# set editor
set -gx EDITOR nvim

# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin

zoxide init fish | source
starship init fish | source
rtx activate fish | source
