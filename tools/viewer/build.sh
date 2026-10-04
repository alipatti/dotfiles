#!/bin/sh
# build ~/Applications/viewer.app and the viewer command. run by home/darwin.nix
#
# this uses the system swiftc rather than nixpkgs', so the app links against
# the current sdk. appkit leaves out newer features (window tiling shortcuts,
# the macos 26 look) for apps built against older ones
set -eu

src=$(dirname "$0")
app=$HOME/Applications/viewer.app
bin=$HOME/.local/bin/viewer

# the command is written last, so it also marks a finished build
if [ -x "$app/Contents/MacOS/viewer" ] && [ -x "$bin" ] && [ -z "$(find "$src" -newer "$bin")" ]; then
	exit 0
fi

mkdir -p "$app/Contents/MacOS" "$(dirname "$bin")"
cp "$src/Info.plist" "$app/Contents/Info.plist"
/usr/bin/swiftc -O "$src/viewer.swift" -o "$app/Contents/MacOS/viewer"

cat >"$bin" <<EOF
#!/bin/sh
# -g keeps focus in the editor. open passes documents to the running app
exec /usr/bin/open -g -a "$app" "\$@"
EOF
chmod +x "$bin"
