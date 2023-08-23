# Watch Notification System - v 2023.08.22
#

  * Finally got my alerts working, so when a host goes haywire I get an alert on the Phone and Cloud, with E-Mail as backup.

> Hope this helps,
> -- Don

alert.sh and log.sh are meant to run a few times per hour
and send alerts if watch thresholds are exceeded.

 * alert.sh - Usually runs on one host and monitors other hosts, using a normal user ssh tunnel.
 * log.sh - Usually runs on each host as root.

When any new file is uploaded into the
 _new alert user_ space, an entry will be written
  to the Conversation <name> with the name and link
  to that file.

On your Phone you can install NextCloud Talk, log in 
  as the new alert user and recieve notifications.
  Bonus: Your watch will alert you too!

On your Phone you can install NextCloud Sync, log in 
  as the new alert user and read notification files.

* Here is the file structure:

```
/home/bob/watch
.
├── alert
│   ├── vm5.util.20230822112005.uploaded
│   └── vm7.util.20230822130010.uploaded
├── alert.sh
├── db
│   ├── db-18.1.40
│   ├── oracle_berkely_DB-V997917-01.zip
│   └── readme
├── deploy.sh
├── df.sh
├── geturl.pl
├── log
│   ├── cloud.log.0
│   ├── cloud.log.1.gz
├── log.sh
├── mail.sh
├── nbs
│   ├── db.c
│   ├── db.o
│   ├── INSTALL
│   ├── Makefile
│   └── ...
├── nbs.tar
├── readme
├── retail
│   ├── Makefile
│   ├── retail
│   ├── retail.c
│   └── ...
├── retail.tar
├── savelog.sh
├── status
│   ├── apache-error
│   ├── apache-error.db.cnt
│   ├── apache-error.db.idx
│   ├── apache-error.db.rec
│   ├── apache-error.db.upd
│   ├── apache-error_new.txt
├── sync.sh
├── util.sh
└── watch.sh


/home/bob/.config
├── watch
│   ├── hosts.txt
│   ├── config.txt
│   └── df.oak
```

## Installation

Copy all files to ~/watch, or whatever directory you like, 
just change this documents' references of 
/home/bob
 to 
_your_ directory.

## Configuration

Create config directory structure:

```
$ mkdir -p ~/.config/watch
```

Create config file:

File: ~/.config/watch/config.txt
```
export CLOUD_USER=<nextcloud user>
export CLOUD_PASS="<nextcloud password>
export CLOUD_DIR=alert
export CLOUD_SERVER="https://www.example.com/nextcloud"
export CLOUD_LOG=/home/bob/watch/log/cloud.log
export LOCAL_DIR=/home/bob/watch
export SSH_USER=bob
export LD_LIBRARY_PATH=/usr/local/BerkeleyDB.18.1/lib:$LD_LIBRARY_PATH
```

* Make sure the LOCAL_DIR/alert exists
```
$ mkdir -p ${LOCAL_DIR}/alert
```

* Make sure CLOUD_LOG is writeable
```
$ touch ${CLOUD_LOG}
```

* Create an hosts.txt list of hosts to monitor

File: ~/.config/watch/hosts.txt
```
# Host   ssh    Remote   Remote
#        Port   Script   Home
# ------ ------ -------- -----------------------
vm1      223    0        /home/bob
vm2      224    1        /home/data/bob
#
# Remote Script: 1=run moniter script that is on remote machine 
#                0=run monitor script on local, through ssh tunnel
```

## Schedule alert.sh in cron

i.e.: every 20 minutes

File: /etc/cron.d/alert 
```
# Run the alert analysis
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO="bob@bob.com"
*/20 * * * * root /home/bob/watch/alert.sh
```

## Copy ssh keys to remote

If remote monitoring is desired; 

 * Generate and copy the _linux_ ssh keys.

```
$ ssh-key-gen
$ ssh-copy-id <remote hosts>
```

## Alert Functions

This is a seperate file for each functional alert, and sometimes host.

> Remote Hosts need their _own_ config file(s)
   
 * On the Remote Host(s):

```
$ mkdir -p ~/.config/watch
```

Example of **df** functional monitor. Each script will describe it's own.

File:  ~/.config/monitor/df.<hostname>
 Usage-Percent-Limit   File-System        Mount-Point
```
34                       "/dev/mmcblk1p2"   "/"
38                       "/dev/mmcblk1p1"   "/boot/firmware" 
16                       "/dev/md0"         "/mnt/raid1"
```

### Default is to send an e-mail if limits are exceeded

To stop E-Mail, add a SEND_MAIL export to the config.txt file.

 * 0 = NO
 * 1 = YES

File: ~/.config/watch/config.txt
```
~
export SEND_MAIL=0
~
```

## NextCloud Flow Notifications

 * Create _new alert user_ in NextCloud
   * Add the NextCloud server as SERVER in ~/.config/alert/config.txt
   * Add the NextCloud user as CLOUD_USER in ~/.config/alert/config.txt
   * Add the NextCloud user's password as CLOUD_PASS in ~/.config/alert/config.txt

 * As the _new alert user_ in NextCloud;
   * Go to Talk
     * Create a new group Conversation <name>
   * Go to Files and create a new alert directory
     * Add it as the REMOTE_DIR to ~/.config/alert/config.txt
   * Go to Personal Settings > Flow
     * Add a new flow _Write to conversasion_ (blue)
       * When: File created
       *  and: File size (upload) is greater than 0 MB
     * -> Write to conversasion using the
        * Conversation <name> created above

Reference: <https://github.com/nextcloud/flow_notifications>

## savelog.sh

This is used to save off several copies of the last sync.sh process sending alerts to the NextCloud server.

> The logs are better viewed using the _lnav_ Linu package. ```lnav ~/watch/log/```

This is released on many OS packages, but not all,
so it is included here. Thanks very much to the original authors!

Reference:
 * <https://launchpad.net/ubuntu/xenial/+package/debianutils>
 * <https://manpages.ubuntu.com/manpages/xenial/en/man8/savelog.8.html>
 * <https://opensource.apple.com/source/uucp/uucp-10/uucp/contrib/savelog.sh.auto.html>
 * <https://rhel.pkgs.org/8/lux/uucp-1.07-65.el8.lux.x86_64.rpm.html>
 
## log.sh - Log Watcher

This script runs as root on each node to search for Never Before Seen (NBS) entries in a log file.
It needs to be scheduled in cron.

The flow is:

1. cron runs log.sh

File: /etc/cron.d/logwatcher
```
# Log - Watcher
PATH=/usr/lib/sysstat:/usr/sbin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO="bob@bob.com"
# Run Log watcher
*/20 * * * * bob  /home/bob/watch/log.sh 
```

2. log.sh reads config file ~/.config/watch/logwatch.<hostname>

File: logwatch.oak
```
# File: logwatch.oak
#           DB                      File                               Alert  Email          Filter 
# ------------------------- ----------------------------------------- ------ ------ -----------------------------------#
apache-access                /var/log/apache2/access.log               N      Y     geturl.pl skip_local_ips.sh
apache-error                 /var/log/apache2/error.log                Y      Y     geturl.pl
apache-other_vhosts_access   /var/log/apache2/other_vhosts_access.log  Y      Y     geturl.pl
```

3. New lines in File are read by retail, filtered by any and all Filters supplied.
4. DB is checked if this has been seen before and can be ignored.
5. Any remainging lines are sent to the alert directory and an Email sent, if Y in config.txt.
6. A sync for new alert files is done, sending new files to the cloud (NextCloud).
7. NextCloud will send a Talk alert to the CLOUD_USER for new files. These are viewable on a Phone or Watch, if running the Talk app.

The following software packages have to be installed and compiled locally:
 * Berkerly DB
 * Never Before Seen (NBS)
 * Retail 

Refer to the log.sh script for instructions.

Reference: 

 * Marcus Ranum <http://ranum.com/security/computer_security/code/index.html>

## Trouble Resolution

#### armv7l issues

The pmlogger systemd daemon had issues being installed, and the following log instructions solved it.

```
Aug 08 11:07:39 bob.example.com systemd[1]: Starting LSB: Control pmlogger (the performance metrics logger for PCP)...
Aug 08 11:07:43 bob.example.com pmlogger[913]: /etc/init.d/pmlogger: Warning: Performance Co-Pilot archive logger(s) not permanently enabled.
Aug 08 11:07:43 bob.example.com pmlogger[913]:     To enable pmlogger, run the following as root:
Aug 08 11:07:44 bob.example.com pmlogger[913]:          update-rc.d -f pmlogger remove
Aug 08 11:07:44 bob.example.com pmlogger[913]:          update-rc.d pmlogger defaults 94 06
```

