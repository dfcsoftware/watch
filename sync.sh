#!/bin/bash
####################################################
#
# File: sync.sh
#
# Dependencies:
#   - sudo dnf install curl
#   - sudo apt install curl
#   - $ mkdir -p ~/.config/watch
#   - File:      ~/.config/watch/config.txt
#      export LOCAL_DIR=/home/bob/watch
#      export CLOUD_USER=<nextcloud user>
#      export CLOUD_PASS="<nextcloud password>
#      export CLOUD_LOG=/home/bob/cloud.log
#      export CLOUD_DIR=alert
#      export CLOUD_SERVER="https://www.example.com/nextcloud"
#   - $ mkdir ${LOCAL_DIR}/alert
#   - Make sure CLOUD_LOG is writeable
#   - Flow Notifications
#      - Create _new alert user_ in NextCloud
#        - Add the server as CLOUD_SERVER in config.txt
#        - Add the user as CLOUD_USER
#        - Add the user's password as CLOUD_PASS
#      - As the _new alert user_ in NextCloud;
#        - Go to Talk
#          - Create a new group Conversation <name>
#        - Go to Files and create a new alert directory
#          - Add it as the CLOUD_DIR to config.txt
#        - Go to Personal Settings > Flow
#          - Add a new flow _Write to conversasion_ (blue)
#          - When: File created
#             and: File size (upload) is greater than 0 MB
#          -> Write to conversasion using the
#              Conversation <name> created above
#    
#      https://github.com/nextcloud/flow_notifications
#   - savelog.sh (local)
# 
# Description: When any new file is uploaded into the
#   _new alert user_ space, an entry will be written
#   to the Conversation <name> with the name and link
#   to that file.
#  On your Phone you can install NextCloud Talk, log in 
#   as the new alert user and recieve notifications.
#   Bonus: Your watch will alert you too!
#  On your Phone you can install NextCloud Sync, log in 
#   as the new alert user and read notification files.
#
# History
#  When       Who        Description
# ----------- ---------- --------------------------------
#  3-Aug-2030 Don Cohoon Created
####################################################
#
#
source ~/.config/watch/config.txt
#
#
CNT=0
FILES=""
FILES_ARRAY=()
LOG=${CLOUD_LOG}
DIR=$(/usr/bin/dirname ${0})
#
date >${LOG}
####################################
#
# Rotate Log
#
function rotate_log() {
  ${DIR}/savelog.sh -q -c 10 ${LOG} >>/dev/null 2>&1
}
####################################
#
# Cleanup Alerts 
#
# touch -mt 08190101  alert/vm2.email-error.20230820181816.uploaded
#
function cleanup_alerts() {
  find ${LOCAL_DIR}/alert/*.uploaded -mtime +7 -exec rm -f {} \; 1>>/dev/null 2>&1
}
####################################
#
# Cleanup
#
function cleanup() {
 #
 rotate_log
 #
 cleanup_alerts
}
####################################
#
# Check for no files
#
ls ${LOCAL_DIR}/alert/*.txt >/dev/null 2>&1
RSLT=$?
if [ $RSLT -ne 0 ]; then
  echo "No files found" >>${LOG}
  cleanup
  exit 2
fi
#
####################################
#
# Create File List  "{file1,file2}"
#
for F in ${LOCAL_DIR}/alert/*.txt
do
  echo "("${CNT}")" ${F} >>${LOG}
  if (( $CNT > 0 )); then
    FILES+=","${F}
  else
    FILES+="{"${F}
  fi
  FILES_ARRAY+=(${F})
  (( CNT++ ))
done
FILES+="}"
#
####################################
#
# Upload Files
#
echo "Uploading files: ${FILES}" >>${LOG}
#
curl --upload-file ${FILES} -u ${CLOUD_USER}:${CLOUD_PASS} ${CLOUD_SERVER}/remote.php/dav/files/${CLOUD_USER}/${CLOUD_DIR}/ >>${LOG} 2>&1
#
####################################
#
# Move files from *.txt to *.uploaded
#
CNT=0
while (( $CNT < ${#FILES_ARRAY[@]} ))
do
  echo "mv ${FILES_ARRAY[$CNT]} to ${FILES_ARRAY[$CNT]%.*}.uploaded" >>${LOG}
  mv ${FILES_ARRAY[$CNT]} ${FILES_ARRAY[$CNT]%.*}.uploaded
  (( CNT++ ))
done
####################################
#
# Clean Up
#
cleanup
#
exit 0
