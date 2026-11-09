# @ali/template

When adding a breaking change to this package,
do the following before making the change:

1. Add
   `"<old version>" = { rev = "<current commit>"; path = "libraries/typst"; };`
   to `releases` in `home/programs/typst.nix`.
2. Bump the minor version in `typst.toml`, e.g. `0.1.0` to `0.2.0`.

Then push and rebuild.
Documents importing old versions compile against the pinned commit.

If the change is backwards-compatible, do not update any versions.
