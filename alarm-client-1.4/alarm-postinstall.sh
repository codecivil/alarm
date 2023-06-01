#!/bin/bash
#alarm-postinstall.sh [-n|--network NETWORK] [-p|--password PASSWORD] [-c|--central CENTRAL] [-y|--yes]
#configures most important network settings

function parseArgs() {
	_yes=false
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
while [[ 0 -ge "$_central" ]]; do echo -n "Last octet or full IPs address of alarm CENTRALs (most reliably accessible nodes): "; read _central; done

sed -i "s/^ALARM\['CENTRAL'\]=[^ #]*/ALARM\['CENTRAL'\]=\"$_central\"/g;s/^ALARM\['NETWORK'\]=[^ #]*/ALARM\['NETWORK'\]=\"$_network\.\"/g;" /etc/alarm/alarm_global.conf
chmod 660 /etc/alarm/alarm_global.conf
chown root:alarm /etc/alarm/alarm_global.conf
[ -f /etc/alarm/alarm_global_central.conf ] && cat /etc/alarm/alarm_global_central.conf >> /etc/alarm/alarm_global.conf

declare -A ALARM
. /etc/alarm/alarm_global.conf

#allow passwordless login to alarm@CENTRAL for every user and clean up authorized key file on CENTRAL
for _central in ${ALARM['CENTRAL']} ${ALARM['CENTRAL_ALT']}; do
	if echo $_central | grep -v '\.' >/dev/null; then _central="${ALARM['NETWORK']}$_central"; fi
	if [[ "$_password" != "" ]]; then
		cat /home/alarm/.ssh/authorized_keys | SSHPASS="$_password" sshpass -e ssh -o StrictHostKeyChecking=no alarm@"$_central" 'cat >> .ssh/authorized_keys && /usr/bin/alarm_cleanup.sh'
	else
		cat /home/alarm/.ssh/authorized_keys | ssh alarm@"$_central" 'cat >> .ssh/authorized_keys && /usr/bin/alarm_cleanup.sh 2>/dev/null || echo "Error: package alarm-central is not (properly) installed on CENTRAL"'
	fi
	# get and read global conf
	su alarm -c "scp alarm@$_central:/etc/alarm/alarm_global.conf /etc/alarm/"
	. /etc/alarm/alarm_global.conf
	# auto registration: add local IP to the ALL value in alarm_global.conf if not yet there
	ALARM['MYIP']="$(ip -4 addr | grep "inet ${ALARM['NETWORK']}" | awk '{print $2; } ' | sed "s/\/.*//; s/${ALARM['NETWORK']}//" | head -n1 )"
	if [[ "${ALARM['ALL']}" != *" ${ALARM['MYIP']}"* ]] && [[ "${ALARM['ALL']}" != *"${ALARM['MYIP']} "* ]]; then
		su alarm -c "ssh alarm@$_central cp /etc/alarm/alarm_global.conf /etc/alarm/alarm_global_$(date +%s).conf" #backup old global conf
		su alarm -c "ssh alarm@$_central 'sed -i '\"'\"'s/\(ALARM.*ALL.*=\"\)\([^\"]*\)\(\"\)/\1\2 ${ALARM['MYIP']}\3/'\"'\" /etc/alarm/alarm_global.conf"
	fi
	# sync client and server conf
	su alarm -c "ssh alarm@$_central '[[ -f /etc/alarm/alarm_global_central.conf ]] && cp /etc/alarm/alarm_global.conf /etc/alarm/alarm_global_central.conf'"
done

# add alarm@CENTRAL to known hosts of every user
# and install alarmd for every user (and generate ssh-key if not exists)
# (this section is largely copied from postinst so that you can simply run alarm-postinstall.sh after adding a new user
# and do not have to reinstall the whole package!)
for _USER in $(ls /home); do
	# ignore users with expired password...
	[[ "$(grep -e ^$_USER: /etc/shadow | sed 's/:/ /g' | awk '{print $3; }')" == "0" ]] && { echo "User $_USER is ignored: password has expired"; continue; }
	# ignore users without login
	grep -e ^$_USER: /etc/passwd | grep -v nologin > /dev/null || continue
	#
	_HOME="$(eval echo ~$_USER)"
	[ -d $_HOME/.config/autostart ] || mkdir -p $_HOME/.config/autostart
	cp -a /usr/share/alarm/alarmd.desktop $_HOME/.config/autostart/
	[ -d $_HOME/.config/alarm ] || mkdir -p $_HOME/.config/alarm
	touch $_HOME/.config/alarm/alarm_user.conf
	#repair ownership
	chown -R $_USER:$_USER $_HOME/.config/alarm
	chown -R $_USER:$_USER $_HOME/.config/autostart
	#generate ssh key if not present
	[ -f $_HOME/.ssh/id_rsa.pub ] || su $_USER -c 'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa' && cat $_HOME/.ssh/id_rsa.pub >> /home/alarm/.ssh/authorized_keys
	# add localhost to known hosts of every user
	su $_USER -c "ssh -o StrictHostKeyChecking=no alarm@localhost 'exit'"
	usermod -aG alarm $_USER
	# add alarm@CENTRAL to known hosts of every user
	for _central in ${ALARM['CENTRAL']} ${ALARM['CENTRAL_ALT']}; do
		if echo $_central | grep -v '\.' >/dev/null; then _central="${ALARM['NETWORK']}$_central"; fi
		su $_USER -c "ssh -o StrictHostKeyChecking=no alarm@$_central 'exit'"
	done
done

cat /home/alarm/.ssh/authorized_keys | sort | uniq >> /home/alarm/.ssh/authorized_keys.tmp
mv /home/alarm/.ssh/authorized_keys.tmp /home/alarm/.ssh/authorized_keys

exit 0

