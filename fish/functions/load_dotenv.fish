function load_dotenv
    echo export $(cat $argv | grep "^[^#]" | string join " ") | source
end
