#!/bin/bash

source ./sftplib.bash 

TEMP_SYSLOG=$(mktemp)

sftp_init root@devuan
sftp_do "pwd"
sftp_do "cd /var/log"
sftp_do "get syslog $TEMP_SYSLOG"
sftp_end
rm "$TEMP_SYSLOG"
