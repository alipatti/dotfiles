# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin
fish_add_path ~/.deno/bin
fish_add_path ~/.n/bin

zoxide init fish | source
starship init fish | source

bind \cr search_history

# load the automatic venv activation function
activate_venv

# load environment variables
echo export $(cat ~/.config/fish/env/*.env | grep "^[^#]" | string join " ") | source
