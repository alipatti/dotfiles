function ask_for_confirmation -a message
    while true
	read -n 1 -l -p "set_color magenta; echo -n $message; set_color normal; echo ' [y/n] ❯ '" confirm

	switch $confirm
	    case Y y
		return 0
	    case '' N n
		return 1
	end
    end
end
