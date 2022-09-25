#!/bin/bash

################################################################################
# Author: Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 20th February 2020
# Version: v1.0.0
# Description: Can be used to clone-pull a repo
################################################################################

if [[ "$LOGGER_LIBRARY_FQFN" == "" || ! -f  "$LOGGER_LIBRARY_FQFN" ]]; then
  if [[ "$LIBRARY_DIRECTORY" == "" ]]; then
    LIBRARY_DIRECTORY='/home/adminhosts/bash_libraries'
  fi
  EXEC_LIBRARY_FQFN="$LIBRARY_DIRECTORY/exec.sh"
  LOGGER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/logger.sh"
fi

if [[ "$LOG_LEVEL" == "" ]]; then
  LOG_LEVEL='DEBUG'
fi

#
## Import logging module
#

source "$LOGGER_LIBRARY_FQFN"
set_log_level "$LOG_LEVEL"

#
## Import other bash modules
#

source "$EXEC_LIBRARY_FQFN"

#
## MAIN SOURCE
#

git_downloader() {
  # $1: git url
  # $2: local directory path
  # optional: $3: git ssh key filepath

  #
  ## Variable declaration
  #

  GIT_URL="$1"
  GIT_NAME="$(basename "$GIT_URL")"
  DIRECTORY="$2"
  KEY_FP="$3"

  log_debug "Downloading repo from url $GIT_URL.."

  if [ ! -d "$DIRECTORY/$GIT_NAME" ]; then
    # Used to determine if need to do something
    CHANGES=1

    log_info "Local repo is missing. Cloning from $GIT_URL.."
    cd "$DIRECTORY"
    if [ $? -ne 0 ]; then
      log_fatal "Cannot move into directory $DIRECTORY. Exiting.."
      exit 1
    fi

    if [[ "$KEY_FP" == "" ]]; then
      COMMAND="git clone \"$GIT_URL\""
    else
      log_debug "Cloning with ssh key from $KEY_FP"
      COMMAND="git -c core.sshCommand=\"ssh -i '$KEY_FP'\" clone \"$GIT_URL\""
    fi
    ERROR_MESSAGE="Cannot clone repo ($GIT_URL)"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  else
    log_info "Local repo exists. Pulling.."

    cd "$DIRECTORY/$GIT_NAME"
    if [ $? -ne 0 ]; then
      log_fatal "Cannot move into directory $DIRECTORY/$GIT_NAME. Exiting.."
      exit 1
    fi

    if [[ "$KEY_FP" == "" ]]; then
      COMMAND="git fetch --all"
    else
      log_debug "Fetching with ssh key from $KEY_FP"
      COMMAND="git -c core.sshCommand=\"ssh -i '$KEY_FP'\" fetch --all"
    fi
    ERROR_MESSAGE="Cannot fetch. Try to continue.."
    execute "$COMMAND" "$ERROR_MESSAGE"
    COMMAND="git reset --hard origin/master"
    ERROR_MESSAGE="Cannot reset. Try to continue.."
    execute "$COMMAND" "$ERROR_MESSAGE"

    if [[ "$KEY_FP" == "" ]]; then
      COMMAND="git pull"
    else
      log_debug "Pulling with ssh key from $KEY_FP"
      COMMAND="git -c core.sshCommand=\"ssh -i '$KEY_FP'\" pull"
    fi
    ERROR_MESSAGE="Cannot pull from remote branch $GIT_URL. Exiting.."
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  fi

}
