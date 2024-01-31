function countlines --wraps='scc --no-cocomo --no-complexity --no-size' --description 'alias countlines scc --no-cocomo --no-complexity --no-size'
  scc --no-cocomo --no-complexity --no-size $argv
        
end
