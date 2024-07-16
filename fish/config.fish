# set editor
set -gx EDITOR nvim

# update path
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin

zoxide init fish | source
starship init fish | source
mise activate fish | source
devpod completion fish | source

if [ "$(uname)" = "Linux" ]
    and test -f /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

set -xg MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -xg BAT_THEME "Coldark-Dark"

set -xg FZF_DEFAULT_OPTS '--border --height 40%
    --layout="reverse" --info="right"
    --padding="1" --margin="1"
    --prompt="❯ "
    --marker="✔ " --pointer=" "
    --color=16 --color=bg+:-1'

bind \cr search_history


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /usr/local/Caskroom/miniconda/base/bin/conda
    eval /usr/local/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/usr/local/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
        . "/usr/local/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/usr/local/Caskroom/miniconda/base/bin" $PATH
    end
end
# <<< conda initialize <<<

