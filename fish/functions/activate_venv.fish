function activate_venv --on-variable PWD
    # search up directory tree for a .venv
    set cur (pwd)
    while true
        if [ -z $cur ]
            # no venv found

            if type -q deactivate
                echo "Deactivating virtual environment"
                deactivate
            end

            return
        end

        if [ -d $cur/.venv ]
            # venv found
            set venv_directory $cur/.venv
            break
        end

        # strip off last path segment (i.e. move up tree)
        set cur (echo $cur | sed 's/\/[^\/]*$//')
    end

    if [ (which python3) -ef $venv_directory/bin/python3 ]
        # venv is already active!
        return 0
    end

    # activate venv
    echo "Activating virtual environment at $venv_directory"
    source $venv_directory/bin/activate.fish
end
