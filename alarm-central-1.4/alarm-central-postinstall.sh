#!/bin/bash
#alarm-central-postinstall.sh
#configures most important network settings

#script mus be run as root
if [[ "$(whoami)" != "root" ]]; then echo "This script must be run as root."; exit 0; fi

_default_network="$(ip addr | grep 'inet ' | awk '{printf "%s\n",$2 }' | sort | tail -n1)"
_default_network="${_default_network%.*}"
_default_ip="$(ip -4 addr | grep "inet $_default_network." | awk '{print $2; } ' | sed "s/\/.*//; s/$_default_network.//")"

while [[ "$_network" != *.*.* ]]; do 
	echo -n "Your network [$_default_network]: "; read _network; 
	[[ "$_network" == "" ]] && _network="$_default_network"	
done
_central=":"
while echo $_central | grep -Eo '[^0-9\. ]' >/dev/null; do 
	echo -n "IPs/Last octet of alarm CENTRAL (most reliably accessible node) [$_default_ip]: "; read _central; 
	[[ "$_central" == "" ]] && _central="$_default_ip"	
done

sed -i "s/^ALARM\['CENTRAL'\]=[^ #]*/ALARM\['CENTRAL'\]=\"$_central\"/g;s/^ALARM\['NETWORK'\]=[^ #]*/ALARM\['NETWORK'\]=\"$_network\.\"/g;" /etc/alarm/alarm_global_central.conf
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

