#!/bin/bash
#######################################################################
#
# File: mail.sh
#
# Usage: mail.sh <File Name to Mail> <Subject>
#
# Who       When        Why
# --------- ----------- -----------------------------------------------
# D. Cohoon Feb-2023    IF host name cannot be changed, set headers
# D. Cohoon Aug-2023    Support multiple OS
#######################################################################
function usage () {
   /usr/bin/echo "Usage: ${0} <File Name to Mail> <Subject>"
   exit 1
}
#------------------
if [ $# -lt 2 ]; then
  usage
fi
#
if [ ! -z ${1} ] && [ ! -f ${1} ]; then
  usage 
fi
#
#------------------
HOSTNAME=$(hostname -s)
DOMAINNAME=$(hostname -d)
OS=$(/usr/bin/hostnamectl|/bin/grep 'Operating System'|/usr/bin/cut -d: -f2|/usr/bin/awk '{print $1}')
FILE=${1}    # First arg
shift 1
SUBJECT="${HOSTNAME}.${DOMAINNAME}:${@}" # Remainder of args
#
#------------------
export REPLYTO=root@${HOSTNAME}.bob.com
FROM=root@${HOSTNAME}.bob.com
#FROM="${HOSTNAME}@${DOMAINNAME}"
MAILTO=bob@bob.com
#
#------------------
case ${OS} in
  AlmaLinux|CentOS) 
    # RedHat s-nail
    /usr/bin/cat ${FILE} | /usr/bin/mail --from-address=${FROM} -s "${SUBJECT}" ${MAILTO}
    ;;
  Ubuntu|Debian) 
    # Debian mailutils
    /bin/cat ${FILE} | /usr/bin/mail -a"FROM:${FROM}"  -s "${SUBJECT}" ${MAILTO}
    ;;
esac
