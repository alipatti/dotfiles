function report_cwd --on-variable PWD
    status is-interactive; or return

    # tell the terminal the cwd (osc 7) so kitty's `launch --cwd=current`
    # opens new windows here. kitty's shell integration also does this, but
    # it isn't loaded on clusters, where bash execs fish after kitten ssh
    printf '\e]7;file://%s%s\e\\' $hostname (string escape --style=url -- $PWD)
end
