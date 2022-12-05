# alipatti's dotfiles

`sh it`

## TODO

- [x] create Brewfile (with mac app store apps included)
- migrate apps to brew installation

  - [x] docker
  - [ ] vscode
  - [x] LaTeX (replace MacTeX with a lighter-weight distribution)

- [x] finish build script (`doit.sh`)

- create symlinks

  - [x] vscode config/extensions
        (to `~/Library/Application Support/Code/User`)
  - [x] `fish` config
        (to `~/.config/fish`)
  - [x] LaTeX class files
        (to `~/Library/texmf/tex/latex`)
  - [x] `.latexmkrc` file
        (to `~/`)

- macOS setup
  - [ ] configure preferences ([possibilities](https://ss64.com/osx/syntax-defaults.html))
  - [ ] add shortcuts
- [ ] add cmd/opt + arrows/delete to terminal (or move to iterm/hyper)

- [ ] set fish as default shell
      (use `chsh`, will probably need to add it to list of valid shells first)

- [ ] either rebuild docs for latex or switch to mactex (basictex doesn't include them)
      (see: <https://gist.github.com/kadrach/6228314>)

- latex setup

  - [x] update tlmgr (`sudo tlmgr update --self`)
  - [x] install `latexmk`
  - [x] install its necessary lua packages
        (`cpan -i YAML::Tiny File::HomeDir Unicode::GCString`)
  - [x] install `latexindent`

- [x] install xcode command line tools
      (UPDATE: this should be done during the brew install)

### Long term

- [ ] make it easier to use docker development containers
- [ ] create system for taking notes in latex/markdown
  - some sort of easy diagram library... write my own??
  - i really only need support for graphs with arbirary latex inside
- [ ] audit ~/School and ~/Projects + create repos for things that I want to save
