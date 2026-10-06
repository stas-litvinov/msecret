#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${PREFIX:=$HOME/.local}"
swift build -c release
bin_dir=$(swift build -c release --show-bin-path)
mkdir -p "$PREFIX/bin"
install -m 755 "$bin_dir/msecret" "$PREFIX/bin/msecret"
printf 'Installed %s/bin/msecret. Ensure this directory is on PATH.\n' "$PREFIX"
