# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin
fish_add_path ~/.deno/bin
fish_add_path ~/.n/bin

zoxide init fish | source
starship init fish | source
devpod completion fish | source

bind \cr search_history

# load the automatic venv activation function
activate_venv

# load environment variables
cat ~/.config/fish/env/*.env | grep "^[^#]" | sed "s/^/export /" | source

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /usr/local/Caskroom/miniforge/base/bin/conda
    eval /usr/local/Caskroom/miniforge/base/bin/conda "shell.fish" hook $argv | source
else
    if test -f "/usr/local/Caskroom/miniforge/base/etc/fish/conf.d/conda.fish"
        . "/usr/local/Caskroom/miniforge/base/etc/fish/conf.d/conda.fish"
    else
        set -x PATH /usr/local/Caskroom/miniforge/base/bin $PATH
    end
end
# <<< conda initialize <<<
