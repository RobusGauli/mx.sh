#!/usr/bin/env bash

VERSION="v0.3-alpha"

if [[ "$EUID" -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if [[ $(uname) = "Darwin" ]]; then
  BIN=/usr/local/bin
else
  BIN=/usr/bin
fi

curl -s https://raw.githubusercontent.com/euclideang/mx.sh/"${VERSION}"/mx.sh -o ${BIN}/mx && chmod +x ${BIN}/mx
echo "Installation complete. Type 'mx' to learn more."
