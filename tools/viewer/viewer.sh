#!/bin/sh
# the viewer command, on every machine. opens urls and files in viewer.app on
# macos and with xdg-open elsewhere
#
# over kitten ssh, urls open on the mac instead. the remote asks kitty to run
# `viewer --attach` there, which forwards a loopback url's port through kitten
# ssh's shared connection and opens it. needs forward_remote_control, see
# home/modules/kitty.nix
#
# usage: viewer <url-or-file>...
set -eu

# run by kitty on the mac, with the remote's hostname and a url
if [ "${1-}" = --attach ]; then
	host=$2 url=$3

	case $url in
	http://localhost:* | http://127.0.0.1:*) ;;
	# reachable from here as it is
	*) exec "$0" "$url" ;;
	esac
	port=${url#http://*:}
	port=${port%%/*}

	# kitty is the parent, and kitten ssh names its sockets after kitty's pid.
	# the one whose host matches is the window that asked
	sock=
	for s in /tmp/kssh-rdir-"$(id -u)"/kssh-"$PPID"-*; do
		if [ "$(ssh -S "$s" -o BatchMode=yes _ uname -n 2>/dev/null)" = "$host" ]; then
			sock=$s
			break
		fi
	done
	[ "$sock" ] || exit 1

	# lasts until the ssh connection closes
	ssh -S "$sock" -O forward -L "$port:localhost:$port" _
	exec "$0" "$url"
fi

if [ "${SSH_CONNECTION-}" ] && [ "${KITTY_LISTEN_ON-}" ]; then
	for url; do
		case $url in
		http://* | https://*) ;;
		*)
			echo "viewer: can only open urls over ssh: $url" >&2
			exit 1
			;;
		esac
		# exec keeps kitty as the parent. $HOME expands on the mac, where
		# ~/.local/bin isn't on the path of programs kitty runs
		# shellcheck disable=SC2016
		kitten @ launch --type=background sh -c 'exec "$HOME/.local/bin/viewer" --attach "$@"' \
			viewer "$(uname -n)" "$url" >/dev/null
	done
	exit
fi

if [ "$(uname)" = Darwin ]; then
	# -g keeps focus in the editor. open passes documents to the running app
	exec /usr/bin/open -g -a "$HOME/Applications/viewer.app" "$@"
fi
for arg; do
	xdg-open "$arg"
done
