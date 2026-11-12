function activate_venv --on-variable PWD
    status is-interactive; or return

    # walk up from the cwd looking for a .venv* (e.g. .venv or .venv.nosync)
    set -l dir (path resolve $PWD)
    set -l venv
    while true
        set -l activators $dir/.venv*/bin/activate.fish
        if set -q activators[1]
            set venv (path dirname (path dirname $activators[1]))
            break
        end
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

    test "$VIRTUAL_ENV" = $venv; and return

    contains -- --quiet $argv; or echo "activating virtual environment at $venv"
    source $venv/bin/activate.fish
end
