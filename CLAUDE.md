# Dotfiles

## Layout

- `hosts/<host>/`: system config per machine.
- `home/`: home-manager entry points.
  `default.nix` is shared,
  and `<platform>.nix` picks modules from `config/`.
- `config/`: home-manager modules, one per program
  (`x.nix`, or `x/default.nix` with its files beside it).
- `apps/`: software written here (CLI or GUI).
- `libraries/`: source imported by other code or documents.

## Convention

- Don't begin a file with a comment describing the file's purpose
  when it's already obvious from the name and content.
- Scripts that programs run are copied into the store (`"${./script.py}"`),
  not linked.

## Deploying

`./setup` needs sudo, so the user runs it after changes.
Before handing off, check that `nix flake check`
(builds this system)
and `nix flake check --all-systems --no-build` (evaluates the rest) pass.
