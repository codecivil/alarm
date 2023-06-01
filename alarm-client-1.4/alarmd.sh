#!/bin/bash

# do not start twice (just to be safe)
[[ -f /tmp/lock.$(whoami).alarm ]] && ps --pid $(cat /tmp/lock.$(whoami).alarm) && exit 0
touch /tmp/lock.$(whoami).alarm

[ -d $HOME/.config/alarm ] || mkdir -p $HOME/.config/alarm
touch $HOME/.config/alarm/alarm_user.conf

declare -A ALARM

. /etc/alarm/alarm_global.conf

# do not start until local network is available
_networkdown=true
while $_networkdown; do
	_nohit=true
	for _central in ${ALARM['CENTRAL']} ${ALARM['CENTRAL_ALT']}; do
		if $_nohit; then
			if echo $_central | grep '\.'; then
				ping -c1 $_central && { ALARM['CENTRAL']="$_central"; _networkdown=false; _nohit=false; }
			else 
				ping -c1 ${ALARM['NETWORK']}$_central && { ALARM['CENTRAL']="${ALARM['NETWORK']}$_central"; _networkdown=false; _nohit=false; }
			fi
		fi
	done
	$_nohit && sleep 10
done

# get global config from CENTRAL (but preserve CENTRAL)
_tmpcentral=${ALARM['CENTRAL']}
scp alarm@${ALARM['CENTRAL']}:/etc/alarm/alarm_global.conf /etc/alarm/

. /etc/alarm/alarm_global.conf
ALARM['CENTRAL']="$_tmpcentral"
_tmpcentral=""

# get current keys from CENTRAL
#first, clean up the key store
ssh alarm@${ALARM['CENTRAL']} 'cat .ssh/authorized_keys | sort | uniq >> /tmp/authorized_keys.tmp; cp /tmp/authorized_keys.tmp .ssh/authorized_keys; rm /tmp/authorized_keys.tmp;'
#only users can login to alarm@*, so from alarm to alarm we have to use user as third party: -3
scp -3 alarm@${ALARM['CENTRAL']}:/home/alarm/.ssh/authorized_keys alarm@localhost:/home/alarm/.ssh/
scp -3 alarm@${ALARM['CENTRAL']}:/home/alarm/.ssh/known_hosts alarm@localhost:/home/alarm/.ssh/known_hosts.tmp
ssh alarm@localhost 'cd .ssh; cat known_hosts >> known_hosts.tmp; cat known_hosts.tmp | sort | uniq > known_hosts; rm known_hosts.tmp'

#get known hosts for user so that alarm deletions work (and creation is faster)
scp alarm@${ALARM['CENTRAL']}:/home/alarm/.ssh/known_hosts $HOME/.ssh/known_hosts.tmp
cd $HOME/.ssh; cat known_hosts >> known_hosts.tmp; cat known_hosts.tmp | sort | uniq > known_hosts; rm known_hosts.tmp

# set up watches

inotifywait -m -e create,delete /tmp | {
	while read _DIR _ACTION _FILE; do
		[[ "$_FILE" == "alarm."* ]] && /usr/bin/alarm_client.sh $_ACTION "$_FILE"
	done
} &
echo "$!" > /tmp/lock.$(whoami).alarm #preserve PID of inotify...

# get current alarms from CENTRAL

scp -3 alarm@${ALARM['CENTRAL']}:/tmp/alarm.* alarm@localhost:/tmp/

# remove expired alarms
while true; do
	_now="$(date +%s)"
	stat -c "%n %Y" /tmp/alarm.* | { 
		while read _file _ctime; do
			if [[ $(( _now - _ctime)) -ge ${ALARM['EXPIRES']} ]]; then ssh -n alarm@localhost "rm $_file"; fi
		done
	}
	sleep ${ALARM['EXPIRES']}
done

exit 0
