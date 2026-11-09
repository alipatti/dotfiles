# alipatti

Personal Python helpers.

```sh
uv add "alipatti @ git+https://github.com/alipatti/dotfiles#subdirectory=libraries/python"
```

The package has a few extras
which can be installed with `... alipatti[<extra>] ...` and used
as `ap.<extra>` after `import alipatti as ap`
(submodules are imported lazily,
so a missing extra only matters once it's used)

- `plot` (plotnine theme and helpers, for typst documents or kitty)
- `cache` (parquet cache for polars dataframes and lazyframes)

`ap.terminal` needs no extra:
it asks the terminal for its colours and checks
whether it shows images with kitty's graphics protocol.
