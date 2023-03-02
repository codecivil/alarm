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
while [[ 0 -ge "$_central" ]]; do echo -n "Last octet of alarm CENTRAL (most reliably accessible node): "; read _central; done

sed -i "s/^ALARM\['CENTRAL'\]=[^ #]*/ALARM\['CENTRAL'\]=\"$_central\"/g;s/^ALARM\['NETWORK'\]=[^ #]*/ALARM\['NETWORK'\]=\"$_network\.\"/g;" /etc/alarm/alarm_global.conf
chmod 660 /etc/alarm/alarm_global.conf
chown root:alarm /etc/alarm/alarm_global.conf
[ -f /etc/alarm/alarm_global_central.conf ] && cat /etc/alarm/alarm_global_central.conf >> /etc/alarm/alarm_global.conf

declare -A ALARM
. /etc/alarm/alarm_global.conf

#allow passwordless login to alarm@CENTRAL for every user and clean up authorized key file on CENTRAL
if [[ "$_password" != "" ]]; then
	cat /home/alarm/.ssh/authorized_keys | SSHPASS="$_password" sshpass -e ssh -o StrictHostKeyChecking=no alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'cat >> .ssh/authorized_keys && /usr/bin/alarm_cleanup.sh'
else
	cat /home/alarm/.ssh/authorized_keys | ssh alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'cat >> .ssh/authorized_keys && /usr/bin/alarm_cleanup.sh 2>/dev/null || echo "Error: package alarm-central is not (properly) installed on CENTRAL"'
fi

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
	su $_USER -c "ssh -o StrictHostKeyChecking=no alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']} 'exit'"
done

cat /home/alarm/.ssh/authorized_keys | sort | uniq >> /home/alarm/.ssh/authorized_keys.tmp
mv /home/alarm/.ssh/authorized_keys.tmp /home/alarm/.ssh/authorized_keys

exit 0

