#!/bin/bash
##########################################################
#
# File: alert.sh
#
# Usage: alert.sh
#
# Purpose: Monitor remote systems, sending notifications
#
# Dependencies: 
#   - Various alert scripts (i.e.: df.sh,...)
#   - sync.sh
#   - $ mkdir -p ~/.config/watch
#   - File:      ~/.config/watch/config.txt
#      export LOCAL_DIR=/home/bob/watch
#      export SSH_USER=bob
#   - $ mkdir ${LOCAL_DIR}/alert
#   - FILE: ~/.config/watch/hosts.txt
#   # Host   ssh    Remote   Remote
#   #        Port   Script   Home
#   # ------ ------ -------- -----------------------
#     vm1    2222   0        /home/don
#     vm2    22     1        /home/data/don
#   # Remote Script: 1=run moniter script that is on remote machine 
#   #                0=run monitor script on local, through ssh tunnel
#   - Schedule this in cron (i.e.: every 15 minutes)
#   - ssh-copy-id <remote hosts>
#   - See sync.sh for further info
#
# Remote Hosts:
#   - For each host and each alert script,
#     Create <alert function>.<hostname>
#      on the remote host
#      in directory ~/.config/watch/
#   EX:
#    $ scp ~/.config/watch/df.vm1 bob@vm1:/home/bob/.config/watch/
#
# Reference:
#  https://pcp.readthedocs.io/en/latest/QG/AutomateProblemDetection.html
#
# History:
#   When          Who          Why
# -----------  ------------ -----------------------------
#  3-Aug-2023  Don Cohoon   Created
#--------------------------------------------------------
CONFIG_DIR=~/.config/watch
#
DIR=$(/usr/bin/dirname ${0})
HOSTNAME=$(/bin/hostname -s)
TMP=$(/bin/mktemp)
MY_DATE=$(/bin/date)
YES=1
NO=0
#..........................................
# 
# Run the Monitor
#
function monit() {
   FN=${1}   # function
   HN=${2}   # hostname
   PORT=${3} # port
   REMOTE_SCRIPT=${4} # remote script
   DATE=$(/bin/date +%Y%m%d%H%M%S)
   if [ ${REMOTE_SCRIPT} = ${YES} ]; then
     /usr/bin/ssh -p ${PORT} ${SSH_USER}@${HN} ./${FN}.sh 3 > ${TMP} 2>&1
   elif [ $HOSTNAME != $HN ]; then
     /usr/bin/ssh -p ${PORT} ${SSH_USER}@${HN} "bash -s" -- < ${LOCAL_DIR}/${FN}.sh 3 > ${TMP} 2>&1
   else
     ${LOCAL_DIR}/${FN}.sh 3 > ${TMP} 2>&1
   fi
   if [ -s ${TMP} ]; then
     /bin/cat ${TMP} > ${LOCAL_DIR}/alert/${HN}.${FN}.${DATE}.txt
   fi
}
#..........................................
#
# Check Config
#
if [ ! -f ${CONFIG_DIR}/hosts.txt ]; then
  /bin/echo "${MY_DATE}:ERROR: Missing (config file) ${CONFIG_DIR}/hosts.txt"
  exit 2
fi
if [ ! -f ${CONFIG_DIR}/config.txt ]; then
  /bin/echo "${MY_DATE}:ERROR: Missing (config file) ${CONFIG_DIR}/config.txt"
  exit 2
else
  . ${CONFIG_DIR}/config.txt
fi
if [ ! -d ${LOCAL_DIR}/alert ]; then
	/bin/echo "${MY_DATE}:ERROR: Missing (LOCAL_DIR) ${LOCAL_DIR}/alert"
  exit 2
fi
#..........................................
#
# Monitor Remote Systems
#
# File: ~/.config/watch/hosts.txt
#  Host | ssh Port | Boolean to run script on 1=remote; 0=local
#```
# host1   28         0
#```
grep -v '^#' < ${CONFIG_DIR}/hosts.txt |
{ while read H PORT REMOTE_SCRIPT REMOTE_HOME
 do
   #..........................................
   # df - Disk Full
   monit df ${H} ${PORT} ${REMOTE_SCRIPT}
   #..........................................
   # util - System Utilization
   monit util ${H} ${PORT} ${REMOTE_SCRIPT}
   #..........................................
done }
#..........................................
#
# Sync to Local Cloud, causing alert
#
${DIR}/sync.sh
#..........................................
#
# Cleanup
#
/bin/rm -f ${TMP}
