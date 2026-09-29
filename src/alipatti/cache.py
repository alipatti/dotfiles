import os
import time
import warnings
from collections.abc import Mapping
from pathlib import Path
from typing import Any, Literal, override

import polars as pl
from joblib import Memory, register_store_backend
from joblib._store_backends import CacheWarning
from joblib.logger import format_time
from joblib.memory import FileSystemStoreBackend

BACKEND_NAME = "com.alipatti.parquet"
PARQUET_FILENAME = "output.parquet"

type MmapMode = Literal["r+", "r", "w+", "c"]


class ParquetStoreBackend(FileSystemStoreBackend):
    """A local store backend that stores DataFrames as Parquets."""

    location: str
    parquet_options: dict[str, Any]

    @override
    def configure(
        self,
        location: str,
        verbose: int = 1,
        backend_options: dict[str, Any] | None = None,
    ) -> None:
        options = dict(backend_options or {})
        self.parquet_options = dict(options.pop("parquet_options", None) or {})

        super().configure(location, verbose, options)

    @override
    def dump_item(
        self,
        call_id: list[str],
        item: Any,
        verbose: int = 1,
    ) -> None:
        if not isinstance(item, pl.DataFrame):
            return super().dump_item(call_id, item, verbose=verbose)

        parquet_path = self._parquet_path(call_id)
        parquet_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            self._concurrency_safe_write(item, str(parquet_path), self._write_parquet)

        except (pl.exceptions.PolarsError, OSError) as e:
            warnings.warn(
                f"Unable to cache DataFrame as parquet, falling back to pickle. "
                f"Exception: {e}.",
                CacheWarning,
            )
            super().dump_item(call_id, item, verbose=verbose)

    @override
    def contains_item(self, call_id: list[str]) -> bool:
        return self._parquet_path(call_id).exists() or super().contains_item(call_id)

    @override
    def load_item(
        self,
        call_id: list[str],
        verbose: int = 1,
        timestamp: float | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> Any:
        parquet_path = self._parquet_path(call_id)

        if not parquet_path.exists():
            return super().load_item(
                call_id,
                verbose=verbose,
                timestamp=timestamp,
                metadata=metadata,
            )

        if verbose > 1:
            _print_load_message(
                call_id, parquet_path.parent, verbose, timestamp, metadata
            )

        return pl.read_parquet(parquet_path)

    def _parquet_path(self, call_id: list[str]) -> Path:
        return Path(self.location, *call_id, PARQUET_FILENAME)

    def _write_parquet(self, df: pl.DataFrame, filename: str) -> None:
        # write through our own handle (polars can create the path after raising)
        # and remove the partial temp file so failed writes leave no trace
        try:
            with open(filename, "wb") as f:
                df.write_parquet(f, **self.parquet_options)

        except (pl.exceptions.PolarsError, OSError):
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
    :class:`polars.DataFrame` results as parquets.

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
