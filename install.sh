#!/usr/bin/env bash
{

os=$(uname)

if [[ "$os" = "Darwin" ]]; then
  BIN=/usr/local/bin
  CURL=curl
else
  # check if user is root
  # and re-exec the script with sudo if not
  #
  # equivalent to: [ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"
  # bash only, but without external call to whoami
  #
  (( EUID != 0 )) && exec sudo -- "$0" "$@"
  BIN=/usr/bin
  CURL="sudo curl"
fi

echo "Installing with"
$CURL -s https://raw.githubusercontent.com/RobusGauli/mx.sh/master/mx.sh?token=ADDJYDQUXQCMVDIS6WQNB2S7RWP3G -o $BIN/mx && chmod +x $BIN/mx
echo "with successfully installed!"

}
