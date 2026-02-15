function load_dotenv
    for file in $argv
        set vars "$(cat $file | grep '^[^#]' 2>/dev/null | string join ' ')"
        echo "export $vars" | source >/dev/null
    end
end
