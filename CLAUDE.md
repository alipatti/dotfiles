# Layout

- `hosts/<host>/`: system config per machine.
- `home/`: home-manager config.
  - `profiles/`: per-platform module selection.
  - `programs/`: one module per program.
- `apps/`: software written here (CLI or GUI).
- `libraries/`: source imported by other code or documents.

Scripts that programs run are copied into the store (`"${./script.py}"`),
not linked, so they keep working until the next switch.

## Deploying

`./setup` needs sudo, so the user runs it after changes.
Before handing off, check that `nix flake check`
(builds this system)
and `nix flake check --all-systems --no-build` (evaluates the rest) pass.
