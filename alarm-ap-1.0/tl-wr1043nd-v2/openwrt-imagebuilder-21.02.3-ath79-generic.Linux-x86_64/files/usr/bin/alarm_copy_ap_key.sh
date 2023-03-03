#!/bin/ash
. /etc/alarm/alarm_ap.conf
i=0
for _target in $ALARM_TARGETS; do
	if [[ "$i" == "1" ]]; then exit 0; fi
	dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key | grep "^ssh-rsa " > /etc/alarm/ap_key.pub 
	cat /etc/alarm/ap_key.pub | ssh -i /etc/dropbear/dropbear_rsa_host_key -y "alarm@$ALARM_NETWORK$_target" "cat >> .ssh/authorized_keys"
	i=1
done
