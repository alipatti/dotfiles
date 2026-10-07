#!/bin/sh
# build ~/Applications/princeton-vpn-callback.app, which handles globalprotectcallback:
# links. run by ../home.nix. uses the system swiftc, like tools/viewer
set -eu

src=$(dirname "$0")
app=$HOME/Applications/princeton-vpn-callback.app
exe=$app/Contents/MacOS/callback

if [ -x "$exe" ] && [ -z "$(find "$src" -newer "$exe")" ]; then
	exit 0
fi

mkdir -p "$app/Contents/MacOS"
cp "$src/Info.plist" "$app/Contents/Info.plist"
/usr/bin/swiftc -O "$src/callback.swift" -o "$exe"

# tell launch services about the link scheme now rather than at first launch
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
