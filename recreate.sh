#!/bin/bash

################################################################################
# Author: Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 20th February 2020
# Version: v1.2.1
# Description: Removes and recreates a file or folder
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

recreate_file() {
  # $1: filepath

  #
  ## Variable declaration
  #

  FILEPATH="$1"
  if [[ "$FILEPATH" == "" ]]; then
    log_fatal "Cannot recreate file without path"
    exit 1
  fi

  BASE_DIR="$(dirname "$FILEPATH")"
  if [ ! -d "$BASE_DIR" ]; then
    log_info "Creating basedir $BASE_DIR since it does not exists"
    COMMAND="mkdir -p '$BASE_DIR'"
    ERROR_MESSAGE="Cannot create $BASE_DIR"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'
  fi

  log_info "Create/Clear $FILEPATH"
  COMMAND="> '$FILEPATH'"
  ERROR_MESSAGE="Cannot clear $FILEPATH"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  if [ ! -f "$FILEPATH" ] || [ -s "$FILEPATH" ]; then
    log_fatal "$FILEPATH is not an empty file"
    exit 1
  fi

}

recreate_directory() {
  # $1: filepath

  #
  ## Variable declaration
  #

  FILEPATH="$1"
  if [[ "$FILEPATH" == "" ]]; then
    log_fatal "Cannot recreate directory without path"
    exit 1
  fi

  log_debug "Checking if $FILEPATH exists"
  if [ -d "$FILEPATH" ]; then
    log_info "Removing $FILEPATH"
    COMMAND="rm -rf '$FILEPATH'"
    ERROR_MESSAGE="Cannot remove $FILEPATH"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'
  fi

  if [ -e "$FILEPATH" ]; then
    log_fatal "$FILEPATH is no directory"
    exit 1
  fi

  log_info "Creating $FILEPATH"
  COMMAND="mkdir -p '$FILEPATH'"
  ERROR_MESSAGE="Cannot create $FILEPATH!"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

}
