function tree --wraps='exa --tree --git-ignore' --wraps='exa --tree --git-ignore --level=3' --description 'alias tree exa --tree --git-ignore --level=3'
  eza --tree --git-ignore --level=3 $argv
        
end
