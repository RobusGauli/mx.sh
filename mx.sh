#! /usr/bin/env bash
# TMUX on steroids i.e MX
# Implemented using POSIX-compliant function
{ # ensures the entire script is downloaded #

set -Eeo pipefail

VERSION="v0.6.1-alpha"

# Color codes
NC="\033[0m"
BGREEN='\033[1;32m'

echoerr() {
  cat <<<"$@" 1>&2;
}

mxecho() {
  command printf %s\\n "$*" 2>/dev/null
}

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
import os
import sys

def exists(file):
    return os.path.exists(file)

if exists('mxconf.yaml'):
    import yaml
    parsed = yaml.safe_load(open('mxconf.yaml'))
else:
    import json
    parsed = json.load(open('mxconf.json'))

windowindex, paneindex, key = sys.argv[1:]
windowindex = int(windowindex) - 1
print(parsed["windows"][int(windowindex)]["panes"][int(paneindex)].get(key))
end

}

panesCount() {

python - "$@" <<end
#! /usr/bin/env python
import os
import sys

def exists(file):
    return os.path.exists(file)

if exists('mxconf.yaml'):
    import yaml
    parsed = yaml.safe_load(open('mxconf.yaml'))
else:
    import json
    parsed = json.load(open('mxconf.json'))

windowindex, = sys.argv[1:]
windowindex = int(windowindex) - 1
print(len(parsed["windows"][windowindex]["panes"]))
end

}

createPane() {
  # Positional arguments
  local session="$1"
  local window="$2"
  local windowIndex="$3"
  local paneIndex="$4"

  local windowConfigIndex
  windowConfigIndex=$(("$windowIndex"))

  local workDir
  workDir="$(getPaneVal "$windowConfigIndex" "$paneIndex" "workdir")"

  local size
  size="$(getPaneVal "$windowConfigIndex" "$paneIndex" "size")"

  if [ "_$size" = "_None" ]; then
    size="50"
  fi

  local expandedPath="${workDir/#\~/$HOME}"

  local command
  command="$(getPaneVal "$windowConfigIndex" "$paneIndex" "command")"

  # TODO: Not happy with how command are passed into pane
  if [ "$paneIndex" -eq 0 ]; then
    tmux new-window -c "$expandedPath" -n "$window" -t "${session}:${windowIndex}"
  else
    if [ $(( "$paneIndex" % 2)) -eq 0 ]; then
      tmux split-window -c "$expandedPath" -t "${session}:${windowIndex}" -v -l "$size"
    else
      tmux split-window -c "$expandedPath" -t "${session}:${windowIndex}" -h -l "$size"
    fi
  fi

  # Send keys to pane
  local paneTmuxIndex
  paneTmuxIndex="$(("$paneIndex"))"

  tmux send-keys -t "${session}:${windowIndex}.${paneTmuxIndex}" "$command" C-m
}

createWindow() {
  # Positional arguments
  local session="$1"
  local window="$2"
  local count="$3"

  local configIndex="$(("$count"))"

  local numOfPanes
  numOfPanes=$(panesCount "$configIndex")

  # seq is inclusive
  ((numOfPanes--))

  for paneIdx in $(seq 0 "$numOfPanes"); do
    createPane "$session" "$window" "$count" "$paneIdx"
  done
}

createWindows() {
  local session="$1"
  local windows="$2"

  # starting from index 2 as session creation creates a window with index 1
  local index=1

  for window in $windows; do
    createWindow "$session" "$window" "$index"
    ((index++))
  done
}


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
import os

def exists(file):
    return os.path.exists(file)

if exists('mxconf.yaml'):
    import yaml
    parsed = yaml.safe_load(open('mxconf.yaml'))
else:
    import json
    parsed = json.load(open('mxconf.json'))

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
import os
import sys

def exists(file):
    return os.path.exists(file)

if exists('mxconf.yaml'):
    import yaml
    parsed = yaml.safe_load(open('mxconf.yaml'))
else:
    import json
    parsed = json.load(open('mxconf.json'))

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
    # Check to see if we intend to attach to the session
    if attachDuringStart; then
      tmux attach-session -t "$session"
      exit 0
    fi

    echoerr "session: '${session}' already exists"
    exit 1
  fi

  # Create a new session if it does not exists
  echo "creating new session..."
  createSession "$session"

  windows=$(getWindows)
  createWindows "$session" "$windows"

  # Delete the 0 index window
  tmux kill-window -t "$session":0

  # Attach it to the session if opted
  if attachDuringStart; then
    tmux attach-session -t "$session"
  fi
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
  mxecho 'Usage: mx up [Options]...'
  mxecho
  mxecho '  Starts and provision new mx session'
  mxecho
  mxecho 'Options:'
  mxecho '  --attach/-a             If set, attach to current session automatically'
  mxecho '  --session/-s STRING     Assign a name to new mx session'
  mxecho '  --verbose/-v            Enable verbose mode'
  mxecho '  --help/-h               Show the help message for up subcommand'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx up --session euler --attach    Starts the new session named "euler" and attach to it'
  mxecho '  mx up                             Starts the new session without attaching to it'
  mxecho '  mx up -v                          Starts the new session in verbose mode'
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

up() {
  # Invariant:
  # Requires config file to be on the current directory
  if ! [ -f "mxconf.yaml" ] &&  ! [ -f "mxconf.json" ]; then
    echoerr "configuration file not found."
    echoerr "Run 'mx template --session <name>' to generate template configuration."
    exit 1
  fi

  # Run the function if invariance is not violated
  _up
}

printListHelp() {
  mxecho 'Usage: mx list [Options]...'
  mxecho
  mxecho '  List active mx session(s)'
  mxecho
  mxecho 'Options:'
  mxecho '  --verbose/-v            Enable verbose mode'
  mxecho '  --help/-h               Show the help message for down subcommand'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx list                 Show current active session(s)'
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
  if ! tmux list-sessions >/dev/null 2>/dev/null; then
    echo "session(s) not found"
    return 1
  fi

  local index=0

  while IFS= read -r session; do
    echo "$(green ${index}) => ${session}"
    index=$(("$index" + 1))
  done < <(tmux list-sessions)
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
    tmux attach-session
    exit 0
  fi

  # Invariant:
  # Valid index argument
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
  mxecho 'Usage: mx attach [Options]...'
  mxecho
  mxecho '  Attach to one of the running active mx session(s)'
  mxecho
  mxecho 'Options:'
  mxecho '  --index/-i NUMBER       Attach to the session identified by integer value. Eg: 1'
  mxecho '  --session/-s TEXT       Attach to the session identified by the name'
  mxecho '  --verbose/-v            Enable verbose mode'
  mxecho '  --help/-h               Show the help message for down subcommand'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx attach                 Attach to last session'
  mxecho '  mx attach -s mxproject    Attach to session named "mxproject"'
  mxecho '  mx attach -i 0            Attach to the session identified by index 0'
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
  ["session"]=""
)

down() {
  local all
  all="${downArguments['all']}"

  if [[ "${all}" -eq 1 ]]; then
    tmux kill-server
    exit 0
  fi

  if ! tmux list-sessions >/dev/null 2>&1; then
    echo "no active session(s) to teardown"
    exit 1
  fi

  local session="${downArguments['session']}"

  if [[ -n "$session" ]]; then
    tmux kill-session -t "$session"
    exit
  fi

  local sessionIndex="${downArguments['index']}"

  if ! isNumber "$sessionIndex"; then
    echoerr "invalid '--index' argument"
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
    tmux kill-session -t "$sessionLabel"
  fi
}

printDownHelp() {
  mxecho 'Usage: mx down [Options]...'
  mxecho
  mxecho '  Teardown active mx session(s)'
  mxecho
  mxecho 'Options:'
  mxecho '  --all/-a                Teardown all active mx session(s)'
  mxecho '  --index/-i              Teardown session indentified by index. Eg: 1'
  mxecho '  --session/-s            Teardown session indentified by name. Eg: "mxsession"'
  mxecho '  --verbose/-v            Enable verbose mode'
  mxecho '  --help/-h               Show the help message for down subcommand'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx down --all                Teardown all active mx session(s)'
  mxecho '  mx down --session mxproject  Teardown session named "mxproject"'
  mxecho '  mx down --i 1                Teardown session indexed 1'
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

    "--session" | "-s")
      shift
      downArguments["session"]=$1
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
  mxecho 'Usage: mx COMMAND [ARGS]...'
  mxecho
  mxecho 'Commands:'
  mxecho '  up         Starts and provision new mx session'
  mxecho '  down       Teardown active mx session'
  mxecho '  list       List active mx sessions'
  mxecho '  attach     Attach to one of the active mx session'
  mxecho '  template   Generate a template config file for mx session'
  mxecho '  version    Show version'
  mxecho '  help       Show the help message for a command'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx template --session euler       Generate a new template for project euler'
  mxecho '  mx up --attach                    Starts the new session and automatically attach to it'
  mxecho '  mx attach -i 0                    Attach to session whose index is 0'
  mxecho '  mx down --all                     Destroy all active sessions'
  mxecho '  mx up help                        Show the help message for up subcommand'
  mxecho '  mx list --help                    Show the help message for list subcommand'
  mxecho '  mx attach                         Attach to session recently created'
  mxecho '  mx attach --session euler         Attach to session named "euler"'
}

declare -A templateArguments=(
  ["session"]="mxsession"
  ["filetype"]="json"
)

template() {
  if ! renderTemplate "${templateArguments['session']}"; then
    return 1
  fi

  return 0
}

printTemplateHelp() {
  mxecho 'Usage: mx template [Options]...'
  mxecho
  mxecho '  Generate mx template to bootstrap your session'
  mxecho
  mxecho 'Options:'
  mxecho '  --session/-s STRING     Set a session name'
  mxecho '  --yaml/-y               If enabled, use yaml configuration'
  mxecho '  --json/-j               If enabled, use json configuration(default)'
  mxecho '  --verbose/-v            Enable verbose mode'
  mxecho '  --help/-h               Show the help message for up subcommand'
  mxecho
  mxecho 'Examples:'
  mxecho '  mx template --session euler         Create a template file with session name "euler"'
  mxecho '  mx template --session euler --yaml  Create yaml template file with session name "euler"'
  mxecho '  mx template --session euler --json  Create json template file with session name "euler"'
}

renderTemplate() {

  if [[ -f "mxconf.yaml" ]]; then
    echoerr "'mxconf.yaml' file already exists"
    exit 120
  fi

  if [[ -f "mxconf.json" ]]; then
    echoerr "'mxconf.json' file already exists"
    exit 120
  fi

  filetype="${templateArguments['filetype']}"

  local sessionName="$1"

  if [[ "_${filetype}" = "_yaml" ]]; then


cat <<END >mxconf.yaml
session: $sessionName
windows:
  - name: w1
    panes:
      - workdir: "$(pwd)"
        command: echo "Hey from pane 1"
      - workdir: "$(pwd)"
        command: echo "Hi from pane 2"
  - name: w2
    panes:
      - workdir: "$(pwd)"
        command: htop
      - workdir: "$(pwd)"
        size: 20
        command: |-
          python
      - workdir: "$(pwd)"
        command: |-
          cal
          date
END

else

cat <<END >mxconf.json
{
  "session": "$sessionName",
  "windows": [
    {
      "name": "w1",
      "panes": [
        {
          "workdir": "$(pwd)",
          "command": "echo \"Hey from pane 1\""
        },
        {
          "workdir": "$(pwd)",
          "command": "echo \"Hi from pane 2\""
        }
      ]
    },
    {
      "name": "w2",
      "panes": [
        {
          "workdir": "$(pwd)",
          "command": "htop"
        },
        {
          "workdir": "$(pwd)",
          "size": 20,
          "command": "python"
        },
        {
          "workdir": "$(pwd)",
          "command": "cal\ndate"
        }
      ]
    }
  ]
}
END

fi

cat <<END
A 'mxconf.${filetype}' file has been placed in this directory. You are now
ready to 'mx up'! Please run 'mx up' --help for more details usage.
END

}

parseTemplateCommandArguments() {
  while [[ -n $1 ]]; do
    case "$1" in

    "--session" | "-s")
      shift
      templateArguments["session"]="$1"
      shift
      ;;

    "--json" | "-j")
      shift
      templateArguments["filetype"]="json"
      ;;

    "--yaml" | "-y")
      shift
      templateArguments["filetype"]="yaml"
      ;;

    "help" | "-h" | "--help")
      printTemplateHelp
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

printVersion(){
  mxecho "$VERSION"
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

  "template")
    shift
    parseTemplateCommandArguments "$@"
    currentCommand="template"
    ;;

  "version")
    shift
    currentCommand="version"
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

  "template")
    template
    ;;

  "version")
    printVersion
    exit 0
    ;;

  "help")
    printHelp
    exit 0
    ;;
  esac
}

main "$@"

} # ensures the entire script is downloaded #
