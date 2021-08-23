#!/bin/bash
declare -A ALARM

. /etc/alarm/alarm_global.conf

# do not start until local network is available
while ! ping -c1 ${ALARM['NETWORK']}${ALARM['CENTRAL']}; do sleep 10; done

# get global config from CENTRAL
scp alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']}:/etc/alarm/alarm_global.conf /etc/alarm/

. /etc/alarm/alarm_global.conf

# get current keys from CENTRAL

#only users can login to alarm@*, so from alarm to alarm we have to use user as third party: -3
scp -3 alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']}:/home/alarm/.ssh/authorized_keys alarm@localhost:/home/alarm/.ssh/
scp -3 alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']}:/home/alarm/.ssh/known_hosts alarm@localhost:/home/alarm/.ssh/known_hosts.tmp
ssh alarm@localhost 'cd .ssh; cat known_hosts >> known_hosts.tmp; cat known_hosts.tmp | sort | uniq > known_hosts; rm known_hosts.tmp'

#get known hosts for user so that alarm deletions work (and creation is faster)
scp alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']}:/home/alarm/.ssh/known_hosts $HOME/.ssh/known_hosts.tmp
cd $HOME/.ssh; cat known_hosts >> known_hosts.tmp; cat known_hosts.tmp | sort | uniq > known_hosts; rm known_hosts.tmp

# set up watches

inotifywait -m -e create,delete /tmp | {
	while read _DIR _ACTION _FILE; do
		[[ "$_FILE" == "alarm."* ]] && /usr/bin/alarm_client.sh $_ACTION "$_FILE"
	done
} &

# get current alarms from CENTRAL

scp -3 alarm@${ALARM['NETWORK']}${ALARM['CENTRAL']}:/tmp/alarm.* alarm@localhost:/tmp/

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
