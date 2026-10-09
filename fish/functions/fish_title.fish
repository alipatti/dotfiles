function fish_title
    # see e.g. https://github.com/fish-shell/fish-shell/blob/master/share/functions/fish_title.fish
    # renders as `[host] path | command`. tools/kitty_tab_bar.py relies on the
    # leading `[` to color remote tabs

    # ssh
    if set -q SSH_TTY
        echo -n "[$(prompt_hostname)] "
    end

    # pwd, as starship shows it (relative to the git root, if any)
    echo -n (starship module directory | string replace -ra '\e\[[0-9;]*m' '' | string trim)

    # current command
    if test "$(status current-command)" != fish
        echo -ns ' | ' (status current-command)
    end
end
