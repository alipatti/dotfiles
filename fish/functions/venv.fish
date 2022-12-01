function venv
if ! test -e .venv
echo "Virtual environment does not exist. Creating one..."
python3 -m venv .venv
end
. .venv/bin/activate.fish
end
