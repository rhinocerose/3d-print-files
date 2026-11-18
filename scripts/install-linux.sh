#!/bin/sh
# Puts this scripts folder on your PATH (Linux / macOS), so these work from any folder of the repo:
#   add-model <url> [--list urls.txt] ...     (downloads into the folder you're in)
#   update-readmes [--refresh | --offline]
# Run it once:  sh scripts/install-linux.sh   then open a new terminal.
# Safe to run again (e.g. after moving the repo): it replaces its old PATH line.
set -e
dir=$(cd "$(dirname "$0")" && pwd -P)
marker='# 3d-print-files scripts'

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 was not found - install it first (e.g. sudo apt install python3)." >&2
  exit 1
fi

chmod +x "$dir/add-model" "$dir/update-readmes" "$dir/add_model.py" "$dir/update_readmes.py"

# The shell's startup file: ~/.zshrc for zsh, ~/.bashrc for bash, ~/.profile otherwise.
case "$(basename "${SHELL:-sh}")" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
  *)    rc="$HOME/.profile" ;;
esac
touch "$rc"
tmp=$(mktemp)
grep -vF "$marker" "$rc" > "$tmp" || true
printf 'export PATH="%s:$PATH"  %s\n' "$dir" "$marker" >> "$tmp"
cat "$tmp" > "$rc"
rm -f "$tmp"

echo "Added $dir to PATH in $rc."
echo "Open a new terminal (or run: . \"$rc\"), then try:  add-model --help"
