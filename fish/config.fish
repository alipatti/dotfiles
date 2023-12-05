# set editor
set -gx EDITOR nvim

# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin

zoxide init fish | source
starship init fish | source
rtx activate fish | source


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /usr/local/Caskroom/miniconda/base/bin/conda
    eval /usr/local/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" $argv | source
end
# <<< conda initialize <<<

