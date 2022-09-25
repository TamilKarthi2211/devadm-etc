#!/bin/bash

################################################################################
# Author: Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 24th February 2020
# Version: v2.0.0
# Description: Copies all rpm repo files from remote git, creates md5 hash sums
#    for all these repo files and moves them to dlm os client config git repo.
#    Additonally, pushing repo files to adminhosts git repo.
################################################################################

#
## Variable declaration
#

TGZ_FILES_GIT_URL="git@github.wdf.sap.corp:d031543/linux-installers"
TGZ_FILES_GIT_NAME="$(basename "$TGZ_FILES_GIT_URL")"
PATH_INSIDE_TGZ_FILES_GIT="tgz_files"
LINUX_INSTALLER_SSH_PATH="/home/adminhosts/devadm/jenkins/.ssh/linux-installers.jenkins_github.id_rsa"

OS_CONFIG_GIT_URL="git@github.wdf.sap.corp:DLM-Org/sm-client-config-linux"
OS_CONFIG_GIT_NAME="$(basename "$OS_CONFIG_GIT_URL")"
PATH_INSIDE_OS_CONFIG_GIT="home/nagios/checkscripts/md5sums"
OS_CONFIG_SSH_PATH="/home/adminhosts/devadm/jenkins/.ssh/id_rsa"

ADMINHOSTS_GIT_URL="git@github.wdf.sap.corp:DLM-Org/sm_adminhosts"
ADMINHOSTS_GIT_NAME="$(basename "$ADMINHOSTS_GIT_URL")"
PATH_INSIDE_ADMINHOSTS_GIT="devadm/home/nagios/automation/repo-setup"
ADMINHOSTS_SSH_PATH="/home/adminhosts/devadm/jenkins/.ssh/home_adminhosts.jenkins_github.id_rsa"

BASE_DIR="/home/adminhosts/devadm/rpmbuild/git_sources/dlm-repo-config"
LOCAL_REPO_FILES="/home/nagios/automation/repo-setup"

SLES11_DMZWDF="zypp-repos-SLES11-SP4-x86_64-dmzwdf"

if [[ "$LIBRARY_DIRECTORY" == "" ]]; then
  LIBRARY_DIRECTORY='/home/adminhosts/bash_libraries'
fi

GIT_DOWNLOADER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/git_downloader.sh"
EXEC_LIBRARY_FQFN="$LIBRARY_DIRECTORY/exec.sh"

LOGGER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/logger.sh"
LOG_LEVEL='DEBUG'

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

update() {

  log_debug "Checking if repo files folder exists.."
  if [ -d "$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT" ]; then
    sudo chown -R jenkins:jenkins "$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT"
    log_info "Repo files folder exists. Removing repo folders.."

    COMMAND="find '${BASE_DIR:?}/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT' -maxdepth 2 -type f -name SAPREPO.repo -not -ipath '*SLES11*dmzwdf*' -delete"
    ERROR_MESSAGE="Cannot remove SAPREPO repo files inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="find '${BASE_DIR:?}/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT' -maxdepth 2 -type f -name PTF.repo -not -ipath '*SLES11*dmzwdf*' -delete"
    ERROR_MESSAGE="Cannot remove PTF repo files inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="find '${BASE_DIR:?}/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT' -maxdepth 2 -type f -name 'SLES*.repo' -not -ipath '*SLES11*dmzwdf*' -delete"
    ERROR_MESSAGE="Cannot remove SUSE repo files inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  fi

  log_info "Creating repo files folder if missing.."
  COMMAND="mkdir -p '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT'"
  ERROR_MESSAGE="Cannot create $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  log_debug "Checking if md5 files exists.."
  if [ -d "$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT" ]; then

    log_info "md5sums folder exists. Removing md5 files.."
    COMMAND="find '${BASE_DIR:?}/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT' -maxdepth 1 -type f -iname 'zypp-repos-SLES*' -exec rm \"{}\" \;"
    ERROR_MESSAGE="Cannot remove md5 files inside $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  fi

  log_info "Creating md5sums folder if missing.."
  COMMAND="mkdir -p '$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT'"
  ERROR_MESSAGE="Cannot create $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  log_info "Searching for all tgz files inside $BASE_DIR/$TGZ_FILES_GIT_NAME/$PATH_INSIDE_TGZ_FILES_GIT"

  OLDIFS=$IFS
  IFS=$'\n'

  COMMAND="find '$BASE_DIR/$TGZ_FILES_GIT_NAME/$PATH_INSIDE_TGZ_FILES_GIT' -iname '*.tgz' | grep 'wdf' | sed -e 's/\.tgz\$//'"
  execute "$COMMAND"
  echo "$OUTPUT" | while read file; do

    file=$(basename "$file")
    log_info "Archive $file.tgz found. Extracting to $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file"

    COMMAND="mkdir -p '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file'"
    ERROR_MESSAGE="Creating folder $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="tar -xvf '$BASE_DIR/$TGZ_FILES_GIT_NAME/$PATH_INSIDE_TGZ_FILES_GIT/$file.tgz' -C '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file'"
    ERROR_MESSAGE="Extracting $BASE_DIR/$TGZ_FILES_GIT_NAME/$PATH_INSIDE_TGZ_FILES_GIT/$file.tgz to $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    log_info "Removing last lines if they're blank"
    COMMAND="find '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file' -type f -iname '*.repo' -exec perl -i -pe 'chomp if eof && /^$/' {} \;"
    ERROR_MESSAGE="Couldn't remove blank lines at the end of the files"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    log_info "Enabling all repositories inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file"
    COMMAND="find '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file' -iname '*.repo' ! -name 'Misc.repo' -exec sed -i 's/enabled=0/enabled=1/g' {} \;"
    ERROR_MESSAGE="Enabling repositories inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    log_info "Enabling autorefresh for all repositories inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file"
    COMMAND="find '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file' -iname '*.repo' ! -name 'Misc.repo' -exec sed -i 's/autorefresh=0/autorefresh=1/g' {} \;"
    ERROR_MESSAGE="Enabling autorefresh for all repositories inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    wdz_file="$(echo "$file" | sed -e 's/-wdf//')-dmzwdf"
    if ! [[ "$wdz_file" =~ "SLES11" ]]; then

      EXCLUDE_FILES_FOR_DMZ="--exclude='Misc.repo' --exclude='PTF.repo'"
      log_info "Syncing $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file to $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file"
      COMMAND="rsync -avzz $EXCLUDE_FILES_FOR_DMZ '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file/'  '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file/'"
      ERROR_MESSAGE="Copying $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file to $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file failed"
      execute "$COMMAND" "$ERROR_MESSAGE" '1'

      log_info "Building wdz repo urls"
      COMMAND="find '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file' -type f"
      execute "$COMMAND"
      echo "$OUTPUT" | while read wdz_repofile; do

        COMMAND="sed -i 's/http\:\/\/ls0110.wdf.sap.corp:8080\/pub/https\:\/\/bsslrepo.dmzwdf.sap.corp\/repository\/current/g' '$wdz_repofile'"
        ERROR_MESSAGE="Replacing ls0110.wdf.sap.corp:8080 with bsslrepo.dmzwdf.sap.corp in $wdz_repofile failed"
        execute "$COMMAND" "$ERROR_MESSAGE" '1'

      done

    else
      log_info "Skipping dmzwdf repos for SLES 11"
    fi

    log_info "Creating md5sums file"
    COMMAND="touch '$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$file'"
    ERROR_MESSAGE="Cannot create file $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$file"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="touch '$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$wdz_file'"
    ERROR_MESSAGE="Cannot create file $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$wdz_file"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    log_info "Searching for repo files inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file"
    for repofile in "$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file"/*; do

      [[ -e "$repofile" ]] || break
      repofile=$(basename "$repofile")

      log_info "Repo file $repofile found. Creating md5 hash.."
      COMMAND="md5sum '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$file/$repofile' | cut -d' ' -f1"
      execute "$COMMAND"
      md5="$OUTPUT"
      log_debug "Hash is $md5"

      log_debug "Writing hash to md5sums file"
      COMMAND="echo '$repofile $md5' >> '$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$file'"
      ERROR_MESSAGE="Cannot append to $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$file"
      execute "$COMMAND" "$ERROR_MESSAGE" '1'

    done

    log_info "Searching for repo files inside $BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file"
    for repofile in "$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file"/*; do

      [[ -e "$repofile" ]] || break
      repofile=$(basename "$repofile")

      log_info "Repo file $repofile found. Creating md5 hash.."
      COMMAND="md5sum '$BASE_DIR/$ADMINHOSTS_GIT_NAME/$PATH_INSIDE_ADMINHOSTS_GIT/$wdz_file/$repofile' | cut -d' ' -f1"
      execute "$COMMAND"
      md5="$OUTPUT"
      log_debug "Hash is $md5"

      log_debug "Writing hash to md5sums file"
      COMMAND="echo '$repofile $md5' >> '$BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$wdz_file'"
      ERROR_MESSAGE="Cannot append to $BASE_DIR/$OS_CONFIG_GIT_NAME/$PATH_INSIDE_OS_CONFIG_GIT/$wdz_file"
      execute "$COMMAND" "$ERROR_MESSAGE" '1'

    done

  done

  IFS=$OLDIFS

  log_info "Pushing changes to $ADMINHOSTS_GIT_URL.."
  cd "$BASE_DIR/$ADMINHOSTS_GIT_NAME"
  if [ $? -ne 0 ]; then
    log_fatal "Cannot move into directory $BASE_DIR/$ADMINHOSTS_GIT_NAME"
    exit 1
  fi

  COMMAND="git add ."
  ERROR_MESSAGE="git add failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  log_debug "Cheching if something to commit.."
  COMMAND='git status --porcelain'
  execute "$COMMAND"
  if [ "$OUTPUT" != "" ]; then
    log_info "Found changes. Commiting.."

    COMMAND="git commit -m 'Updated rpm repo files'"
    ERROR_MESSAGE="git commit failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="git -c core.sshCommand=\"ssh -i '$ADMINHOSTS_SSH_PATH'\" push -u origin master"
    ERROR_MESSAGE="git push failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  else
    log_info "Nothing to commit."
  fi

  log_info "Pushing changes to $OS_CONFIG_GIT_URL.."
  cd "$BASE_DIR/$OS_CONFIG_GIT_NAME"
  if [ $? -ne 0 ]; then
    log_error "Cannot move into directory $BASE_DIR/$OS_CONFIG_GIT_NAME"
    exit 1
  fi

  COMMAND="git add ."
  ERROR_MESSAGE="git add failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  echo "Cheching if something to commit.."
  COMMAND="git status --porcelain"
  execute "$COMMAND"
  if [ "$OUTPUT" != "" ]; then
    echo "Changes found. Commiting.."

    COMMAND="git commit -m 'Updated md5sums for rpm repos'"
    ERROR_MESSAGE="git commit failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    COMMAND="git -c core.sshCommand=\"ssh -i '$OS_CONFIG_SSH_PATH'\" push -u origin master"
    ERROR_MESSAGE="git push failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

  else
    log_info "Nothing to commit."
  fi

  log_debug "Exiting.."
}

sapmnt_copy (){
  #Repo files in sapmnt share will be used for SP upgrade
  log_info "Copying repo files to sapmnt share"
  COMMAND="rsync -arpt $LOCAL_REPO_FILES/ $SAPMNT_REPO_FILES/"
  ERROR_MESSAGE="Failed top copy repo files to sapmnt share"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'
}

log_info "Checking if local working directory exists.. ($BASE_DIR)"
if [ ! -d "$BASE_DIR" ]; then
  log_error "Directory $BASE_DIR missing. Creating.."
  COMMAND="mkdir -p '$BASE_DIR'"
  ERROR_MESSAGE="Cannot create directory $BASE_DIR"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'
fi

log_info "Checking if local version of linux-installers repo exists"

log_debug "Checking if local dlm adminhosts repo exists.."
git_downloader "$ADMINHOSTS_GIT_URL" "$BASE_DIR" "$ADMINHOSTS_SSH_PATH"

log_debug "Checking if local dlm client config linux repo exists.."
git_downloader "$OS_CONFIG_GIT_URL" "$BASE_DIR" "$OS_CONFIG_SSH_PATH"

cd "$BASE_DIR"
if [ $? -ne 0 ]; then
  log_fatal "Cannot move into directory $BASE_DIR"
  exit 1
fi

if [ ! -d "$TGZ_FILES_GIT_NAME" ]; then

  log_error "Directory not found. Cloning from remote.. ($TGZ_FILES_GIT_URL)"

  COMMAND="git clone '$TGZ_FILES_GIT_URL'"
  ERROR_MESSAGE="git clone failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  update

else

  log_info "Directory found. Searching for updates on remote branch.."

  cd "$TGZ_FILES_GIT_NAME"
  if [ $? -ne 0 ]; then
    log_fatal "Cannot move into directory $TGZ_FILES_GIT_NAME"
    exit 1
  fi

  COMMAND="git -c core.sshCommand=\"ssh -i '$LINUX_INSTALLER_SSH_PATH'\" remote update"
  ERROR_MESSAGE="git remote update failed"
  execute "$COMMAND" "$ERROR_MESSAGE" '1'

  COMMAND="git status -uno | grep -q 'branch is behind'"

  if execute "$COMMAND"; then

    log_info "Update found. Pulling from remote.. ($TGZ_FILES_GIT_URL)"

    COMMAND="git -c core.sshCommand=\"ssh -i '$LINUX_INSTALLER_SSH_PATH'\" pull"
    ERROR_MESSAGE="git pull failed"
    execute "$COMMAND" "$ERROR_MESSAGE" '1'

    update
    #sapmnt_copy
    
  else

    COMMAND="diff -qrN $BASE_DIR/$ADMINHOSTS_GIT_NAME/ $LOCAL_REPO_FILES"
    execute "$COMMAND"

    if [[ "$OUTPUT" != "" ]]; then

      log_info "Update within git repo files found comparing $BASE_DIR/$ADMINHOSTS_GIT_NAME and $LOCAL_REPO_FILES"

      update

    else
      log_info "Nothing to do. Exiting."
    fi

  fi

fi

exit 0
