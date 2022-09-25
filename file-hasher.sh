#!/bin/bash

################################################################################
# Author: Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 24th July 2020
# Version: v0.1.0
# Description: Creates md5 hashes for specified files.
################################################################################

#
## Variable declaration
#

BASE_DIR="/home/adminhosts/devadm/rpmbuild/git_sources/sm-staging"
CLIENT_CONFIG_GIT_URL="git@github.wdf.sap.corp:DLM-Org/sm-client-config-linux"
CLIENT_CONFIG_GIT_NAME="$(basename "$CLIENT_CONFIG_GIT_URL")"
PATH_INSIDE_CLIENT_CONFIG_GIT="home/nagios/checkscripts/md5sums"
MD5_FILE_NAME="shellrc"
GIT_FOLDER="$BASE_DIR/$CLIENT_CONFIG_GIT_NAME"
MD5_DIRECTORY_PATH="$GIT_FOLDER/$PATH_INSIDE_CLIENT_CONFIG_GIT"
MD5_FILE_PATH="$MD5_DIRECTORY_PATH/$MD5_FILE_NAME"
CLIENT_CONFIG_SSH_PATH="/home/adminhosts/devadm/jenkins/.ssh/id_rsa"

FILES=( "/etc/bash.bashrc.local"
        "/etc/csh.logout"
        "/root/.bashrc"
        "/root/.bash_profile"
        "/root/.forward"
      )

if [[ "$LIBRARY_DIRECTORY" == "" ]]; then
  LIBRARY_DIRECTORY='/home/adminhosts/bash_libraries'
fi

GIT_DOWNLOADER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/git_downloader.sh"
EXEC_LIBRARY_FQFN="$LIBRARY_DIRECTORY/exec.sh"

LOGGER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/logger.sh"
LOG_LEVEL='VERBOSE'

#
## Import logging module
#

source "$LOGGER_LIBRARY_FQFN"

set_log_level "$LOG_LEVEL"


#
## Import other bash modules
#

source "$GIT_DOWNLOADER_LIBRARY_FQFN"
source "$EXEC_LIBRARY_FQFN"

#
## MAIN SOURCE
#

log_info "Checking if local working directory exists.. ($BASE_DIR)"
if [ ! -d "$BASE_DIR" ]; then
  log_error "Directory $BASE_DIR missing. Creating.."
  COMMAND="mkdir -p '$BASE_DIR'"
  ERROR_MESSAGE="Cannot create directory $BASE_DIR"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'
fi

log_debug "Checking if local dlm client config linux repo exists.."
git_downloader "$CLIENT_CONFIG_GIT_URL" "$BASE_DIR" "$CLIENT_CONFIG_SSH_PATH"

cd "$BASE_DIR"
if [ $? -ne 0 ]; then
  log_fatal "Cannot move into directory $BASE_DIR"
  exit 1
fi

log_debug "Checking if md5 files exists.."
if [ ! -d "$MD5_DIRECTORY_PATH" ]; then

  log_info "md5sums folder missing."
  COMMAND="mkdir -p '$MD5_DIRECTORY_PATH'"
  ERROR_MESSAGE="Cannot create $MD5_DIRECTORY_PATH"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

fi

touch "$MD5_FILE_PATH"
PRESUM="$(md5sum "$MD5_FILE_PATH")"
log_info "Created a pre sum for comparison ($PRESUM)."

# Remove empty lines
perl -i -pe 'chomp if eof && /^$/' "$MD5_FILE_PATH"

log_info "Removing previous md5 file $MD5_FILE_PATH"
COMMAND="rm -f '$MD5_FILE_PATH'"
ERROR_MESSAGE="Cannot remove $MD5_FILE_PATH. Check manually.."
execute "$COMMAND" "$ERROR_MESSAGE" '1'

touch "$MD5_FILE_PATH"
if [ ! -f "$MD5_FILE_PATH" ]; then
  log_fatal "Couldn't create $MD5_FILE_PATH. Check manually.."
  exit 1
fi

for file in ${FILES[@]}; do
  hash="$(md5sum "$GIT_FOLDER/$file" | cut -d ' ' -f1)"
  log_info "Hash for $file is $hash"
  echo "$hash  $file" >> "$MD5_FILE_PATH"
done

perl -i -pe 'chomp if eof && /^$/' "$MD5_FILE_PATH"

POSTSUM="$(md5sum "$MD5_FILE_PATH")"
log_info "Comparing old file ($PRESUM) to new file ($POSTSUM)"

if [[ "$PRESUM" != "$POSTSUM" ]]; then

  log_info "Changes found. Pushing new version back to $CLIENT_CONFIG_GIT_NAME."
  cd "$GIT_FOLDER"
  if [ $? -ne 0 ]; then
    log_error "Cannot move into directory $BASE_DIR/$CLIENT_CONFIG_GIT_NAME"
    exit 1
  fi

  COMMAND="git add ."
  ERROR_MESSAGE="git add failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  COMMAND="git commit -m 'Updated md5sums for shellrc check'"
  ERROR_MESSAGE="git commit failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  COMMAND="git -c core.sshCommand=\"ssh -i '$CLIENT_CONFIG_SSH_PATH'\" push -u origin master"
  ERROR_MESSAGE="git push failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'
else
  log_info "Nothing changed.."
fi

log_debug "Exiting.."

exit 0
