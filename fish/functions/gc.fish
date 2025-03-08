function gc --wraps='git commit' --wraps='git commit -m' --description 'alias gc=git commit'
  git commit $argv
        
end
