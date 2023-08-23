#!/bin/bash
#################################################################
#
# File: log.sh 
# Uses: 'Never Before Seen' database, 
#  and retail log tail utility.
#  https://www.ranum.com/security/computer_security/code/
#
# Berkerley DB:
#  Get the BSD DB library
#  > Re-directs to oracle: <https://www.oracle.com/database/technologies/related/berkeleydb-downloads.html#>  Need to log into oracle, download (via-download manager or wget.sh script proveded)
#  * unzip <download>
#  * cd <version>, i.e.: db-18.1.40
## To perform a standard UNIX build of Berkeley DB; 
#  1. Change to the build_unix directory
#  2. Enter the following two commands:
#  
#  ```
#  $ ../dist/configure
#  $ make
#  ```
#  * This will build the Berkeley DB library.
#  * To install the Berkeley DB library, enter the following command:
#
#  ```
#  $ sudo make install
#  ```
#  Add/Create File: ${CONFIG_DIR}/config.txt
#    export LD_LIBRARY_PATH=/usr/local/BerkeleyDB.18.1/lib
#
# Never Before Seen:
# - http://ranum.com/security/computer_security/code/nbs.tar
#  tar -xvf nbs.tar
#  cd nbs
#  make clean
#  make all
#
# Retail:
#  - git clone https://github.com/mbucc/retail
#  cd retail
#  make
#
# Filters:
# - Skip reporting local IP address on logs like: apache, nginx,...
#   grep -v -f local_ips.txt
#
# - Extract IP address and URL from apache -or- nginx
# File: geturl.pl
#!/usr/bin/perl
## example.com:80 6.22.8.8 - - [29/Mar/2018:07:36:35 -0400] "GET /mythweb/tv/channel/1052/1517563800 HTTP/1.1" 200 6156 "-" "Mozilla/5.0 (compatible; SemrushBot/1.2~bl; +http://www.semrush.com/bot.html)"
#while (<>) {
#  if(/"GET.*HTTP/) {
#    @array = split(/ /);
#    print("$array[0] - $array[1] "); # 0=nginx, 1=apache2
#    if ($array[6] =~ "GET") {
#      print("$array[7]\n");
#    } else {
#      print("$array[6]\n");
#    }
#  }
#}
#  --
#
# Status Directory:
# This will be automatically created on the first run of a file/filter.
# - Example for monitors fail2ban, and nginx-err
#  status
#  ├── fail2ban              <- database parameter
#  │   └── .fail2ban.log.off <- retail inode & offset for log file
#  ├── fail2ban.db.cnt       <- BDB − the counts index (allows rapid sorting/retrieval of "bottom/top N" data)
#  ├── fail2ban.db.idx       <- BDB − the master index (allows rapid neverseen checking and sorted retrieval of data keys)
#  ├── fail2ban.db.rec       <- BDB − the data records and their update information
#  ├── fail2ban.db.upd       <- BDB − the update time index (allows rapid sorting/retrieval of "least/most recently" updated data)
#  ├── nginx-err
#  │   └── .error.log.off
#  ├── nginx-err.db.cnt
#  ├── nginx-err.db.idx
#  ├── nginx-err.db.rec
#  └── nginx-err.db.upd
#
# Mail:
#  mail.sh (local)
#
# Config Directory:
# - Make the config directory
#   mkdir -p /root/.config
# - Create config file to point logwatch to watch user:
#   File: /root/.config/logwatch.txt
#   CONFIG_DIR=/home/don/.config/watch
# - Create a file ON each host, FOR each host; 
#   File: ${SSH_USER}/.config/watch/logwatch.vm3
#```
# File: logwatch.vm3
# #         DB                      File                   Alert  Email          Filter 
# #------------------------ ------------------------------ ------ ------ -----------------------------------
# email-messages              /var/log/maillog                N      Y     ${LOCAL_DIR}/email_filter.sh
# email-connect-messages      /var/log/maillog                Y      Y     ${LOCAL_DIR}/email_connect_filter.sh
# email-secure                /var/log/secure                 Y      Y     ${LOCAL_DIR}/email_auth_filter.sh
# fail2ban                    /var/log/fail2ban.log           Y      Y     cat
# nginx-access                /var/log/nginx/access.log       N      Y     ${LOCAL_DIR}/geturl.pl ${LOCAL_DIR}/skip_local_ips.sh
# nginx-err                   /var/log/nginx/error.log        Y      Y     ${LOCAL_DIR}/skip_local_ips.sh
# fail2ban                    /var/log/fail2ban.log           Y      Y     cat
#```
#
# Log: ${LOCAL_DIR}/log
# - View logs with _lnav_ 
#
# History:
# When        Who          What
# ----------- ------------ -----------------------------------------
# 2004        Marcus Ranum http://ranum.com/security/computer_security/code/index.html
# 2008        Don Cohoon   Created this script
# 16-Jul-2023 Don Cohoon   Modify for CentOS
#################################################################
#
# Configure
#
source /root/.config/logwatch.txt
#
HOST=$(hostname -s)
TMP=$(mktemp)
ID=$(id -u)
MY_DATE=$(/bin/date)
DIR=$(/usr/bin/dirname ${0})
#
if [ ${ID} -ne 0 ]; then
    echo "ERROR: Must run as root"
    exit 2
fi
#................................................................
#
# Check Log against Filter
#
function check_it () {
  db=${1}
  file=${2}
  alert=${3}
  email=${4}
  filter=${5}
  if (( $# > 5 )); then
    filter2=${6}
  else
    filter2="cat"
  fi   
  DIR=${LOCAL_DIR}/status
  mkdir -p ${DIR}
  #
  # Berkerly DB
  #
  DB=${DIR}/${db}.db
  # NOTE: Make the DB first (one-time)
  if [ ! -f $DB.cnt ]; then
    ${LOCAL_DIR}/nbs/nbsmk -d $DB
  fi
  #
  # Retail Log
  #
  LOG=${DIR}/${db}
  mkdir -p ${LOG}
  #
  # Check
  #
  ${LOCAL_DIR}/retail/retail -T ${LOG} ${file} | 
      ${LOCAL_DIR}/filters/${filter} | ${LOCAL_DIR}/filters/${filter2} | 
      ${LOCAL_DIR}/nbs/nbs -d $DB -o ${DIR}/${db}_new.txt
  #
  if [ -s ${DIR}/${db}_new.txt ]; then
    DATE=$(/bin/date +%Y%m%d%H%M%S)
    # top 10, reverse sort
    echo "---> Top 10 <---"             > ${DIR}/${db}_top10.txt
    ${LOCAL_DIR}/nbs/nbsdump -d $DB -c 10 -R >> ${DIR}/${db}_top10.txt
    #
    cat ${DIR}/${db}_new.txt ${DIR}/${db}_top10.txt >${TMP}
    if [ ${SEND_MAIL} = ${YES} ] && [ ${email} = "Y" ]; then
      ${LOCAL_DIR}/mail.sh ${TMP} ":${db} activity"
    fi
    if [ ${alert} = "Y" ]; then
      /bin/cat ${TMP} > ${LOCAL_DIR}/alert/${HOST}.${db}.${DATE}.txt
    fi
    rm -f ${TMP}
  fi
}
#................................................................
#
# Check Config
#
if [ ! -f ${CONFIG_DIR}/config.txt ]; then
  /bin/echo "${MY_DATE}:ERROR: Missing (config file) ${CONFIG_DIR}/config.txt"
  exit 2
else
  . ${CONFIG_DIR}/config.txt
fi
#
if [ ! -d ${LOCAL_DIR} ]; then
  /bin/echo "${MY_DATE}:ERROR: Missing (LOCAL_DIR) ${LOCAL_DIR}"
  exit 2
fi
#
LOGWATCH_CONFIG=${CONFIG_DIR}/logwatch.${HOST}
if [ ! -f ${LOGWATCH_CONFIG} ]; then
  /bin/echo "${MY_DATE}:ERROR: Missing (config file) ${LOGWATCH_CONFIG}"
  exit 2
fi
#
#................................................................
#
# Process Host File for My Host
#
cd ${LOCAL_DIR}
#
grep -v '^#' < ${LOGWATCH_CONFIG} | envsubst |
{ while read DB  FILE  ALERT  EMAIL  FILTERS
  do
    #..........................................
    #echo "${H}: db=${DB}; file=${FILE}; filters=${FILTERS}"
    check_it ${DB} ${FILE} ${ALERT} ${EMAIL} ${FILTERS}
    #..........................................
  done }
#..........................................
# Sync to Local Cloud, causing alert
#
sudo -u ${SSH_USER} ${DIR}/sync.sh 
#..........................................
#
# Cleanup
#

exit 0
