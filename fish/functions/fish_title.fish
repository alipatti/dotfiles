function fish_title
    # see e.g. https://github.com/fish-shell/fish-shell/blob/master/share/functions/fish_title.fish
    
    set -l output

    # ssh
    if set -q SSH_TTY
        echo -n "{$(prompt_hostname)} "
    end

    # current command
    if test "$(status current-command)" != fish
        echo -ns '(' (status current-command) ') '
    end

    # pwd
    echo (prompt_pwd)
end
