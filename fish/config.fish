# claude desktop's terminal panel does not answer fish's terminal queries, which
# makes fish stall 10s at startup and print a warning. fish only reads
# fish_features at startup, so export the flag and re-exec once.
if status is-interactive; and test "$TERM_PROGRAM" = claude-desktop; and not contains no-query-term $fish_features
    set -gx fish_features $fish_features no-query-term
    if status is-login
        exec fish -l
    else
        exec fish
    end
end

# local bin
fish_add_path ~/.local/bin

# kitty shell integration (cursor shape, prompt marks, etc). loaded by hand
# because nix-darwin overwrites XDG_DATA_DIRS, which is how kitty normally
# injects it. kitty.conf sets `shell_integration no-rc` to match
if set -q KITTY_INSTALLATION_DIR
    source "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish"
end

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

# tinymist
if command -q tinymist
    tinymist completion | source
end

# load the automatic venv activation function
if status is-interactive
    activate_venv --quiet
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
abbr gcanea git commit -a --no-edit --amend
abbr gp git push
abbr gl git log
abbr gb git branch

# other abbr
abbr vim nvim
abbr ipy ipython
abbr npm pnpm

