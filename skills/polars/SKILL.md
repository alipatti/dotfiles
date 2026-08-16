---
name: polars
description: "Use this skill for any tabular data task in Python: loading, transforming, aggregating, or writing dataframes. Covers polars style and conventions, including lazy evaluation, expressions, dtype choices, and reading SAS/Stata files."
---

# Polars Skill

Use polars for _all_ tabular data tasks
unless pandas is strictly required by legacy dependencies.

This document is intended as an overview and style guide,
not an exhaustive source on how to use `polars`.
Refer to surrounding code, the linked documentation,
and the context7 documentation MCP server with `libraryId: websites/pola_rs`
for more information.

## Setup

```bash
uv add polars
```

```python
import polars as pl
```

## Loading Data

Use the built-in polars `pl.read_*` and `pl.scan_*` functions
for loading common file types.
Always load large (> ~25MB) files lazily.

```python
df = pl.read_csv("/path/to/small/csv")
lf = pl.scan_parquet("/path/to/parquet")
```

It's often a good idea to inspect the schema of a file
before doing downstream computation.

```python
print(lf.collect_schema())
```

### From SAS and Stata Files

Use the `polars_readstat` library for loading SAS (`.sas7bdat`)
and Stata (`.dta`) files.

```bash
uv add polars_readstat
```

```python
import polars_readstat as prs

stata_lf = prs.scan_readstat(
    "file.dta",
    # set these two parameters by default unless there is a reason not to
    value_labels_as_strings=True, # load labeled variables as categoricals
    missing_string_as_null=True, # "" -> null
)

sas_lf = prs.scan_readstat(
    "file.sas7bdat",
    missing_string_as_null=True,
)
```

See [the docs](https://jrothbaum.github.io/polars_readstat/read/) for more.

### From Other In-Memory Data

```python
# polars implements the PyCapsule interface and can convert to/from `pyarrow` at zero cost
arrow_table = pa.table(polars_df)
polars_again = pl.DataFrame(arrow_table)

# conversion from pandas (copies data, so avoid pandas entirely if possible!)
pl.from_pandas(pandas_df)

# use from_records to load from row-wise python objects
list_of_dicts = [{"col1" : 1, "col2" : 2}, {"col1" : 3, "col2" : 4}, ...]
pl.from_records(list_of_records)

list_of_lists = [[1, 2], [3, 4], ...]
pl.from_records(list_of_lists, schema=["col1", "col2"])

# use the class constructor to load from column-wise representations
pl.DataFrame({"col1" : [1, 2, 3], "col2" : [4, 5, 6]})

```

## Lazy Evaluation

Polars offers two modes: lazy and eager.
Lazy queries are first constructed using a DSL and then optimized
and distributed across all available cores.
Eager queries are executed on-the-fly and are generally slower.
Prefer lazy evaluation when working with large data (more than ~ 1M cells)

```python
lazy_query = (
    # load data
    pl.scan_parquet("orders.parquet")
    # restrict to a subset of rows
    .filter(pl.col("status") == "shipped")
    # do some work
    .group_by("customer_id")
    .agg(
        pl.col("amount").sum().alias("total"),
        pl.len().alias("n_orders"),
    )
    .sort("total", descending=True)
)

# call collect at the end to execute the query and materialize the data.
# only the relevant rows (status == shipped) and columns (customer_id and amount) will be loaded
print(lazy_query.collect())
```

### Streaming

For lazy queries over data too large to fit in memory,
use the streaming engine to process the data in batches rather than all at once.

```python
# collect() -> new streaming engine
lazy_query.collect(engine="streaming")

# sink_* writes results straight to disk, streaming automatically
lazy_query.sink_parquet("output.parquet")
```

Not every operation supports streaming
(e.g. some joins and sorts require the full frame in memory).
Check `.explain(engine="streaming")` to see
which parts of the plan will run in streaming mode.

## Manipulating Data

### Adding Columns

Add new columns using `lf.with_columns(expression, ...)`.
These expressions can be quite complex and appear many places in polars.
See [Expressions](#expressions) below for more.

```python
lf.with_columns(
    # use .alias() to name the output
    pl.col("x").pow(2).add(7).mul(10).sub(4).alias("y"),
    # you can operate on multiple columns at the same time
    # if there is no .alias(), the result will overwrite the existing column
    pl.col("x1", "x2") - 10,
)

# add many columns at once by unpacking iterables and mappings
lf.with_columns(
    *(pl.lit(i).alias(f"x_{i}") for i in range(4)),
    **{name : pl.lit(name) for name in "asdf"}
)
```

### Selecting Columns

Select columns using `lf.select()`.

```python
lf.select(
    "by_name",
    pl.col("col").log().name.suffix("_log"),
    # you can also unpack iterables/mappings as in .with_columns
)
```

### Aggregation

Aggregation is done using `.group_by()` and `.agg()`.

```python
lf.group_by("g1", pl.col("g2").cast(pl.Int64).mod(10)).agg(
    pl.col("x").mean().alias("mean"),
    pl.col("x").var().alias("var"),
)
```

### Joining

Polars supports the full suite of standard joins.

```python
df1.join(
    df2,
    on = ["join", "keys"], # arbitrary expressions are also accepted!
    how ="inner", # "left", "right", "full", "semi", "anti"
)
```

There are also non-equality joins by key proximity (`.join_asof`)
or by arbitrary boolean expressions (`.join_where`).
See [the guide](https://docs.pola.rs/user-guide/transformations/joins/)
for more info.

### Pivoting

To go from long to wide, use `.pivot()`
([guide](https://docs.pola.rs/user-guide/transformations/pivot/),
[reference](https://docs.pola.rs/api/python/stable/reference/dataframe/api/polars.DataFrame.pivot.html)).
This is not available lazily (the possible values aren't known a priori).

To go from wide to long, use `.unpivot()`
([guide](https://docs.pola.rs/user-guide/transformations/unpivot/),
[eager reference](https://docs.pola.rs/api/python/stable/reference/dataframe/api/polars.DataFrame.unpivot.html),
[lazy reference](https://docs.pola.rs/api/python/stable/reference/lazyframe/api/polars.LazyFrame.unpivot.html)
).
This works both lazily and eagerly.

### Concatenation

Stack multiple frames together using `pl.concat()`
([reference](https://docs.pola.rs/api/python/stable/reference/api/polars.concat.html)).

```python
# if the schemas match exactly
pl.concat(frames_with_identical_schemas, how="vertical")

# if they don't (e.g. there are extra columns or different dtypes)
pl.concat(frames_with_different_schemas, how="diagonal_relaxed")
```

## Expressions

Expressions are the main way that you interact with data in polars.
Use expressions as much as possible rather than chaining multiple with_columns
calls.

To preserve readability,
build up complicated expressions using well-named intermediate expressions
and helper functions.

```python
def weighted_mean(x: pl.Expr, w: pl.Expr | str):
    if isinstance(w, str):
        w = pl.col(w)

    # mask for null values
    mask = x.is_not_null().cast(int)

    return x.dot(w) / w.dot(mask)

# use .pipe to apply a function in a chain of method calls
x_bar = pl.col("x").pipe(weighted_mean, "weight").over("group")

lf.with_columns(x_bar)
```

### Selectors and Expression Expansion

Use selectors to select many columns at once.
The resulting object can be used like any other polars expression.
See
[the docs](https://docs.pola.rs/user-guide/expressions/expression-expansion/)
for more.

```python
from polars import selectors as cs

# by dtype, e.g., trim whitespace from all string cols
cs.string().str.strip_chars()

# by regex, e.g., log wages for every year
cs.matches(r"^wages_\d{4}$").log().name.prefix("log_")

# by prefix, e.g., mean of all x_* columns
cs.starts_with("x_").mean()

# selectors can be combined like sets
cs.contains("_") - cs.string() # columns with an underscore, but not strings
cs.string() | cs.categorical() # both strings and categoricals
cs.int() & cs.contains("foo") # integer columns containing the string foo
```

When doing the same operation to many columns, prefer selectors
(`cs.matches(r"x_\d").log()`) over generator expressions
(`(pl.col(f"x_{i}").log() for i in range(4))`) over repeated code.

### Window Expressions

Window functions restrict expressions to operate only _within_ defined groups.
Prefer them to using `group_by` followed by a join -- they often let one avoid
constructing temporary dataframes.

```python
# demeaning a variable within some group
x_tilde = pl.col("x") - pl.col("x").mean().over("category")

# lagged variables within each unit
x_tm2 = pl.col("x").lag(2).over("unit")

# rank within cohort/sex
x_rank = pl.col("x").rank(method="average").over("cohort", "sex")
```

### Custom Functions

Make a best effort to implement functionality using the built-in expression API.
For things that can't be implemented natively in Polars,
there are three options in order of preference:

1. Write a function that operates on `pl.Series` and use `.map_batches()`
   [docs](https://docs.pola.rs/api/python/stable/reference/expressions/api/polars.Expr.map_batches.html).
2. Write and then call a `numpy` ufunc or generalized ufunc.
   These can be used in polars with little overhead
   [docs](https://docs.pola.rs/user-guide/expressions/numpy-functions/).
   Polars uses a separate nullity bitmask that numpy does not receive,
   so only use this if your operation is elementwise
   or the input contains no null values.
   Prefer this option makes use of existing numpy-compatible tooling,
   for example `scipy` or `np.linalg`.
3. Write a python function that operates on individual elements
   and use `.map_elements()`
   [docs](https://docs.pola.rs/api/python/stable/reference/expressions/api/polars.Expr.map_elements.html).
   This is slow and should only be used on very small DataFrames
   (e.g. relabeling rows for plotting).

## Data Types

Choosing appropriate data types is a first-order task.
Columns should use the data type
that is semantically closest to the data being stored.

For example, columns indicating the date should be stored as a `pl.Date`,
not a `yyyy-mm-dd` string.
Time spans should be stored as `pl.Duration`s.

Categorical columns with a fixed set of options should be stored as `pl.Enum`s.
Columns with a large or a-priori unknown set of categories should be stored
as `pl.Categorical`s.
Do not store categorical columns as strings or integers.

Numeric columns that cannot take on fractional values should be stored
as integers.
Default to `pl.Int64` and use smaller integer types only when you are certain
that the values will not overflow
(e.g. year can safely be stored as a `pl.Int16`).
Avoid unsigned integer types (they make subtraction behave in unexpected ways).

### Null Values

Polars stores missing data as `null`,
tracked via a separate per-column validity bitmask rather than a sentinel value
in the data itself.
This means every dtype (including numeric and categorical types) can represent
missingness without reserving a value for it.

Always use `null` for missing data.
Do not use sentinel values such as empty strings (`""`) or magic integers
(`-1`, `9999`) to mean "missing".
If there are many meaningful reasons for missingness,

```python
lf = pl.scan_csv("raw_messy_data.csv")

# look at first few rows
print(lf.head().collect())

# clean up missing values
lf.with_columns(
    pl.col("code").replace(-1, None),
    pl.col("name").replace("", None),
)
```

## Debugging and Development

Use `.inspect()` to print the content of the dataframe at
that point in the query _at execution time_.
Note that because of Polars' optimizations
(reordering statements, removing unused columns),
the output may not appear exactly as you expect.

```python
query = (
    lf.with_columns(y = pl.col("x").pow(2))
    .inspect()
    .with_columns(z = pl.col("x").pow(3))
)

# when collect is called, prints the df with only y added
query.collect()
```

You can also inspect the query plan.

```python
query.explain() # get a text-based representation of the compiled query
query.show_graph() # show the computational graph (this can be long and complicated)
```

It's also often helpful to break long queries into several steps.

### Logging

Use `loguru` to include many log statements.
Use the debug level by default.

```python
from loguru import logger

logger.debug("Schema before processing: {}", lf.collect_schema())
logger.debug("Data before processing: {}", lf.head().collect())

# do work and collect...

logger.debug("Expensive step done!")
logger.debug("Data after processing: {}", df_processed)
```

### Interactive Use with IPython

For interactive exploration of a dataframe or query,
use the `ipython` MCP server rather than repeatedly editing
and rerunning a script.
It runs a persistent IPython session,
so variables and imports stay alive between tool calls.

Add it to `settings.json`:

```json
"mcpServers": {
  "ipython": {
    "command": "uvx",
    "args": ["--from", "git+https://github.com/alipatti/repl-mcp", "repl-mcp", "ipython"]
  }
}
```

Use it to collect the desired data once
(possibly after performing some operations),
and then experiment against the live session instead of re-running `pl.scan_*`
from scratch each time.

## Writing Data

Save data to parquet files by default.

```python
DATA = Path("./data")

# use write_parquet to save in-memory data
df.write_parquet(DATA / "output.parquet")

# use sink_parquet to write lazy queries to disk
really_complicated_query.sink_parquet(DATA / "output.parquet")
```
