#!/bin/bash

################################################################################
# Authors:  Sudhir Raghuwanshi (i320398) s.raghuwanshi@sap.com
#           Simon Deckwert (i511727) simon.deckwert@sap.com
# Release: 8th April 2020
# Version: v4.0
# Description: Pushes files to linux and windows servers that are not maintained
#         by the dlm repo.
# Former: sync_check_scripts.sh
################################################################################

#
## Variable declaration
#

OS_TYPE="$1"

BASE_DIR='/tmp/nagios_sync'

API_CREDENTIALS='dlm:pw4remL#'
API_FQDN='api.infra-mon.c.eu-de-1.cloud.sap'
API_URL="https://$API_FQDN/rest/v1?lob=DLM&command=get_hosts&host_group="

HOST_TEMP_FOLDER="$BASE_DIR/hosts"
get_hostlist_fp() {
  IDENTIFIER="$1"
  echo "${HOST_TEMP_FOLDER}/${IDENTIFIER}_hosts"
}

FILES_LIST="$BASE_DIR/files_to_copy_${OS_TYPE}"

TRANSFER_OUTPUT_DIRECTORY="$BASE_DIR/stdout/${OS_TYPE}"
TRANSFER_ERROR_DIRECTORY="$BASE_DIR/stderr/${OS_TYPE}"

HOST_OUTPUT_CACHE="$BASE_DIR/${OS_TYPE}_file_sync_cache"
FILE_LIST_CACHE="$BASE_DIR/${OS_TYPE}_file_list_cache"

PSCP_TIMEOUT='120'
RPSYNC_TIMEOUT='150'

USER_ID="DL_011000358700000410012012E" #sm_all
#CC_ID="DL_51B1B352DF15DB58440015CF" # CoE
HEADLINE="DLM - Nagios File Sync ${OS_TYPE^}"
SUBJECT="Nagios File Sync ${OS_TYPE^}"
USER_MAIL="${USER_ID}@exchange.sap.corp"
#CC_MAIL="${CC_ID}@exchange.sap.corp"
ATTACHMENT_FP="$BASE_DIR/attachment_${OS_TYPE}.csv"
ATTACHMENT_CHECKSCRIPTS_FP="$BASE_DIR/attachment_${OS_TYPE}_checkscripts.csv"


if [[ "$OS_TYPE" == 'windows' ]]; then

  #WINDOWS_LOCAL_GIT_STORAGE='/home/adminhosts/devadm/rpmbuild/git_sources/windows'
  WINDOWS_LOCAL_GIT_STORAGE='/home/windows'
  WINDOWS_GIT_INTERNAL_PATH=''
  WINDOWS_FIND_ARGUMENTS='-mindepth 1 -type f -mmin -2 -regextype awk -regex ".*(/Nagios/.*|/root/.*|/patching/automation/.*|/bginfo/default_DLM.bgi)$" -not -iname "*_nsclient.ps1" -not -name "README.md"'

  WINDOWS_CHECKSUM_DIRECTORY="$BASE_DIR/checksums_windows/"

  PSCP_ARGUMENTS="-r -o '$TRANSFER_OUTPUT_DIRECTORY' -e '$TRANSFER_ERROR_DIRECTORY' -t '$PSCP_TIMEOUT' -x -p"

  WIN_API_IDENTIFIER='windows'

fi

if [[ "$OS_TYPE" == 'linux' ]]; then

  LINUX_SOURCES='/home/nagios'
  LINUX_CHECKSCRIPT_SOURCES="$LINUX_SOURCES/checkscripts"
  LINUX_FIND_ARGUMENTS='-mindepth 1 -maxdepth 1 -iname checkscripts -o -iname perfdata -o -iname dlmscripts -o -iname .ssh'
  LINUX_DESTINATION_FQFP='/home/nagios'

  CHECKSCRIPTS_SUFFIX='_checkscripts'

  PRSYNC_INCLUDE_FILES="-X --include='authorized_keys' -X --include='config' -X --include='known_hosts' -X --include='.gitkeep'"
  PRSYNC_EXCLUDE_FILES="-X --exclude='*~' -X --exclude='.ssh/*' -X --exclude='perfata/var/*'"
  PRSYNC_ARGUMENTS="-avzz -X --inplace -r -o '$TRANSFER_OUTPUT_DIRECTORY' -e '$TRANSFER_ERROR_DIRECTORY' -t '$RPSYNC_TIMEOUT' $PRSYNC_INCLUDE_FILES $PRSYNC_EXCLUDE_FILES"
  PSCP_ARGUMENTS="-r -o '$TRANSFER_OUTPUT_DIRECTORY$CHECKSCRIPTS_SUFFIX' -e '$TRANSFER_ERROR_DIRECTORY$CHECKSCRIPTS_SUFFIX' -t '$PSCP_TIMEOUT' -x -p"

  RH_API_IDENTIFIER='redhat'
  #SUSE_API_IDENTIFIER='suse'
  DEB_API_IDENTIFIER='debian'
  UBU_API_IDENTIFIER='ubuntu'
  UNIX_API_IDENTIFIER='unix'
  OLD_SLES_IDENTIFIER='old_sles'
  COMBINED_IDENTIFIER='combined'

  OLD_SLES_SOURCE_HOSTLIST='/home/adminhosts/assets/OLD_SLES_HOSTS.txt'

fi

if [[ "$LIBRARY_DIRECTORY" == "" ]]; then
  LIBRARY_DIRECTORY='/home/adminhosts/bash_libraries'
fi

GIT_DOWNLOADER_LIBRARY_FQFN="$LIBRARY_DIRECTORY/git_downloader.sh"
RECREATE_LIBRARY_FQFN="$LIBRARY_DIRECTORY/recreate.sh"
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
source "$RECREATE_LIBRARY_FQFN"
source "$EXEC_LIBRARY_FQFN"

#
## Debug output
#

log_debug "OS Type: $OS_TYPE"
log_debug "Nagios URL: $API_FQDN"

#
## Download and create host lists
#

download_hosts() {
  # $1: API identifier
  API_IDENTIFIER="$1"
  HOSTLIST="$(get_hostlist_fp "$API_IDENTIFIER")"

  if [[ "$API_IDENTIFIER" != "" ]]; then
    recreate_file "$HOSTLIST"
    log_info "Writing $API_IDENTIFIER hosts from $API_URL$WIN_API_IDENTIFIER to $HOSTLIST"
    COMMAND="curl --noproxy '$API_FQDN' -ks -u '$API_CREDENTIALS' '$API_URL$API_IDENTIFIER' | cut -d ';' -f1 | sed -n '1!p' > '$HOSTLIST'"
    ERROR_MESSAGE="Cannot download or write $API_IDENTIFIER host list"
    execute "$COMMAND" "$ERROR_MESSAGE" '12'
  fi
}

append() {
  # $1: hostlist
  IDENTIFIER="$1"
  HOSTLIST="$(get_hostlist_fp "$IDENTIFIER")"
  COMBINED_HOSTLIST="$(get_hostlist_fp "$COMBINED_IDENTIFIER")"

  if [[ "$IDENTIFIER" != '' ]] && [ -f "$HOSTLIST" ]; then
    log_info "Concat $HOSTLIST to $COMBINED_HOSTLIST"
    COMMAND="cat $HOSTLIST >> '$COMBINED_HOSTLIST'"
    ERROR_MESSAGE="Cannot concat $HOSTLIST to $COMBINED_HOSTLIST"
    execute "$COMMAND" "$ERROR_MESSAGE" '14'
  fi
}

if [[ "$OS_TYPE" == 'windows' ]]; then
  download_hosts "$WIN_API_IDENTIFIER"
fi

if [[ "$OS_TYPE" == 'linux' ]]; then
  download_hosts "$UNIX_API_IDENTIFIER"
  download_hosts "$SUSE_API_IDENTIFIER"
  download_hosts "$RH_API_IDENTIFIER"
  download_hosts "$DEB_API_IDENTIFIER"
  download_hosts "$UBU_API_IDENTIFIER"

  if [[ "$OLD_SLES_IDENTIFIER" != "" && "$OLD_SLES_SOURCE_HOSTLIST" != "" && -s "$OLD_SLES_SOURCE_HOSTLIST" ]]; then
    OLD_SLES_HOSTLIST="$(get_hostlist_fp "$OLD_SLES_IDENTIFIER")"
    recreate_file "$OLD_SLES_HOSTLIST"
    log_info "Checking for suse servers with old sles version"
    OLDIFS=$IFS
    IFS=$'\n'
    for server in $(cat "$OLD_SLES_SOURCE_HOSTLIST"); do
      log_info "Checking for port 22 on server $server"
      COMMAND="nc -z '$server' 22 2>/dev/null"
      if execute "$COMMAND"; then
        log_debug "Port 22 avaiable"
        COMMAND="echo '$server' >> '$OLD_SLES_HOSTLIST'"
        ERROR_MESSAGE="Cannot add line $server to $OLD_SLES_HOSTLIST"
        execute "$COMMAND" "$ERROR_MESSAGE" '13'
      fi
    done
    IFS=$OLDIFS
  fi

  recreate_file "$(get_hostlist_fp "$COMBINED_IDENTIFIER")"
  log_info "Combining hostlists to $(get_hostlist_fp "$COMBINED_IDENTIFIER")"
  append "$UNIX_API_IDENTIFIER"
  append "$SUSE_API_IDENTIFIER"
  append "$OLD_SLES_IDENTIFIER"
  append "$RH_API_IDENTIFIER"
  append "$DEB_API_IDENTIFIER"
  append "$UBU_API_IDENTIFIER"
fi

#
## Creating file lists
#

if [[ "$OS_TYPE" == 'windows' ]]; then
  log_info "Collecting files for windows from $WINDOWS_LOCAL_GIT_STORAGE/$WINDOWS_GIT_INTERNAL_PATH in $FILES_LIST"
  COMMAND="find '$WINDOWS_LOCAL_GIT_STORAGE/$WINDOWS_GIT_INTERNAL_PATH' $WINDOWS_FIND_ARGUMENTS > '$FILES_LIST'"
  ERROR_MESSAGE="Cannot create file list for windows"
  execute "$COMMAND" "$ERROR_MESSAGE" '15'
fi

if [[ "$OS_TYPE" == 'linux' ]]; then
  log_info "Collecting files for linux from $LINUX_SOURCES in $FILES_LIST"
  COMMAND="find '$LINUX_SOURCES' $LINUX_FIND_ARGUMENTS > '$FILES_LIST'"
  ERROR_MESSAGE="Cannot create file list for linux"
  execute "$COMMAND" "$ERROR_MESSAGE" '16'
fi

#
## Distributing files
#

log_debug "PSCP Output Directory: $TRANSFER_OUTPUT_DIRECTORY"
log_debug "PSCP Error Directory: $TRANSFER_ERROR_DIRECTORY"
log_debug "PSCP Timeout In Seconds: $TRANSFER_TIMEOUT"



if [[ -s "$FILES_LIST" && "$OS_TYPE" == 'windows' ]]; then
  recreate_file "$HOST_OUTPUT_CACHE"
  WIN_HOSTLIST="$(get_hostlist_fp "$WIN_API_IDENTIFIER")"

  # Prepare Mail
  log_info "Preparing values for mail content(1/2)"
  TOTAL_HOST_NUMBER="$(cat "$WIN_HOSTLIST" | wc -l)"
  STATUS_TIMEOUT="0"
  STATUS_LOST_CONNECTION="0"
  STATUS_NOT_CATCHED="0"

  # Prepare Attachment
  log_info "Preparing file for mail attachment"
  recreate_file "$ATTACHMENT_FP"
  echo "Host,Result,Exit Code,Output,Error" >> "$ATTACHMENT_FP"

  # Execute command
  filestocopy_win="$(cat "$FILES_LIST" | xargs)"
  for file in ${filestocopy_win}; do
    log_info "Copying $file to all hosts in $WIN_HOSTLIST"
    WIN_PSCP_ARGUMENTS="-h '$WIN_HOSTLIST' '$file'"
    if [[ "${file}" = */checkscripts/* ]]; then
      if [[ "${file}" = */bin/* ]]; then
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/perfdata/bin/\"'"
      elif [[ "${file}" = */etc/* ]]; then
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/perfdata/etc/\"'"
      elif [[ "${file}" = */libexec/perf/* ]]; then
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/perfdata/libexec/perf/\"'"
      elif [[ "${file}" = */libexec/* ]]; then
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/perfdata/libexec/\"'"
      elif [[ "${file}" = */var/* ]]; then
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/perfdata/var/\"'"
      else
        COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/scripts/\"'"
      fi
    elif [[ "${file}" = */bginfo/* ]]; then
      COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/tools/bginfo/\"'"
    elif [[ "${file}" = */patching/* ]]; then
      COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/_patching_do_not_delete/automation/\"'"
    elif [[ "${file}" = */security/* ]]; then
      COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/security/\"'"
    elif [[ "${file}" = */Healing/* ]]; then
      COMMAND="scp -q $file /sapmnt/dlm_export/services/servermgmnt/windows/git_repo/Nagios/Healing/"
    elif [[ "${file}" = */root/* ]]; then
      COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/users/root/.ssh/\"'"
    else
      COMMAND="pscp $PSCP_ARGUMENTS $WIN_PSCP_ARGUMENTS '\"/C:/Program Files/NSClient/\"'"
    fi
    ERROR_MESSAGE="Uploading file $file failed."
    execute "$COMMAND" "$ERROR_MESSAGE"

    log_info "Removing failed servers and adding to attachment"
    echo "$OUTPUT" | grep 'FAILURE' | awk -F '] ' '{print $3}' >> "$HOST_OUTPUT_CACHE"
    for host in $(echo "$OUTPUT" | grep 'FAILURE' | cut -d' ' -f4); do
      sed -i "/$host/d" "$WIN_HOSTLIST"

      # Prepare Attachment
      LINE="$(echo "$OUTPUT" | grep "$host")"
      host_result='FAILURE'

      if echo "$LINE" | grep -q 'Timed out'; then
        STATUS_TIMEOUT=$(expr "$STATUS_TIMEOUT" + '1')
        host_exit_code="1"
        host_output=''
        host_error="$(echo "$LINE" | cut -d' ' -f5- | tr '\n' ' ' | tr ',' ';')"
      else
        if grep -q 'lost connection' "$TRANSFER_ERROR_DIRECTORY/$host"; then
          STATUS_LOST_CONNECTION=$(expr "$STATUS_LOST_CONNECTION" + '1')
        else
          STATUS_NOT_CATCHED=$(expr "$STATUS_NOT_CATCHED" + '1')
        fi
        if echo "$LINE" | grep -q 'Exited with error code'; then
          host_exit_code="$(echo "$LINE" | cut -d' ' -f9)"
        else
          host_exit_code='255'
        fi
        host_output="$(cat "$TRANSFER_OUTPUT_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
        host_error="$(cat "$TRANSFER_ERROR_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
      fi
      echo "$host,$host_result,$host_exit_code,$host_output,$host_error" >> "$ATTACHMENT_FP"
    done
  done

  # Prepare Attachment
  for host in $(cat "$WIN_HOSTLIST"); do
    if [[ "$host" == "" ]]; then continue; fi
    host_result='SUCCESS'
    host_exit_code='0'
    host_output="$(cat "$TRANSFER_OUTPUT_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
    host_error="$(cat "$TRANSFER_ERROR_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
    echo "$host,$host_result,$host_exit_code,$host_output,$host_error" >> "$ATTACHMENT_FP"
  done

  log_info "Preparing values for mail content (2/2)"
  STATUS_SUCCESS_RSYNC="$(cat "$WIN_HOSTLIST" | wc -l)"

  # Send Mail
  log_info "Sending mail"
  COMMAND="/home/adminhosts/mail/dlm_mail.pl \
    --template /home/adminhosts/mail/dlm_template.html \
    --subject '$SUBJECT' \
    --var 'headline=$HEADLINE' \
    --var '<b>Total number of hosts</b>'='$TOTAL_HOST_NUMBER' \
    --var '<b>Successful copies</b>'='$STATUS_SUCCESS_RSYNC' \
    --var '<b>Lost connection</b>'='$STATUS_LOST_CONNECTION' \
    --var '<b>Timed out</b>'='$STATUS_TIMEOUT' \
    --var '<b>Other Errors</b>'='$STATUS_NOT_CATCHED' \
    --from 'Nagios_File_Sync_Tools' \
    --to=$USER_MAIL \
    --attachment '$ATTACHMENT_FP'"
  ERROR_MESSAGE="Cannot send mail to dlm team"
  execute "$COMMAND" "$ERROR_MESSAGE"

fi

if [[ "$OS_TYPE" == 'windows' && ! -s "$FILES_LIST" ]]; then
  log_info "No files to update. Pushing no changes"
fi

if [[ -s "$FILES_LIST" && "$OS_TYPE" == 'linux' ]]; then
    # Execute Command (prsync)
    COMBINED_HOSTLIST="$(get_hostlist_fp "$COMBINED_IDENTIFIER")"
    log_info "Copying files from $FILES_LIST to all hosts in $COMBINED_HOSTLIST"
    log_debug "Destination Host Directory: $LINUX_DESTINATION_FQFP"
    COMMAND="prsync $PRSYNC_ARGUMENTS -h '$COMBINED_HOSTLIST' $(cat $FILES_LIST | xargs) '$LINUX_DESTINATION_FQFP'"
    ERROR_MESSAGE="Cannot copy files from $FILES_LIST to all hosts in $COMBINED_HOSTLIST"
    execute "$COMMAND" "$ERROR_MESSAGE"
    TRANSFER_OUTPUT="$OUTPUT"

    # Execute 2nd Command (pscp)
    log_info "Copying checkscripts with pscp for all hosts that failed"
    TEMP_HOST_FILE="$BASE_DIR/linux_file_sync_cache"
    recreate_file "$TEMP_HOST_FILE"
    COMMAND="echo \"$TRANSFER_OUTPUT\" | grep 'FAILURE' | cut -d' ' -f4 > '$TEMP_HOST_FILE'"
    ERROR_MESSAGE="Cannot write list of hosts that failed to $TEMP_HOST_FILE"
    execute "$COMMAND" "$ERROR_MESSAGE"
    COMMAND="pscp $PSCP_ARGUMENTS -h '$TEMP_HOST_FILE' -r '$LINUX_CHECKSCRIPT_SOURCES' '$LINUX_DESTINATION_FQFP'"
    ERROR_MESSAGE="Cannot copy checkscripts from $LINUX_CHECKSCRIPT_SOURCES to all hosts in $TEMP_HOST_FILE"
    execute "$COMMAND" "$ERROR_MESSAGE"
    TRANSFER_CHECKSCRIPTS_OUTPUT="$OUTPUT"

    # Copy motd.sh to Redhat servers
    log_info "Copying motd.sh to redhat, ubuntu, debian servers"
    REDHAT_SERVERS_LIST="$(get_hostlist_fp "$RH_API_IDENTIFIER")"
    DEBIAN_SERVER_LIST="/tmp/Debianserverslist"
    UBUNTU_SERVER_LIST="/tmp/Ubuntuserverslist"
    COMBINED_MOTD_LIST="/tmp/MOTDCombinedLIST"
    FETCH_UBUNTU=`curl --noproxy api.infra-mon.c.eu-de-1.cloud.sap -ks -u 'dlm:pw4remL#' 'https://api.infra-mon.c.eu-de-1.cloud.sap/rest/v1?lob=DLM&command=get_hosts&host_group=ubuntu' | cut -d ';' -f1 | sed -n '1!p' > $UBUNTU_SERVER_LIST`
    FETCH_DEBIAN=`curl --noproxy api.infra-mon.c.eu-de-1.cloud.sap -ks -u 'dlm:pw4remL#' 'https://api.infra-mon.c.eu-de-1.cloud.sap/rest/v1?lob=DLM&command=get_hosts&host_group=debian'  | cut -d ';' -f1 | sed -n '1!p' > $DEBIAN_SERVER_LIST`
    COMBINE_HOSTS=`cat $REDHAT_SERVERS_LIST > $COMBINED_MOTD_LIST`
    COMBINE_HOSTS=`cat $DEBIAN_SERVER_LIST >> $COMBINED_MOTD_LIST`
    COMBINE_HOSTS=`cat $UBUNTU_SERVER_LIST >> $COMBINED_MOTD_LIST`
    SOURCE_FILE="/home/adminhosts/devadm/rpmbuild/chroot/etc/profile.d/motd.sh"
    DESTINATION_DIR="/etc/profile.d/"
    log_info "Copying file $SOURCE_FILE to hosts $REDHAT_SERVERS_LIST"
    log_debug "Destination Directory is /etc/profile.d"
    PRSYNC_ADDN_ARGUMENTS="-avzz -X --inplace -r -o '/tmp/nagios_sync/stdout/motd_linux' -e '/tmp/nagios_sync/stderr/motd_linux' -t '150'"
    #COMMAND_MOTD="prsync $PRSYNC_ADDN_ARGUMENTS -h $REDHAT_SERVERS_LIST $SOURCE_FILE $DESTINATION_DIR"
    COMMAND_MOTD="prsync $PRSYNC_ADDN_ARGUMENTS -h $COMBINED_MOTD_LIST $SOURCE_FILE $DESTINATION_DIR"
    ERROR_MESSAGE_MOTD="Cannot copy file $SOURCE_FILE to all hosts in  $COMBINED_MOTD_LIST"
    execute "$COMMAND_MOTD" "$ERROR_MESSAGE_MOTD"
    TRANSFER_MOTD_OUTPUT="$OUTPUT"


    # Prepare Mail (1/2)
    log_info "Preparing values for mail content"
    TOTAL_HOST_NUMBER="$(cat "$COMBINED_HOSTLIST" | wc -l)"
    STATUS_SUCCESS_RSYNC="$(echo "$TRANSFER_OUTPUT" | grep 'SUCCESS' | wc -l)"
    STATUS_SUCCESS_SCP="$(echo "$TRANSFER_CHECKSCRIPTS_OUTPUT" | grep 'SUCCESS' | wc -l)"
    STATUS_TIMED_OUT="$(echo "$TRANSFER_CHECKSCRIPTS_OUTPUT" | grep 'Timed out' | wc -l)"
    STATUS_SUCCESS_MOTD="$(echo "$TRANSFER_MOTD_OUTPUT" | grep 'SUCCESS' | wc -l)"
    STATUS_ERROR_MOTD="$(echo "$TRANSFER_MOTD_OUTPUT" | grep -v 'SUCCESS' | wc -l)"

    HOST_GROUPS=""
    if [[ "$OLD_SLES_SOURCE_HOSTLIST" != "" && -s "$OLD_SLES_SOURCE_HOSTLIST" ]]; then HOST_GROUPS+='SLES<=10, '; fi
    if [[ "$SUSE_API_IDENTIFIER" != '' ]]; then HOST_GROUPS+='SuSE, '; fi
    if [[ "$RH_API_IDENTIFIER" != '' ]]; then HOST_GROUPS+='RedHat, '; fi
    if [[ "$DEB_API_IDENTIFIER" != '' ]]; then HOST_GROUPS+='Debian, '; fi
    if [[ "$UNIX_API_IDENTIFIER" != '' ]]; then HOST_GROUPS+='Unix, '; fi

    get_host_group() {
      host="$1"
      if [[ "$OLD_SLES_IDENTIFIER" != "" ]] && grep -q "$host" "$(get_hostlist_fp "$OLD_SLES_IDENTIFIER")"; then host_group="$OLD_SLES_IDENTIFIER"; fi
      if [[ "$SUSE_API_IDENTIFIER" != "" ]] && grep -q "$host" "$(get_hostlist_fp "$SUSE_API_IDENTIFIER")"; then host_group="$SUSE_API_IDENTIFIER"; fi
      if [[ "$RH_API_IDENTIFIER" != "" ]] && grep -q "$host" "$(get_hostlist_fp "$RH_API_IDENTIFIER")"; then host_group="$RH_API_IDENTIFIER"; fi
      if [[ "$DEB_API_IDENTIFIER" != "" ]] && grep -q "$host" "$(get_hostlist_fp "$DEB_API_IDENTIFIER")"; then host_group="$DEB_API_IDENTIFIER"; fi
      if [[ "$UNIX_API_IDENTIFIER" != "" ]] && grep -q "$host" "$(get_hostlist_fp "$UNIX_API_IDENTIFIER")"; then host_group="$UNIX_API_IDENTIFIER"; fi
    }

    # Prepare Attachments
    log_info "Preparing files for mail attachments"
    recreate_file "$ATTACHMENT_FP"
    recreate_file "$ATTACHMENT_CHECKSCRIPTS_FP"
    echo "Host,Host Group,Result,Exit Code,Output,Error" >> "$ATTACHMENT_FP"
    for host in $(cat "$COMBINED_HOSTLIST"); do
      host_result="$(echo "$TRANSFER_OUTPUT" | grep "$host" | cut -d[ -f3 | cut -d] -f1)"
      get_host_group "$host"
      host_exit_code="$(echo "$TRANSFER_OUTPUT" | grep "$host" | awk -F 'error code ' '{print $2}')"
      if [[ "$host_exit_code" == "" ]]; then host_exit_code="0"; fi
      host_output="$(cat "$TRANSFER_OUTPUT_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
      host_error="$(cat "$TRANSFER_ERROR_DIRECTORY/$host" | tr '\n' ' ' | tr ',' ';')"
      echo "$host,$host_group,$host_result,$host_exit_code,$host_output,$host_error" >> "$ATTACHMENT_FP"
    done
    echo "Host,Host Group,Result,Exit Code,Output,Error" >> "$ATTACHMENT_CHECKSCRIPTS_FP"
    for host in $(cat "$TEMP_HOST_FILE"); do
      host_result="$(echo "$TRANSFER_CHECKSCRIPTS_OUTPUT" | grep "$host" | cut -d'[' -f3 | cut -d']' -f1)"
      get_host_group "$host"
      host_exit_code="$(echo "$TRANSFER_CHECKSCRIPTS_OUTPUT" | grep "$host" | awk -F 'error code ' '{print $2}')"
      if [[ "$host_exit_code" == "" ]]; then
        if echo "$TRANSFER_OUTPUT" | grep "$host" | grep -q 'Timed out'; then
          host_exit_code="255";
        else
          host_exit_code="0";
        fi
      fi
      host_output="$(cat "$TRANSFER_OUTPUT_DIRECTORY$CHECKSCRIPTS_SUFFIX/$host" | tr '\n' ' ' | tr ',' ';')"
      host_error="$(cat "$TRANSFER_ERROR_DIRECTORY$CHECKSCRIPTS_SUFFIX/$host" | tr '\n' ' ' | tr ',' ';')"
      echo "$host,$host_group,$host_result,$host_exit_code,$host_output,$host_error" >> "$ATTACHMENT_CHECKSCRIPTS_FP"
    done

    echo "Copying MOTD to Redhat,Ubuntu,Debian" >>  "$ATTACHMENT_FP"
    echo "Host,Result,Exit Code,Output,Error" >>  "$ATTACHMENT_FP"
    for host in $(cat "$COMBINED_MOTD_LIST"); do
      host_motd_result="$(echo "$TRANSFER_MOTD_OUTPUT" | grep "$host" | cut -d[ -f3 | cut -d] -f1)"
      host_motd_exit="$(echo "$TRANSFER_MOTD_OUTPUT" | grep "$host" | awk -F 'error code ' '{print $2}')"
      if [[ "$host_motd_exit" == "" ]]; then host_motd_exit="0"; fi
      host_motd_op="$(cat "/tmp/nagios_sync/stdout/motd_linux/$host" | tr '\n' ' ' | tr ',' ';')"
      if [ -f "/tmp/nagios_sync/stderr/motd_linux/$host" ]; then
         host_motd_er="$(cat "/tmp/nagios_sync/stderr/motd_linux/$host" | tr '\n' ' ' | tr ',' ';')"
      fi
      echo "$host,$host_motd_result,$host_motd_exit,$host_output_op,$host_motd_er" >> "$ATTACHMENT_FP"
    done

    # Prepare Mail (2/2)
    STATUS_NO_SPACE_LEFT="$(cat "$ATTACHMENT_CHECKSCRIPTS_FP" | grep 'No space left' | wc -l)"
    STATUS_LOST_CONNECTION="$(cat "$ATTACHMENT_CHECKSCRIPTS_FP" | grep 'lost connection' | wc -l)"
    STATUS_NOT_CATCHED="$(cat "$ATTACHMENT_CHECKSCRIPTS_FP" | grep -v -E 'SUCCESS|No space|lost connection|Host,Host Group' | wc -l)"

    # Send Mail
    log_info "Sending mail"
    COMMAND="/home/adminhosts/mail/dlm_mail.pl \
      --template /home/adminhosts/mail/dlm_template.html \
      --subject '$SUBJECT' \
      --var 'headline=$HEADLINE' \
      --var '<b>Total number of hosts</b>'='$TOTAL_HOST_NUMBER' \
      --var '<b>All files synced</b>'='$STATUS_SUCCESS_RSYNC' \
      --var '<b>Only checkscripts synced</b>'='$STATUS_SUCCESS_SCP' \
      --var '<b>Timed out</b>'='$STATUS_TIMED_OUT' \
      --var '<b>Lost connection</b>'='$STATUS_LOST_CONNECTION' \
      --var '<b>No space left</b>'='$STATUS_NO_SPACE_LEFT' \
      --var '<b>Other Errors</b>'='$STATUS_NOT_CATCHED' \
      --var '<b>Host Groups</b>'='${HOST_GROUPS::-2}' \
      --var '<b>MOTD_Servers-Sucesss:Error</b>=$STATUS_SUCCESS_MOTD:$STATUS_ERROR_MOTD' \
      --from 'Nagios_File_Sync_Tools' \
      --to=$USER_MAIL \
      --attachment '$ATTACHMENT_FP' \
      --attachment '$ATTACHMENT_CHECKSCRIPTS_FP'"
    ERROR_MESSAGE="Cannot send mail to dlm team"
    execute "$COMMAND" "$ERROR_MESSAGE"
fi

log_info "Successfully finished!"
