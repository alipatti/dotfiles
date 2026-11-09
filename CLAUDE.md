# Layout

- `hosts/<host>/`: system config per machine.
- `home/`: home-manager config.
  - `profiles/`: per-platform module selection.
  - `programs/`: one module per program, auto-imported.
- `apps/`: software written here (CLI or GUI).
- `libraries/`: source imported by other code or documents.

## Deploying

`./setup` needs sudo, so the user runs it after changes.
Before handing off, check
that the config still builds with
`nix build --no-link .#darwinConfigurations.macbook.system`.
