#!/bin/bash
#######################################
#
# File: deploy.sh
#
# Usage: deploy.sh [first-time <host>] [help]
#
# Settings:
#  FILE: ~/.config/watch/hosts.txt
#```
# # Host   ssh    Remote   Remote
# #        Port   Script   Home
# # ------ ------ -------- -----------------------
# vm1      2222   0        /home/bob
# vm2      22     1        /home/data/bob
# # Remote Script: 1=run moniter script that is on remote machine 
# #                0=run monitor script on local, through ssh tunnel
#```
#
# Purpose: Activate watch on remote host(s)
#
# Files pushed out (with tarballs extracted):
# ├── alert     <- Directory for alerts
# ├── alert.sh  <- Schedule this to run df.sh and util.sh
# ├── db        <- Berkerly Database, used by nbs
# │   ├── oracle_berkely_DB-V997917-01.zip
# │   └── readme
# ├── deploy.sh <- This script
# ├── df.sh     <- Disk Full alerts
# ├── geturl.pl <- Extract URL and IP Address from Apache/nginx logs
# ├── log.sh    <- Schedule this to watch log files
# ├── mail.sh   <- Send e-mail unless SEND_MAIL is set to 0 in config.txt
# ├── nbs       <- Never Before Seen (NBS) database application
# │   ├── db.c
# │   ├── gtemp.c
# │   ├── INSTALL
# │   ├── LICENSE.pdf
# │   ├── Makefile
# │   ├── nbs.c
# │   ├── nbsdump.c
# │   ├── nbs.h
# │   ├── nbs.man
# │   ├── nbs-man.pdf
# │   ├── nbsmk.c
# │   ├── nbspreen.c
# │   ├── nbs-viewgraphs.pdf
# │   └── scripts
# │       ├── getdhcp.pl
# │       ├── geturl.pl
# │       └── README
# ├── nbs.tar   <- Tarball of NBS used for deployment
# ├── retail    <- Retail log watcher
# │   ├── Makefile
# │   ├── retail.c
# │   ├── retail.c.save
# │   ├── retail.man
# │   ├── retail-master
# │   │   ├── Makefile
# │   │   ├── README
# │   │   ├── retail.1
# │   │   ├── retail.c
# │   │   └── test_retail.sh
# │   └── retail-master.zip
# ├── retail.tar <- Tarball of Retail used for deployment
# ├── savelog.sh <- Rotate and remove watch log files
# ├── status     <- Status directory for log.sh
# ├── sync.sh    <- Sync alert directory to nextcloud
# ├── util.sh    <- System Utilization alerts
# └── watch.sh   <- Interactive alert tester/watcher
# 
# 8 directories, 40 files
# 
#
# History:
# When        Who        Description
# ----------- ---------- --------------------
# 17-Aug-2023 Don Cohoon Created
#######################################
CONFIG_DIR=~/.config/watch
LOCAL_HOME=/home/bob
MY_HOST=$(hostname -s)
FIRSTTIME=0
#######################################
function usage(){
 echo "Usage:${0} [<host>] [first-time <host>] [help]"
 echo " Empty parameters will process all hosts."
}
#
#######################################
function help() {
  echo " This script will push out watch files to remote hosts."
  echo " Start with: ${0} first-time <host>"
  echo " Then follow the settings in files alert.sh. df.sh, util.sh, and sync.sh."
  echo " File alert.sh can be scheduled to monitor remote hosts, as a ssh capable user;"
  echo "  while file log.sh needs to be scheduled locally on each host, as root."
  echo " log.sh requires compiling the Berkely DB, nbs, and retail packages on each host"
  echo " See file log.sh for instructions."
}
#######################################
#
function push() {
  HOST=${1}
  PORT=${2}
  REMOTE_SCRIPT=${3}
  REMOTE_HOME=${4}
  #
  echo "${0}: Processing Host: ${HOST}, Remote Script: ${REMOTE_SCRIPT}, Remote Home: ${REMOTE_HOME}"
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/status
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/filters
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/alert
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/log
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/db
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/nbs
  ssh -p ${PORT} ${HOST} mkdir -p ${REMOTE_HOME}/watch/retail
  #
  if [ ${FIRSTTIME} -eq 1 ]; then
    scp -pP ${PORT}  ${LOCAL_HOME}/watch/db/oracle_berkely_DB-V997917-01.zip ${HOST}:${REMOTE_HOME}/watch/db
    scp -pP ${PORT}  ${LOCAL_HOME}/watch/db/readme   ${HOST}:${REMOTE_HOME}/watch/db
    scp -pP ${PORT}  ${LOCAL_HOME}/watch/nbs.tar     ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}  ${LOCAL_HOME}/watch/retail.tar  ${HOST}:${REMOTE_HOME}/watch/
  fi
  if [ ${REMOTE_SCRIPT} -eq 0 ]; then
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/*.sh       ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/filters/*  ${HOST}:${REMOTE_HOME}/watch/filters/
  else # Only copy log.sh and sync, do not overlay local df.sh and util.sh, etc...
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/mail.sh    ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/savelog.sh ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/log.sh     ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/sync.sh    ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/geturl.pl  ${HOST}:${REMOTE_HOME}/watch/
    scp -pP ${PORT}      ${LOCAL_HOME}/watch/filters/*  ${HOST}:${REMOTE_HOME}/watch/filters/
  fi
  echo "${0}: Check directory ${REMOTE_HOME}/watch on Host: ${HOST}"
  return 0
}
#######################################
#
# Parameters
#
if [ $# -gt 0 ]; then
  case ${1}
    in
      help)
          help 
          usage
          exit 2
        ;;
      first-time)
          FIRSTTIME=1
          DEPLOY_HOST=${2}
          echo "Looking for host: ${DEPLOY_HOST}"
        ;;
      *)
          DEPLOY_HOST=${1}
          echo "Looking for host: ${DEPLOY_HOST}"
        ;;
  esac
fi
#######################################
#
# For each host in host.txt file
#
TMP=$(mktemp)
grep -v '^#' < ${CONFIG_DIR}/hosts.txt >${TMP}
{ while read -u 3 H PORT REMOTE_SCRIPT REMOTE_HOME
do
  if [ ${MY_HOST} = ${H} ]; then
    continue
  fi
  if [ ${FIRSTTIME} -eq 1 ]; then
    if  [ "${DEPLOY_HOST}" = "${H}" ]; then
      push ${H} ${PORT} ${REMOTE_SCRIPT} ${REMOTE_HOME}
    fi
  elif [ -n "${DEPLOY_HOST}" ]; then
    if [ "${DEPLOY_HOST}"  = "${H}" ]; then
      push ${H} ${PORT} ${REMOTE_SCRIPT} ${REMOTE_HOME}
    fi
  else # all
    push ${H} ${PORT} ${REMOTE_SCRIPT} ${REMOTE_HOME}
  fi
done } 3< ${TMP} # ssh tunnel grabs stdin & stdout
#
rm -f ${TMP}

