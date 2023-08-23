#!/bin/bash
##########################################################
#
# File: util.sh
#
# Usage: util.sh [Number] [Debug]
#
#  Debug: defaults to OFF (0), while 1 is ON.
#
#  Number is one of:
#  1) pmstat - Current system wide statistics
#  2) pmrep - displays kernel.all.load; and
#             kernel.all.cpu.user kernel.all.cpu.sys kernel.all.cpu.idle kernel.all.cpu.wait.total
#  3) monitor - requires a file with the 5 minute system load threshold, see below.
#     Background process to check System Load for the last 20 minutes,
#     - Default is to send an e-mail if limits are exceeded.
#     - To stop E-Mail:
#      - File: ~/.config/monitor/config.txt
#         export SEND_MAIL=0
#
# Dependencies for Local and Remote hosts: 
#   > dnf=RedHat; apt=Debian
#   $ sudo dnf install pcp cockpit-pcp python3-pcp # default from cockpit web install
#   $ sudo apt install pcp cockpit-pcp python3-pcp # default from cockpit web install
#   - Systemd Services:
#     pmcd.service
#     pmlogger.service
#     pmie.service
#     pmproxy.service
#
#   $ sudo dnf install pcp-export-pcp2json         # pcp2json
#   $ sudo apt install pcp-export-pcp2json         # pcp2json
#   $ sudo dnf install pcp-system-tools            # pmrep
#
#   $ sudo dnf install jq                          # json parser
#   $ sudo apt install jq                          # json parser
#
#   $ sudo dnf install ncdu                        # Text-based disk usage viewer
#   $ sudo apt install ncdu                        # Text-based disk usage viewer
#   mail.sh (Don Cohoon)
#
# Needs a Configuration File
#  - $ mkdir -p ~/.config/watch
#  -> Remote Hosts need their _own_ ~/.config/watch/util.<hostname>
#    Format:
#      System Load Threshold
#    File: ~/.config/watch/util.<hostname>
#      0.10
#
# Further testing:
#  Get list of pcp metrics
#    $ pminfo | grep kernel.cpu
#    kernel.cpu.util.user
#    kernel.cpu.util.nice
#    kernel.cpu.util.sys
#    kernel.cpu.util.idle
#    kernel.cpu.util.intr
#    kernel.cpu.util.wait
#    kernel.cpu.util.steal
# ...
#  Get pcp via metrics
#   $ pmrep kernel.cpu.util.user
#  NOTE: pmrep takes simular parameters as pcp2json
#   $ pmstat -a ${ARCH} -t 2hour -A 1hour -z
#   $ pcp2json -a ${ARCH} -t 2hour -A 1hour -z
#   $ pcp2json -H -L -z -a ${ARCH} -t 1m -S @09:20:00 -T @09:22:00 kernel.all.load kernel.all.cpu | \
#       jq ".[] | debug"
#
# Sample JSON:
# {"@hosts":[{"@host":"bob.example.com","@metrics":[{"@interval":"0","@timestamp":"2023-08-04 09:20:28","kernel":{"all":{"load":{"@instances":[{"name":"1 minute","value":"0.190"},{"name":"5 minute","value":"0.080"},{"name":"15 minute","value":"0.020"}]}}}},{"@interval":"60","@timestamp":"2023-08-04 09:21:28","kernel":{"all":{"cpu":{"guest":{"@unit":"ms/s","value":"48.667"},"guest_nice":{"@unit":"ms/s","value":"0.000"},"idle":{"@unit":"ms/s","value":"3917.347"},"intr":{"@unit":"ms/s","value":"11.333"},"irq":{"hard":{"@unit":"ms/s","value":"7.000"},"soft":{"@unit":"ms/s","value":"4.333"}},"nice":{"@unit":"ms/s","value":"0.000"},"steal":{"@unit":"ms/s","value":"0.000"},"sys":{"@unit":"ms/s","value":"7.333"},"user":{"@unit":"ms/s","value":"54.167"},"vnice":{"@unit":"ms/s","value":"0.000"},"vuser":{"@unit":"ms/s","value":"5.500"},"wait":{"total":{"@unit":"ms/s","value":"18.000"}}},"load":{"@instances":[{"name":"1 minute","value":"0.110"},{"name":"5 minute","value":"0.080"},{"name":"15 minute","value":"0.020"}]}}}}],"@source":"/var/log/pcp/pmlogger/bob.example.com/20230804.00.10.0","@timezone":"UTC-4"}]}
#
# Reference:
#   https://stedolan.github.io/jq/
#   https://stedolan.github.io/jq/manual/#Basicfilters
#   https://linux.die.net/man/1/ncdu
#   https://github.com/performancecopilot/pcp
#   https://pcp.io/documentation.html
#   https://www.man7.org/linux/man-pages/man1/pmrep.1.html#PCP_ENVIRONMENT
#
# History:
#   When          Who          Why
# -----------  ------------ -----------------------------
#  3-Aug-2023  Don Cohoon   Created
#--------------------------------------------------------
#
# Configs
#
CONFIG_DIR=~/.config/watch
YES=1
NO=0
SEND_MAIL="${SEND_MAIL:=${YES}}"
#SEND_MAIL="${SEND_MAIL:=${NO}}"
#..........................................
#
# Environment
#
HOSTNAME=$(/bin/hostname -s)
FQHN=$(/bin/hostname)
DIR=$(/usr/bin/dirname ${0})
JQ=/usr/bin/jq
DEBUG=0
#..........................................
#
# pmlogger database
#
ARCH_TIME=$(/bin/date -d "now - 20 minutes" "+%H:%M:%S")
# Once configured, the PCP tools that manage archive logs employ a consistent
#  scheme for selecting the basename for an archive each time pmlogger is launched, 
#  namely the current date and time in the format YYYYMMDD.HH.MM. Typically, at 
#  the end of each day, all archives for a particular host on that day would be 
#  merged to produce a single archive with a basename constructed from the date, 
#  namely YYYYMMDD. The pmlogger_daily script performs this action and a number 
#  of other routine housekeeping chores.
#  Reference: https://pcp.readthedocs.io/en/latest/UAG/ArchiveLogging.html#basenames-for-managed-archive-log-files
#
ARCH_TODAY=$(/bin/grep '^Archive: '  /var/log/pcp/pmlogger/${FQHN}/Latest| /usr/bin/awk '{print $NF}'|/usr/bin/xargs basename)
#  *.0 # Wildcard picks up most current file
# ARCH_YESTERDAY=0.xz 
# ARCH=/var/log/pcp/pmlogger/${FQHN}/${ARCH_DATE}.${ARCH_TODAY}
#ARCH_DATE=$(/bin/date +%Y%m%d) # today
ARCH=/var/log/pcp/pmlogger/${FQHN}/${ARCH_TODAY}
#..........................................
#
# Check for threshold exceeded
#
#..........................................
function checkit() {
  LIMIT=${1}
  #
  TMP=$(/bin/mktemp)
  TMP2=$(/bin/mktemp)
  # Only run for local single host, so no need to filter/display hosts
  CMD='.[]  | .["@hosts"]| .[] | .["@metrics"]| .[] | .["kernel"].all.load  | .["@instances"] | .[] | ' \
  #    Array     Index    Array     Index      Array     Index    Attribute      Index         Array  
  CMD+='select(.name=="5 minute" and ' \
  CMD+=".value > ${LIMIT} ) | .value "
  #
  /bin/echo "${PCP}" |  ${JQ}  "${CMD}" >${TMP}
  #
  if [ -s ${TMP} ]; then
    DATE=$(/bin/date +%Y%m%d%H%M%S)
    /bin/echo "Current time: " $(/bin/date -d now "+%H:%M:%S") ", Start time: "  ${ARCH_TIME} > ${TMP2}
    /bin/echo "-- System Load > ${LIMIT} " >> ${TMP2}
    /bin/cat ${TMP} >> ${TMP2}
    # Next get hogs if load is high, 4 samples, 3 items
    /bin/echo "--------- CPU ----------"      >> ${TMP2}
    /usr/bin/pmrep -s 4 -1gUJ 3 proc.hog.cpu  >> ${TMP2}
    /bin/echo "--------- MEM ----------"      >> ${TMP2}
    /usr/bin/pmrep -s 4 -1gUJ 3 proc.hog.mem  >> ${TMP2}
    /bin/echo "--------- DISK ----------"     >> ${TMP2}
    /usr/bin/pmrep -s 4 -1gUJ 3 proc.hog.disk >> ${TMP2}
    # Next get IO hogs if load is high (use input (-i) process name from CPU hogs)
    #sudo pmrep -gp -i qemu-kvm :proc-io
    if [ ${SEND_MAIL} == ${YES} ]; then
      ${DIR}/mail.sh ${TMP2} "${HOSTNAME} :${0} : System Load"
    fi
    #cp ${TMP2}  ${DIR}/monitor/${HOSTNAME}.util.${DATE}.${MP}.txt
    /bin/cat ${TMP2}
  fi
  /bin/rm -f ${TMP}
  /bin/rm -f ${TMP2}
}
#..........................................
#
# Get Threshold
#
#..........................................
function monitor () {
  while read LIMIT
  do
    checkit ${LIMIT}
  done < ${CONFIG_DIR}/util.${HOSTNAME}
}
#..........................................
#
# Parse Parameters
#
if [ $# -gt 0 ]; then
  A=${1}
  DEBUG=${2}
else
  /bin/echo "1) pmrep - Last 20 minutes load, and cpu statistics"
  /bin/echo "2) pmstat - Current system statistics"
  /bin/echo "3) monitor - System load monitor"
  read A
fi
#
case ${A}
 in
   1) # Report
    /bin/echo "System 5 Minute Load Alert is: $(/bin/cat ${CONFIG_DIR}/util.${HOSTNAME}) "
    /bin/echo "Current time: " $(/bin/date -d now "+%H:%M:%S") ", Start time: "  ${ARCH_TIME}
    /bin/echo "."
    /usr/bin/pmrep -L -a ${ARCH} -t 5m -A 5m -S @${ARCH_TIME} kernel.all.load
    /usr/bin/pmrep -L -a ${ARCH} -t 5m -A 5m -S @${ARCH_TIME} kernel.all.cpu.user kernel.all.cpu.sys kernel.all.cpu.idle kernel.all.cpu.wait.total
    ;;
   2) # Stats
    /usr/bin/pmstat
    ;;
   3) # System Load
    PCP=$(/usr/bin/pcp2json -E -H -L -z -a ${ARCH} -t 1m -A 1m -S @${ARCH_TIME} kernel.all.load )
    if [ "${DEBUG}" = "1" ]; then
      /bin/echo ${PCP} | ${JQ} '.[]|debug'
    fi
    monitor
    ;;
esac
