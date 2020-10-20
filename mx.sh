#! /usr/bin/env bash
# TMUX on steroids i.e MX
# Implemented using POSIX-compliant function
{ # ensures the entire script is downloaded #

set -Eeo pipefail

# Color codes
NC="\033[0m"
BGREEN='\033[1;32m'


# Name of the configuration file
CONFIG_FILE=${MX_CONFIG_FILE:-mxconf.yaml}

green() {
  printf "$BGREEN%s$NC" "$1"
}

hasSession() {
  local session=$1
  if tmux has-session -t "$session" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

createSession() {
  local session="$1"
  tmux new-session -s "$session" -d
}

getPaneVal() {

python - "$@" <<end
#! /usr/bin/env python
import yaml
import sys
parsed = yaml.safe_load(open('mxconf.yaml'))
windowindex, paneindex, key = sys.argv[1:]
print(parsed["windows"][int(windowindex)]["panes"][int(paneindex)].get(key))
end

}

panesCount() {

python - "$@" <<end
#! /usr/bin/env python
import yaml
import sys
parsed = yaml.safe_load(open('mxconf.yaml'))
windowindex,  = sys.argv[1:]
print(len(parsed["windows"][int(windowindex)]["panes"]))
end

}




createPane() {
  local session="$1"
  local window="$2"
  local windowIndex="$3"
  local paneIndex="$4"

  local windowConfigIndex
  windowConfigIndex=$(("$windowIndex"-2))

  local workDir
  workDir="$(getPaneVal "$windowConfigIndex" "$paneIndex" "workdir")"

  local size
  size="$(getPaneVal "$windowConfigIndex" "$paneIndex" "size")"
  local expandedPath="${workDir/#\~/$HOME}"

  local command
  command="$(getPaneVal "$windowConfigIndex" "$paneIndex" "command")"

  # TODO: not happy with how command are passed into pane
  if [ "$paneIndex" -eq 0 ]; then
    tmux new-window -c "$expandedPath" -n "$window" -t "${session}:${windowIndex}"
  else
    if [ "_$size" = "_None" ]; then
      size="50"
    fi
    if [ $(( "$paneIndex" % 2)) -eq 0 ]; then
      tmux split-window -c "$expandedPath" -t "${session}:${windowIndex}" -v -l "$size"
    else
      tmux split-window -c "$expandedPath" -t "${session}:${windowIndex}" -h -l "$size"
    fi
  fi

  # send keys to pane
  local paneTmuxIndex
  paneTmuxIndex="$(("$paneIndex" + 1))"

  tmux send-keys -t "${session}:${windowIndex}.${paneTmuxIndex}" "$command" C-m
}

createWindow() {
  local session="$1"
  local window="$2"
  local count="$3"
  local configIndex="$(("$count" - 2))"

  local numOfPanes
  numOfPanes=$(panesCount "$configIndex")

  ((numOfPanes--))

  for paneIdx in $(seq 0 "$numOfPanes"); do
    createPane "$session" "$window" "$count" "$paneIdx"
  done
}

createWindows() {
  local session="$1"
  local windows="$2"
  # starting from index 2 as session creation creates a window with index 1
  local index=2
  for window in $windows; do
    createWindow "$session" "$window" "$index"
    ((index++))
  done
}

echoerr() { cat <<<"$@" 1>&2; }

isEmpty() {
  local val="$1"
  if [ "$val" = "" ]; then
    return 0
  fi
  return 1
}

isVerbose() {
  if [ "${globalArguments['verbose']}" -eq 1 ]; then
    return 0
  fi
  return 1
}


sessionName() {

python - <<END
#! /usr/bin/env python
import yaml
parsed = yaml.safe_load(open('mxconf.yaml'))
print(parsed['session'])
END

}
# Returns name of the session. It tries to parse from the command line argument and fallbacks to yaml configuration.
getSession() {
  if [ -n "${startArguments['session']}" ]; then
    echo "${startArguments['session']}"
    return 0
  fi

  local session
  session=$(sessionName)

  if [ -z "$session" ]; then
    return 1
  fi

  echo "$session"
}

# Returns whether to attach to the currently running tmux session
attachDuringStart() {
  if [ "${startArguments['attach']}" -eq 1 ]; then
    return 0
  fi
  return 1
}


getWindows() {

python - <<END
#! /usr/bin/env python
import yaml
parsed = yaml.safe_load(open('mxconf.yaml'))
print('\n'.join([ window['name'] for window in parsed["windows"] ]))
END

}
_up() {
  local session
  session=$(getSession)

  if isEmpty "$session"; then
    echoerr "missing argument: 'session'"
    exit 1
  fi

  if hasSession "$session"; then
    # check to see if we intend to attach to the session
    if attachDuringStart; then
      tmux attach-session -t "$session"
      exit 0
    fi
    echoerr "session: '${session}' already exists"
    exit 1
  fi

  # create a new session if it does not exists
  echo "creating new session..."
  createSession "$session"

  windows=$(getWindows)
  createWindows "$session" "$windows"

  # attach it to the session
  if attachDuringStart; then tmux attach-session -t "$session"; fi
}

declare -A globalArguments=(
  ["verbose"]=0
)

declare -A startArguments=(
  # Name of the session, defaults to `name` in config.yml
  ["session"]=""
  # Whether to attach to the session during start
  ["attach"]=0
)

printUpCommandHelp() {
  echo "start command help"
}

parseUpCommandArguments() {
  while [[ -n $1 ]]; do
    case "$1" in

    "--session" | "-s")
      shift
      startArguments["session"]="$1"
      shift
      ;;

    "help" | "-h" | "--help")
      printUpCommandHelp
      exit
      ;;

    "--attach" | "-a")
      shift
      startArguments["attach"]=1
      ;;

    "--verbose" | "-v")
      shift
      globalArguments["verbose"]=1
      ;;

    *)
      echoerr "unknown argument: ${1}"
      exit 1
      ;;
    esac
  done
}

# start entry path
up() {
  # requires config file to be on the current directory
  if ! [ -e "$CONFIG_FILE" ]; then
    echoerr "configuration file not found: 'mxconf.yaml'"
    exit 1
  fi
  _up
}

printListHelp() {
  printf "printing list help\n"
}

parseListCommandArguments() {
  while [[ -n $1 ]]; do
    case "$1" in

    "help" | "-h" | "--help")
      printListHelp
      exit
      ;;

    "--verbose" | "-v")
      shift
      globalArguments["verbose"]=1
      ;;

    *)
      echoerr "unknown argument: ${1}"
      exit 1
      ;;
    esac
  done
}

list() {
  _list
}

_list() {
  if ! tmux list-sessions >/dev/null 2>/dev/null; then
    echo "session(s) not found"
    return 1
  fi
  local index=0
  while IFS= read -r session; do
    echo "$(green ${index}) => ${session}"
    index=$(("$index" + 1))
  done < <(tmux list-sessions)

  #if [[ $1 = "kill" ]]; then
  #tmux kill-server
  #return 0
  #fi
  #if ! [[ $1 =~ '^[0-9]+$' ]]; then
  #echo "error: argument must be number" >&2
  #return 1
  #fi
  #if tmux list-sessions 2>/dev/null >/dev/null; then
  #local sessionIndex="$1"
  #local sessions="$(tmux list-sessions)"
  #local numOfSessions="$(tmux list-sessions | wc -l)"
  #local index=0
  #local parsedSessionLabel=""
  #if [[ -n "${sessionIndex}" ]]; then
  #if [[ "$sessionIndex" -lt "$numOfSessions" ]]; then
  #local counter=0
  #while IFS= read -r session; do
  #if [[ "$counter" -eq "$sessionIndex" ]]; then
  #local sessionLabel="$(grep -o '.*:\s' <<< $session)"
  #parsedSessionLabel="${sessionLabel%:*}"
  #break
  #fi
  #((counter++))
  #done <<< "$sessions"
  #fi
  #fi
  #fi
  #if [[ -n $parsedSessionLabel ]]; then
  #tmux attach-session -t "${parsedSessionLabel}"
  #fi
  #print the list of currently running session with it's index
}

declare -A attachArguments=(
  ["session"]=""
  ["index"]=""
)

isNumber() {
  local arg="$1"
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

attach() {
  if ! tmux list-sessions >/dev/null 2>&1; then
    echo "no active session(s) to attach"
    exit 1
  fi

  local session="${attachArguments['session']}"
  if [[ -n "$session" ]]; then
    # attach to the session and exit
    tmux attach-session -t "$session"
    exit
  fi

  local sessionIndex="${attachArguments['index']}"

  if ! isNumber "$sessionIndex"; then
    echoerr "invalid '--index' argument, number required"
    exit 1
  fi

  # valid index argument
  local totalSessions
  totalSessions=$(tmux list-sessions | wc -l)

  if [[ "$sessionIndex" -ge "totalSessions" ]]; then
     echoerr "invalid '--index' argument, index must be in range"
     exit 1
  fi

  i=0
  local sessionLabel=""
  while IFS= read -r s; do
    if [[ "$i" -eq "$sessionIndex" ]]; then
      sessionLabel="$(grep -oP '^.*(?=:\s)' <<< "$s")"
      break
    fi
    i=$(("$i" + 1))
  done < <(tmux list-sessions)

  if [[ -n "$sessionLabel" ]]; then
    tmux attach-session -t "$sessionLabel"
  fi
}

printAttachHelp() {
  echo "this is going to be attach help"
}

parseAttachCommandArguments() {
  while [[ -n $1 ]]; do
    case "$1" in

    "--session" | "-s")
      shift
      attachArguments["session"]=$1
      shift
      ;;

    "--index" | "-i")
      shift
      attachArguments["index"]=$1
      shift
      ;;

    "help" | "-h" | "--help")
      printAttachHelp
      exit
      ;;

    "--verbose" | "-v")
      shift
      globalArguments["verbose"]=1
      ;;

    *)
      echoerr "unknown argument: ${1}"
      exit 1
      ;;
    esac
  done
}


declare -A downArguments=(
  ["all"]=0
  ["index"]=""
)

down() {
  local all
  all="${downArguments['all']}"
  if [[ "${all}" -eq 1 ]]; then
    tmux kill-server
  fi
}

printDownHelp() {
  echo "print down help"
}

parseDownCommandArguments() {
  while [[ -n $1 ]]; do
    case "$1" in

    "--all" | "-A")
      shift
      downArguments["all"]=1
      ;;

    "--index" | "-i")
      shift
      downArguments["index"]=$1
      shift
      ;;

    "help" | "-h" | "--help")
      printDownHelp
      exit
      ;;

    "--verbose" | "-v")
      shift
      globalArguments["verbose"]=1
      ;;

    *)
      echoerr "unknown argument: ${1}"
      exit 1
      ;;
    esac
  done
}

printHelp() {
  echo "print help message"
}

# will be set by parseCommand
currentCommand=""

parseCommand() {
  local command="$1"

  case "$command" in
  "up")
    # parse up command arguments
    shift
    parseUpCommandArguments "$@"
    currentCommand="up"
    ;;

  "list")
    shift
    parseListCommandArguments "$@"
    currentCommand="list"
    ;;

  "attach")
    shift
    parseAttachCommandArguments "$@"
    currentCommand="attach"
    ;;

  "down")
    shift
    parseDownCommandArguments "$@"
    currentCommand="down"
    ;;

  "help")
    shift
    printHelp
    exit 0
    ;;

  *)
    printHelp
    exit 0
    ;;
  esac
}

main() {
  parseCommand "$@"
  if isVerbose; then
    set -x
  fi
  case "$currentCommand" in
  "up")
    up
    ;;

  "list")
    list
    ;;

  "attach")
    attach
    ;;

  "down")
    down
    ;;

  "help")
    printHelp
    exit 0
    ;;
  esac
}

main "$@"

} # ensures the entire script is downloaded #
