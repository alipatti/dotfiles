# expansion for the ssh abbr in home/modules/shell.nix. inside kitty, use the
# ssh kitten so new splits open on the remote host
function ssh_abbr
    if set -q KITTY_WINDOW_ID
        echo kitten ssh
    else
        echo ssh
    end
end
