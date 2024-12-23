function ql
	set file $argv[1]
	echo "Viewing $file"
	qlmanage -p $file 2> /dev/null > /dev/null &
end
