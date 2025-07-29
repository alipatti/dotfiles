function e --wraps=eza
  eza --icons auto --group-directories-first \
    --git --no-permissions --total-size --no-user \
    --time-style relative --sort modified --reverse \
    $argv
end
