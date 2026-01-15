# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin
fish_add_path ~/.deno/bin
fish_add_path ~/.n/bin

if command -q nix-your-shell
    nix-your-shell fish | source
end

if command -q zoxide
    zoxide init fish | source
end

if command -q starship
    starship init fish | source
end

bind \cr search_history

# load the automatic venv activation function
activate_venv

# load environment variables
echo export $(cat ~/.config/fish/env/*.env | grep "^[^#]" | string join " ") | source
