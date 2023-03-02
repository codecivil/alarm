#!/bin/bash
declare -A ALARM

. /etc/alarm/alarm_global.conf

# set up watches

inotifywait -mr -e create,delete /tmp | {
	while read _DIR _ACTION _FILE; do
		[[ "$_FILE" == "alarm."* ]] && /usr/bin/alarm_central.sh $_ACTION "$_FILE"
	done
} &

# remove expired alarms
while true; do
	_now="$(date +%s)"
	stat -c "%n %Y" /tmp/alarm.* | { 
		while read _file _ctime; do
			if [[ $(( _now - _ctime)) -ge ${ALARM['EXPIRES']} ]]; then ssh -n alarm@localhost "rm $_file"; fi # -n: so ssh does not read from stdin, eating up all other alarm files...
		done
	}
	sleep ${ALARM['EXPIRES']}
done

exit 0
