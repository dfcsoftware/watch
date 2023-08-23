#!/bin/bash
##########################################################
#
# File: watch.sh
#
# Usage: watch.sh [host]
#  Default is all hosts in hosts.txt
#
# Purpose: Monitor remote systems, sending notifications
#
# Dependencies: 
#   - Various alert scripts (i.e.: df.sh,...)
#   - $ mkdir -p ~/.config/alert
#   - File:      ~/.config/alert/config.txt
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
#   - ssh-copy-id <remote hosts>
#
# Remote Hosts:
#   - For each host and each alert script,
#     Create <alert function>.<hostname>
#      on the remote host
#      in directory ~/.config/alert/
#   EX:
#    $ scp ~/.config/alert/df.vm1 bob@vm1:/home/bob/.config/alert/
#
# Reference:
#  https://pcp.readthedocs.io/en/latest/QG/AutomateProblemDetection.html
#
# History:
#   When          Who          Why
# -----------  ------------ -----------------------------
# 11-Aug-2023  Don Cohoon   Created
#--------------------------------------------------------
CONFIG_DIR=~/.config/watch
#
HOSTNAME=$(/bin/hostname -s)
DIR=$(/usr/bin/dirname ${0})
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
     /usr/bin/ssh -p ${PORT} ${SSH_USER}@${HN} ./${FN}.sh 1 > ${TMP} 2>&1
   elif [ $HOSTNAME != $HN ]; then
     /usr/bin/ssh -p ${PORT} ${SSH_USER}@${HN} "bash -s" -- < ${DIR}/${FN}.sh 1 > ${TMP} 2>&1
   else
     ${DIR}/${FN}.sh 1 > ${TMP} 2>&1
   fi
   if [ -s ${TMP} ]; then
     /bin/cat ${TMP} 
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
if [ $# -gt 0 ]; then
  HOST=${1}
else 
  HOST="ALL"
fi
/bin/grep -v '^#' < ${CONFIG_DIR}/hosts.txt |
{ while read H PORT REMOTE_SCRIPT REMOTE_HOME
 do
   if [ ${HOST} = "ALL" ] || [ ${H} = ${HOST} ]; then
     /bin/echo "========> ${H} <========"
     #..........................................
     /bin/echo "---> df - Disk Full <---"
     monit df ${H} ${PORT} ${REMOTE_SCRIPT}
     #..........................................
     /bin/echo "---> util - System Utilization <---"
     monit util ${H} ${PORT} ${REMOTE_SCRIPT}
     #..........................................
   fi
done }
#..........................................
#
# Cleanup
#
/bin/rm -f ${TMP}
