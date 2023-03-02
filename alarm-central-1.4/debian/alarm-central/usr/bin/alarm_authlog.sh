#!/bin/bash
grep publickey /var/log/auth.log > /home/alarm/auth.log
grep publickey /var/log/auth.log.1 >> /home/alarm/auth.log
chown alarm:alarm /home/alarm/auth.log
chmod 640 /home/alarm/auth.log
exit 0
