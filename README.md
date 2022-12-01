# alipatti's dotfiles

`sh it`

## TODO

- [x] create Brewfile (with mac app store apps included)
- migrate apps to brew installation

  - [x] docker
  - [ ] vscode
  - [x] LaTeX (replace MacTeX with a lighter-weight distribution)

- [ ] finish build script (`doit.sh`)

- create symlinks

  - [ ] vscode config/extensions
        (to `~/Library/Application Support/Code/User`)
  - [ ] `fish` config
        (to `~/.config/fish`)
  - [ ] LaTeX class files
        (to `~/Library/texmf/tex/latex`)
  - [ ] `.latexmkrc` file
        (to `~/`)

- macOS setup
  - [ ] configure preferences ([possibilities](https://ss64.com/osx/syntax-defaults.html))
  - [ ] add shortcuts
- [ ] add cmd/opt + arrows/delete to terminal (or move to iterm/hyper)

- [ ] set fish as default shell in `dotbot` config file
      (use `chsh`)

- latex setup
  - [ ] update tlmgr (`sudo tlmgr update --self`)
  - [ ] install `latexmk` - [ ] install its necessary lua packages
        (`cpan -i YAML::Tiny File::HomeDir Unicode::GCString`)
  - [ ] `latexindent` with tlmgr

- [ ] install xcode command line tools

### Long term

- [ ] make it easier to use docker development containers
- [ ] create system for taking notes in latex/markdown
  - some sort of easy diagram library... write my own??
  - i really only need support for graphs with arbirary latex inside
- [ ] audit ~/School and ~/Projects + create repos for things that I want to save
