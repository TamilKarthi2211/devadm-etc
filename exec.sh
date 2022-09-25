#!/bin/bash

################################################################################
# Author: Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 24th February 2020
# Version: v1.0.0
# Description: Used to exec and log commands
################################################################################

if [[ "$LOGGER_LIBRARY_FQFN" == "" || ! -f  "$LOGGER_LIBRARY_FQFN" ]]; then
  if [[ "$LIBRARY_DIRECTORY" == "" ]]; then
    LIBRARY_DIRECTORY='/home/adminhosts/bash_libraries'
  fi
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
## MAIN SOURCE
#

execute() {
  # $1 : Command
  # $2 : Error message
  # $3 : Exit on error with this exit code

  # Get passed command
  COMMAND="$1"
  ERROR_MESSAGE="$2"
  EXIT_CODE_ON_ERROR="$3"

  log_verbose "Command: $COMMAND"

  # Execute command
  OUTPUT="$(eval "$COMMAND")"
  STATUS="$?"

  # Echo output from command
  if [[ "$OUTPUT" != "" ]]; then
    log_verbose "Output: $(echo -e "$OUTPUT")"
  fi

  log_verbose "Status Code: $STATUS"

  if [ $STATUS -ne 0 ] && [[ "$ERROR_MESSAGE" != "" ]]; then
    if [[ "$EXIT_CODE_ON_ERROR" == "" ]]; then
      log_error "$ERROR_MESSAGE"
    else
      log_fatal "$ERROR_MESSAGE"
      exit "$EXIT_CODE_ON_ERROR"
    fi
  fi

  return "$STATUS"

}
