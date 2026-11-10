function activate_venv --on-variable PWD
    status is-interactive; or return

    # walk up from the cwd looking for a .venv
    set -l dir (path resolve $PWD)
    while not test -d $dir/.venv
        if test $dir = /
            # none found: leave one that was activated further down
            if type -q deactivate
                echo "deactivating virtual environment"
                deactivate
            end
            return
        end
        set dir (path dirname $dir)
    end

    set -l venv $dir/.venv
    test "$VIRTUAL_ENV" = $venv; and return

    contains -- --quiet $argv; or echo "activating virtual environment at $venv"
    source $venv/bin/activate.fish
end
