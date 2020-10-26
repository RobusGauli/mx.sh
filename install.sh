#!/usr/bin/env bash

VERSION="v0.5-alpha"

if [[ "$EUID" -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if [[ $(uname) = "Darwin" ]]; then
  BIN=/usr/local/bin
else
  BIN=/usr/bin
fi
url="https://raw.githubusercontent.com/RobusGauli/mx.sh/$VERSION/mx.sh"
curl -s "$url" -o "$BIN"/mx && chmod +x "$BIN"/mx
echo "Installation complete. Type 'mx' to learn more."
