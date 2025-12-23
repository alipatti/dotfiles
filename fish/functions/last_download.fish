function last_download
    ls -t ~/Downloads | head -n 1 | xargs -I {} echo ~/Downloads/{}
end
