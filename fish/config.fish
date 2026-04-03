# local bin
fish_add_path ~/.local/bin

# rust setup
test -f "$HOME/.cargo/env.fish" && source "$HOME/.cargo/env.fish"

# prompt setup
command -q starship && starship init fish | source

# z setup
command -q starship && zoxide init fish | source

# bat setup
if command -q bat
    set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# nixos setup
if command -q nix-your-shell
    nix-your-shell fish | source
end

# load the automatic venv activation function
if status is-interactive
    activate_venv
end

if command -q fzf
    bind \cr search_history
end

load_dotenv ~/.dotfiles/env/*

# git shortcuts
abbr g git
abbr gs git status
abbr gd git diff
abbr ga git add
abbr gaa git add --all
abbr gc git commit
abbr gcm git commit -m
abbr gcam git commit -am
abbr gp git push
abbr gl git log
abbr gb git branch

# other abbr
abbr vim nvim
abbr r radian
