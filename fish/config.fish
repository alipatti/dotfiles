# add paths
fish_add_path ~/.local/bin

for cmd in n cargo deno
    if command -q $cmd
        fish_add_path ~/.$cmd/bin
    end
end

# source init files
for cmd in starship zoxide
    if command -q $cmd
        $cmd init fish | source
    end
end

if command -q bat
    set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

if command -q nix-your-shell
    nix-your-shell fish | source
end

# load the automatic venv activation function
if status is-interactive
    activate_venv
end

bind \cr search_history

load_dotenv ~/.dotfiles/env/*

# git shortcuts
abbr g git
abbr gs git status
abbr gd git diff
abbr ga git add
abbr gc git commit
abbr gcm git commit -m
abbr gcam git commit -am
abbr gp git push
abbr gl git log

# other abbr
abbr vim nvim
abbr r radian
