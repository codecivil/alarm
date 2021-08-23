#!/bin/bash
#alarm-postinstall.sh [-n|--network NETWORK] [-p|--password PASSWORD] [-c|--central CENTRAL] [-y|--yes]
#configures most important network settings

function parseArgs() {
	while [[ "$@" != '' ]]; do
		case "$1" in
			"-n"|"--network")
				shift
				_network="$1"
				;;
			"-p"|"--password")
				shift
				_password="$1"
				;;
			"-c"|"--central")
				shift
				_central="$1"
				;;
			"-y"|"--yes")
				_yes=true
				;;
		esac
		shift
	done
}

parseArgs $@

_default_network="$(ip addr | grep 'inet ' | awk '{printf "%s\n",$2 }' | sort | tail -n1)"
_default_network="${_default_network%.*}"
if $_yes; then 	[[ "$_network" == "" ]] && _network="$_default_network"; fi
while [[ "$_network" != *.*.* ]]; do 
	echo -n "Your network [$_default_network]: "; read _network; 
	[[ "$_network" == "" ]] && _network="$_default_network"	
done
while [[ 0 -ge "$_central" ]]; do echo -n "Last octet of alarm CENTRAL (most reliably accessible node): "; read _central; done

while read _line; do
	case "$_line" in
	"ALARM['NETWORK']="*) echo "ALARM['NETWORK']=\"$_network.\"" >> /tmp/alarm_global.conf;;
	"ALARM['CENTRAL']="*) echo "ALARM['CENTRAL']=\"$_central\"" >> /tmp/alarm_global.conf;;
	*) echo $_line >> /tmp/alarm_global.conf;;
	esac
done < /etc/alarm/alarm_global.conf
mv /tmp/alarm_global.conf /etc/alarm/alarm_global.conf
chmod 660 /etc/alarm/alarm_global.conf
chown root:alarm /etc/alarm/alarm_global.conf
[ -f /etc/alarm/alarm_global_central.conf ] && cat /etc/alarm/alarm_global_central.conf >> /etc/alarm/alarm_global.conf

declare -A ALARM
. /etc/alarm/alarm_global.conf

#allow passwordless login to alarm@CENTRAL for every user
if [[ "$_password" != "" ]]; then
	cat /home/alarm/.ssh/authorized_keys | SSHPASS="$_password" sshpass -e ssh -o StrictHostKeyChecking=no alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'cat >> .ssh/authorized_keys'
else
	cat /home/alarm/.ssh/authorized_keys | ssh alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'cat >> .ssh/authorized_keys'
fi
# add alarm@CENTRAL to known hosts of every user
for _USER in $(ls /home); do
	su $_USER -c "ssh -o StrictHostKeyChecking=no alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'exit'"
done

exit 0

