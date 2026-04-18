function load_dotenv
    for file in $argv
        # Skip files that aren't plaintext (e.g. git-crypt encrypted files)
        if not string match -q 'text*' "$(file -b --mime-type $file)"
            continue
        end
        set vars "$(cat $file | grep '^[^#]' 2>/dev/null | string join ' ')"
        echo "export $vars" | source >/dev/null
    end
end
