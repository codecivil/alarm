#!/bin/bash
#alarm-central-postinstall.sh
#configures most important network settings

_default_network="$(ip addr | grep 'inet ' | awk '{printf "%s\n",$2 }' | sort | tail -n1)"
_default_network="${_default_network%.*}"
_default_ip="$(ip -4 addr | grep "inet $_default_network." | awk '{print $2; } ' | sed "s/\/.*//; s/$_default_network.//")"

while [[ "$_network" != *.*.* ]]; do 
	echo -n "Your network [$_default_network]: "; read _network; 
	[[ "$_network" == "" ]] && _network="$_default_network"	
done
while [[ 0 -ge "$_central" ]]; do 
	echo -n "Last octet of alarm CENTRAL (most reliably accessible node) [$_default_ip]: "; read _central; 
	[[ "$_cdentral" == "" ]] && _central="$_default_ip"	
done

while read _line; do
	case "$_line" in
	"ALARM['NETWORK']="*) echo "ALARM['NETWORK']=\"$_network.\"" >> /tmp/alarm_global.conf;;
	"ALARM['CENTRAL']="*) echo "ALARM['CENTRAL']=\"$_central\"" >> /tmp/alarm_global.conf;;
	*) echo $_line >> /tmp/alarm_global.conf;;
	esac
done < /etc/alarm/alarm_global_central.conf
mv /tmp/alarm_global.conf /etc/alarm/alarm_global_central.conf
chmod 660 /etc/alarm/alarm_global_central.conf
chown root:alarm /etc/alarm/alarm_global_central.conf
[ -f /etc/alarm/alarm_global_central.conf ] && cat /etc/alarm/alarm_global_central.conf >> /etc/alarm/alarm_global.conf

## set password for alarm (so that clients can connect with CENTRAL at installation)
echo "Set password for user alarm"
passwd alarm

#declare -A ALARM
#. /etc/alarm/alarm_global_central.conf
#cat /home/alarm/.ssh/authorized_keys | ssh alarm@localhost 'cat >> .ssh/authorized_keys'

exit 0

