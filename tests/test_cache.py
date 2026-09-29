import pickle
import warnings
from collections.abc import Callable
from pathlib import Path

import polars as pl
import pytest
from joblib._store_backends import CacheWarning

from alipatti.cache import (
    LAZY_PARQUET_FILENAME,
    PARQUET_FILENAME,
    MmapMode,
    ParquetCache,
)


class Counter:
    """Counts how many times a polars query actually executes."""

    def __init__(self) -> None:
        self.n = 0

        # a closure rather than a method: joblib hashes a bound method's `self`,
        # whose count changes after each execution
        def query(n: int) -> pl.LazyFrame:
            return pl.LazyFrame({"a": range(n)}).with_columns(
                b=pl.col.a.map_batches(self.times_ten, return_dtype=pl.Int64)
            )

        self.query = query

    def times_ten(self, s: pl.Series) -> pl.Series:
        self.n += 1
        return s * 10


@pytest.fixture
def cache(tmp_path: Path) -> ParquetCache:
    return ParquetCache(tmp_path, verbose=0)


@pytest.fixture
def counter() -> Counter:
    return Counter()


def cached_files(cache: ParquetCache, pattern: str = "output*") -> list[str]:
    return sorted(p.name for p in Path(str(cache.location)).rglob(pattern))


def object_frame() -> pl.DataFrame:
    return pl.DataFrame({"x": [object()]}, schema={"x": pl.Object})


# dataframes


def test_dataframe_is_cached_as_parquet(cache: ParquetCache):
    """Store DataFrame results as parquet and reload them without recomputing."""
    calls = []

    @cache.cache
    def frame(n: int) -> pl.DataFrame:
        calls.append(n)
        return pl.DataFrame({"a": range(n)})

    first, second = frame(3), frame(3)

    assert calls == [3]
    assert isinstance(second, pl.DataFrame)
    assert first.equals(second)
    assert cached_files(cache) == [PARQUET_FILENAME]


def test_other_types_fall_back_to_pickle(cache: ParquetCache):
    """Pickle results that are not polars frames."""
    frame = cache.cache(lambda: {"a": 1})

    frame()

    assert frame() == {"a": 1}
    assert cached_files(cache) == ["output.pkl"]


def test_unwritable_dataframe_warns_and_leaves_no_files(cache: ParquetCache):
    """Warn and still return the result when a DataFrame cannot be cached."""
    frame = cache.cache(object_frame)

    with pytest.warns(CacheWarning):
        result = frame()

    assert result.shape == (1, 1)
    assert cached_files(cache, "output.parquet*") == []


def test_joblib_options_are_forwarded(tmp_path: Path):
    """Pass compress and mmap_mode through to joblib's store backend."""
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")  # joblib warns that compress disables mmap
        cache = ParquetCache(tmp_path, compress=3, mmap_mode="r")

    backend = cache.store_backend
    assert backend is not None
    assert backend.compress == 3
    assert backend.mmap_mode == "r"


def test_parquet_options_are_applied(tmp_path: Path):
    """Pass parquet_options through to the parquet writer."""
    frame = pl.DataFrame({"a": range(100_000)}).cast(pl.String)

    def cached_size(compression: str) -> int:
        cache = ParquetCache(
            tmp_path / compression,
            verbose=0,
            parquet_options={"compression": compression},
        )
        cache.cache(lambda: frame)()
        (path,) = Path(str(cache.location)).rglob(PARQUET_FILENAME)
        return path.stat().st_size

    assert cached_size("uncompressed") > cached_size("zstd")


def test_load_message_is_printed(tmp_path: Path, capsys: pytest.CaptureFixture[str]):
    """Print joblib's loading message on parquet cache hits when verbose."""
    frame = ParquetCache(tmp_path, verbose=2).cache(lambda: pl.DataFrame({"a": [1]}))
    frame()
    capsys.readouterr()

    frame()

    assert "Loading" in capsys.readouterr().out


# lazyframes


def test_lazyframe_is_not_executed_until_collected(
    cache: ParquetCache,
    counter: Counter,
):
    """Return a LazyFrame without executing the query or writing the cache."""
    lf = cache.cache(counter.query)(5)
    lf.filter(pl.col.a > 2).collect_schema()

    assert isinstance(lf, pl.LazyFrame)
    assert counter.n == 0
    assert cached_files(cache, LAZY_PARQUET_FILENAME) == []


@pytest.mark.parametrize("mmap_mode", [None, "r"])
def test_lazyframe_executes_once(
    tmp_path: Path,
    counter: Counter,
    mmap_mode: MmapMode | None,
):
    """Execute the query once across collects, self-joins, and later calls."""
    query = ParquetCache(tmp_path, verbose=0, mmap_mode=mmap_mode).cache(counter.query)

    lf = query(5)
    lf.join(lf, on="a").collect()
    lf.collect()
    query(5).collect()

    assert counter.n == 1


def test_lazyframe_cache_hit_scans_parquet(cache: ParquetCache, counter: Counter):
    """Return a parquet scan on cache hits so downstream pushdown applies."""
    query = cache.cache(counter.query)
    query(5).collect()

    hit = query(5)

    assert "Parquet SCAN" in hit.explain()
    assert cached_files(cache) == [LAZY_PARQUET_FILENAME]


@pytest.mark.parametrize(
    "downstream",
    [
        lambda lf: lf.filter(pl.col.a > 2).select("b"),
        lambda lf: lf.filter(pl.col.b > 10).head(2),
        lambda lf: lf.select(pl.col.b.sum()),
        lambda lf: lf.head(1),
    ],
    ids=["filter-other-column", "filter-then-head", "aggregate", "head"],
)
@pytest.mark.parametrize("hit", [False, True], ids=["miss", "hit"])
def test_lazyframe_results_match_uncached(
    cache: ParquetCache,
    counter: Counter,
    downstream: Callable[[pl.LazyFrame], pl.LazyFrame],
    hit: bool,
):
    """Produce the same results as the uncached query under pushdown."""
    query = cache.cache(counter.query)

    if hit:
        query(6).collect()

    expected = downstream(counter.query(6)).collect()
    assert downstream(query(6)).collect().equals(expected)


def test_lazyframe_is_picklable(cache: ParquetCache, counter: Counter):
    """Pickle the returned LazyFrame, e.g. to pass it to another cached function."""
    lf = cache.cache(counter.query)(3)

    assert pickle.loads(pickle.dumps(lf)).collect()["b"].to_list() == [0, 10, 20]


def test_unwritable_lazyframe_warns_and_returns_data(cache: ParquetCache):
    """Warn and still return the result when a LazyFrame cannot be cached."""
    lf = cache.cache(lambda: object_frame().lazy())()

    with pytest.warns(CacheWarning):
        result = lf.collect()

    assert result.shape == (1, 1)
    assert cached_files(cache, "output.lazy.parquet*") == []
