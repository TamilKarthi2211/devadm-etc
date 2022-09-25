#!/bin/bash

ORIGFILE=/etc/sidinfo # Define sidinfo locations to read and write
NEWFILE=/sapmnt/dlm/services/servermgmnt/sidinfo.txt

if [[ $(/usr/bin/md5sum $ORIGFILE |  awk '{print $1}') == $(/usr/bin/md5sum $NEWFILE | awk '{print $1}') ]]; then { # Check if the current sidinfo differs to the last one
    echo "File sidinfo is already up to date"
    exit 0 # Exit if not
}
else {
    diff -e $ORIGFILE $NEWFILE > /tmp/diff # Generate ed script for differences
    IFS=$'\n'
    set -f
    for line in $(cat < "/tmp/diff"); # Iterate through lines
    do
      if [[ ! $line == "." ]] && [[ ! $line == *","* ]] && [[ $line =~ .*sap.* ]]; then # Only include real sap hosts
        if [[ ! $(echo $line | awk '{print $NF}') == pwdf* ]] && [[ ! $(echo $line | awk '{print $NF}') == vmw* ]] && [[ ! $(echo $line | awk '{print $NF}') == vwc* ]] && [[ ! $(echo $line | awk '{print $NF}') == dewdfgwd* ]] && [[ ! $(echo $line | awk '{print $NF}') == dewdfgwp* ]]; then
          echo "sudo -i -u rcuser timeout 5 pssh -v -i -H \"$(echo $line | awk '{print $NF}')\" -x '-q -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no -o PreferredAuthentications=publickey -o PubkeyAuthentication=yes' -i \"echo '$line' > /etc/motd_sidinfo\" | grep -v tput >> /tmp/sidupdater.log" | tee -a /tmp/diff2 # Write command to /tmp/diff2
        fi
      fi
    done

    touch /tmp/sidupdater.log
    rm -f /tmp/sidupdater.log
    touch /tmp/sidupdater.log
    /etc/send_sidinfo.pl # Execute perl script

    (cat /tmp/diff && echo w) | ed - $ORIGFILE # Update /etc/sidinfo
    rm /tmp/diff # Remove temporary files
    rm /tmp/diff2
    echo "Succeded updating SID info files"
}
fi
