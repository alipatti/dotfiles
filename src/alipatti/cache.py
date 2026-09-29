import os
import threading
import time
import uuid
import warnings
from collections import defaultdict
from collections.abc import Iterator, Mapping
from datetime import datetime
from functools import partial
from pathlib import Path
from typing import Any, Literal, override

import polars as pl
from joblib import Memory, register_store_backend
from joblib._store_backends import (
    CacheItemInfo,
    CacheWarning,
    concurrency_safe_write,
)
from joblib.backports import concurrency_safe_rename
from joblib.logger import format_time
from joblib.memory import FileSystemStoreBackend
from polars.io.plugins import register_io_source

BACKEND_NAME = "com.alipatti.parquet"
PARQUET_FILENAME = "output.parquet"
LAZY_PARQUET_FILENAME = "output.lazy.parquet"
LAZY_TOKEN_FILENAME = "output.lazy.token"

type MmapMode = Literal["r+", "r", "w+", "c"]

# serializes writing each deferred LazyFrame's cache within this process
_WRITE_LOCKS: defaultdict[Path, threading.Lock] = defaultdict(threading.Lock)


class ParquetStoreBackend(FileSystemStoreBackend):
    """A local store backend that stores DataFrames and LazyFrames as Parquets."""

    location: str
    parquet_options: dict[str, Any]
    _pending: dict[Path, pl.LazyFrame]

    @override
    def configure(
        self,
        location: str,
        verbose: int = 1,
        backend_options: dict[str, Any] | None = None,
    ) -> None:
        options = dict(backend_options or {})
        self.parquet_options = dict(options.pop("parquet_options", None) or {})
        self._pending = {}

        super().configure(location, verbose, options)

    @override
    def dump_item(
        self,
        call_id: list[str],
        item: Any,
        verbose: int = 1,
    ) -> None:
        if isinstance(item, pl.LazyFrame):
            return self._defer_lazy_item(call_id, item)

        if not isinstance(item, pl.DataFrame):
            return super().dump_item(call_id, item, verbose=verbose)

        parquet_path = self._parquet_path(call_id)
        parquet_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            _write_parquet_atomic(item, parquet_path, self.parquet_options)

        except (pl.exceptions.PolarsError, OSError) as e:
            warnings.warn(
                f"Unable to cache DataFrame as parquet, falling back to pickle. "
                f"Exception: {e}.",
                CacheWarning,
            )
            super().dump_item(call_id, item, verbose=verbose)

    @override
    def contains_item(self, call_id: list[str]) -> bool:
        return (
            self._parquet_path(call_id).exists()
            or self._lazy_parquet_path(call_id).exists()
            or super().contains_item(call_id)
        )

    @override
    def load_item(
        self,
        call_id: list[str],
        verbose: int = 1,
        timestamp: float | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> Any:
        parquet_path = self._parquet_path(call_id)
        lazy_parquet_path = self._lazy_parquet_path(call_id)

        # joblib reloads right after the call when mmap_mode is set,
        # before a deferred LazyFrame has been collected and written
        if lazy_parquet_path in self._pending:
            return self._pending.pop(lazy_parquet_path)

        if not (parquet_path.exists() or lazy_parquet_path.exists()):
            return super().load_item(
                call_id,
                verbose=verbose,
                timestamp=timestamp,
                metadata=metadata,
            )

        if verbose > 1:
            _print_load_message(
                call_id,
                parquet_path.parent,
                verbose,
                timestamp,
                metadata,
            )

        return (
            pl.scan_parquet(lazy_parquet_path)
            if lazy_parquet_path.exists()
            else pl.read_parquet(parquet_path)
        )

    @override
    def get_items(self) -> list[CacheItemInfo]:
        # joblib only checks output.pkl for last access, so use the parquet's instead
        return [_with_output_access_time(item) for item in super().get_items()]

    def _defer_lazy_item(self, call_id: list[str], lf: pl.LazyFrame) -> None:
        """Swap `lf`'s plan in place for one that caches its result on collect.

        joblib returns the same object it passes to `dump_item`,
        so the caller receives the deferred LazyFrame.
        """
        path = self._lazy_parquet_path(call_id)
        query = pl.LazyFrame._from_pyldf(lf._ldf)
        token = _claim_token(path.with_name(LAZY_TOKEN_FILENAME))

        # the source must not reference `self` so the frame stays picklable
        deferred = register_io_source(
            partial(_scan_cached, query, path, token, self.parquet_options),
            schema=query.collect_schema,
            is_pure=True,
        )
        lf._ldf = deferred._ldf

        if self.mmap_mode is not None:
            self._pending[path] = lf

    def _parquet_path(self, call_id: list[str]) -> Path:
        return Path(self.location, *call_id, PARQUET_FILENAME)

    def _lazy_parquet_path(self, call_id: list[str]) -> Path:
        return Path(self.location, *call_id, LAZY_PARQUET_FILENAME)


def _with_output_access_time(item: CacheItemInfo) -> CacheItemInfo:
    for filename in (PARQUET_FILENAME, LAZY_PARQUET_FILENAME):
        output = Path(item.path, filename)

        if output.exists():
            # naive to match joblib, which compares against datetime.now()
            access_time = output.stat().st_atime
            last_access = datetime.fromtimestamp(access_time)  # noqa: DTZ006
            return item._replace(last_access=last_access)

    return item


def _claim_token(token_path: Path) -> str:
    """Return the cache entry's token, creating it if this is the entry's first call.

    Deferred frames only write the cache while the token they were created with is
    still on disk, so frames that outlive a `clear()` or a change to the cached
    function don't populate the new entry with stale results.
    """
    token_path.parent.mkdir(parents=True, exist_ok=True)

    if not token_path.exists():
        token_path.write_text(uuid.uuid4().hex)

    return token_path.read_text()


def _scan_cached(
    query: pl.LazyFrame,
    path: Path,
    token: str,
    parquet_options: dict[str, Any],
    with_columns: list[str] | None,
    predicate: pl.Expr | None,
    n_rows: int | None,
    batch_size: int | None,
) -> Iterator[pl.DataFrame]:
    """Stream `query` to the parquet at `path` if needed, then yield batches from it."""
    with _WRITE_LOCKS[path]:
        if not path.exists() and _token_matches(path, token):
            _try_write_lazy(query, path, parquet_options)

    source = pl.scan_parquet(path) if path.exists() else query

    # polars expects the row limit to apply before the predicate
    if with_columns is not None:
        source = source.select(with_columns)

    if n_rows is not None:
        source = source.head(n_rows)

    if predicate is not None:
        source = source.filter(predicate)

    yield from source.collect_batches(chunk_size=batch_size)


def _token_matches(path: Path, token: str) -> bool:
    token_path = path.with_name(LAZY_TOKEN_FILENAME)
    return token_path.exists() and token_path.read_text() == token


def _try_write_lazy(
    query: pl.LazyFrame,
    path: Path,
    parquet_options: dict[str, Any],
) -> None:
    """Sink `query` to `path`, warning instead of raising if it can't be stored.

    Errors from the query itself propagate so a failing query isn't run twice.
    """
    if pl.Object in query.collect_schema().dtypes():
        warnings.warn(
            "Unable to cache LazyFrame result with Object columns as parquet.",
            CacheWarning,
        )
        return

    try:
        _write_parquet_atomic(query, path, parquet_options)

    except OSError as e:
        warnings.warn(
            f"Unable to cache LazyFrame result as parquet. Exception: {e}.",
            CacheWarning,
        )


def _write_parquet_atomic(
    frame: pl.DataFrame | pl.LazyFrame,
    path: Path,
    parquet_options: dict[str, Any],
) -> None:
    """Write to a temporary file and rename it so readers never see partial files."""
    temporary_path = concurrency_safe_write(
        frame,
        str(path),
        partial(_write_parquet, parquet_options=parquet_options),
    )
    concurrency_safe_rename(temporary_path, str(path))


def _write_parquet(
    frame: pl.DataFrame | pl.LazyFrame,
    filename: str,
    parquet_options: dict[str, Any],
) -> None:
    # write through our own handle (polars can create the path after raising)
    # and remove the partial file so failed writes leave no trace
    try:
        with open(filename, "wb") as f:
            if isinstance(frame, pl.LazyFrame):
                frame.sink_parquet(f, **parquet_options)
            else:
                frame.write_parquet(f, **parquet_options)

    except BaseException:
        Path(filename).unlink(missing_ok=True)
        raise


def _print_load_message(
    call_id: list[str],
    item_path: Path,
    verbose: int,
    timestamp: float | None,
    metadata: dict[str, Any] | None,
) -> None:
    """Mirror the message printed by joblib's `StoreBackendMixin.load_item`."""
    elapsed = f"{format_time(time.time() - timestamp): <16}" if timestamp else ""

    signature = os.path.basename(call_id[0])
    if metadata and "input_args" in metadata:
        args = ", ".join(f"{k}={v}" for k, v in metadata["input_args"].items())
        signature += f"({args})"

    message = f"[Memory]{elapsed}: Loading {signature}"
    print(f"{message}..." if verbose < 10 else f"{message} from {item_path}")


register_store_backend(BACKEND_NAME, ParquetStoreBackend)


class ParquetCache(Memory):
    """A thin wrapper around :class:`joblib.Memory` that caches
    :class:`polars.DataFrame` and :class:`polars.LazyFrame` results as parquets.

    LazyFrame results stay lazy: nothing executes until the returned frame is
    collected, at which point the result is written to the cache. Subsequent calls
    return a :func:`polars.scan_parquet` of the cached file.
    Other return types fall back to joblib's pickle-based storage.
    See the `joblib documentation <https://joblib.readthedocs.io/en/stable/memory.html>`_
    for more.

    Parameters
    ----------
    location
        Path to the cache directory. If None, caching is disabled.
    verbose
        Verbosity level passed to joblib.
    mmap_mode
        Memory-map mode for loading pickled numpy arrays. See :class:`joblib.Memory`.
    compress
        Compression level for pickled (non-DataFrame) results.
    parquet_options
        Keyword arguments passed to :meth:`polars.DataFrame.write_parquet`.

    Examples
    --------
    >>> import time
    >>> import polars as pl
    >>> from alipatti.cache import ParquetCache
    >>>
    >>> CACHE = ParquetCache("/tmp/example/cache/path/", verbose=0)
    >>> CACHE.clear(warn=False)
    >>>
    >>> @CACHE.cache()
    ... def slow_query() -> pl.DataFrame:
    ...     print("Computing expensive function...")
    ...     time.sleep(2)
    ...     return pl.DataFrame({"x": [1, 2, 3]})
    >>>
    >>> slow_query()  # slow on first call
    Computing expensive function...
    shape: (3, 1)
    ┌─────┐
    │ x   │
    │ --- │
    │ i64 │
    ╞═════╡
    │ 1   │
    │ 2   │
    │ 3   │
    └─────┘
    >>> slow_query()  # fast on subsequent calls
    shape: (3, 1)
    ┌─────┐
    │ x   │
    │ --- │
    │ i64 │
    ╞═════╡
    │ 1   │
    │ 2   │
    │ 3   │
    └─────┘

    Functions returning a LazyFrame are only executed when the result is collected:

    >>> @CACHE.cache()
    ... def lazy_query() -> pl.LazyFrame:
    ...     return pl.LazyFrame({"x": [1, 2, 3]}).with_columns(y=pl.col.x * 2)
    >>>
    >>> lf = lazy_query()  # nothing is computed yet
    >>> lf.select(pl.col.y.sum()).collect().item()  # computes and caches
    12
    >>> lazy_query().select(pl.col.y.sum()).collect().item()  # reads the cache
    12

    The backend can also be used directly from :class:`joblib.Memory`:

    >>> from joblib import Memory
    >>> from alipatti.cache import BACKEND_NAME
    >>> CACHE = Memory("/tmp/another/cache/path/", backend=BACKEND_NAME)
    """

    def __init__(
        self,
        location: str | Path | None = None,
        *,
        verbose: int = 1,
        mmap_mode: MmapMode | None = None,
        compress: bool | int = False,
        parquet_options: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(
            location,
            backend=BACKEND_NAME,
            verbose=verbose,
            mmap_mode=mmap_mode,
            compress=compress,
            backend_options={"parquet_options": dict(parquet_options or {})},
        )
