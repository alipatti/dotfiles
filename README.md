# Alistair's dotfiles

![the general problem](https://imgs.xkcd.com/comics/the_general_problem.png)

Two hosts, both a nix flake: `macbook` (nix-darwin) and `fridge` (nixos).
Per-user config is home-manager, shared in `home/` with platform-specific
bits in `home/darwin.nix` and `home/linux.nix`. `hosts/` holds what needs
root.

```bash
# fresh machine: installs nix (and homebrew on a mac), then applies the flake
./setup macbook

# afterwards
sudo darwin-rebuild switch --flake ~/.dotfiles
sudo nixos-rebuild switch --flake ~/.dotfiles
```

Configs that get edited in place (nvim, fish functions, ipython, latex,
typst, skills) are symlinked out of the repo rather than copied into the
store, so changes apply without a rebuild.

`secrets.env` is encrypted with git-crypt and only sourced once unlocked:

```bash
git-crypt unlock /path/to/key
```

Neovim plugins are managed by `vim.pack`; update them with
`:lua vim.pack.update()`.
