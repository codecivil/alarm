#!/bin/bash
# alarm_client.sh
# lives in /usr/bin/ of each client (differ between main target and usual client?...)
[[ "$2" != "alarm."* ]] && exit 0

declare -A ALARM
#inotifywait on /tmp passes alarm file name
ALARM['ONOFF']="$1" #values: CREATE, DELETE
ALARM['LOCATION_FILE']="/tmp/$2" #values: /tmp/alarm.*
ALARM['LOCATION']="${ALARM['LOCATION_FILE']#*alarm.}"

. /etc/alarm/alarm_global.conf
. /etc/alarm/alarm_local.conf

ALARM['MYIP']="$(ip -4 addr | grep "inet ${ALARM['NETWORK']}" | awk '{print $2; } ' | sed "s/\/.*//; s/${ALARM['NETWORK']}//")"
[[ "${ALARM['MYIP']}" == "" ]] && ALARM['MYIP']="XXX"

 _allstring=""
for _ip in ${ALARM['ALL']}; do
	[[ "$_ip" == "${ALARM['MYIP']}" ]] && continue
	_allstring+="alarm@${ALARM['NETWORK']}$_ip "
done

function distributeAlarm() {
	case "${ALARM['ONOFF']}" in
		"CREATE")
			#in order to prevent quadratic scaling on ssh connections, check where the alarm came from
			#do nothing if file did not come from AP (so it has a non-zero size)
			#adapt to messages
			grep -E ^[0-9]+$ ${ALARM['LOCATION_FILE']} ]] && return 1
#			[[ -s ${ALARM['LOCATION_FILE']} ]] && return 1
			#distribute if file did come from AP
			ssh alarm@localhost "echo ${ALARM['MYIP']} >> ${ALARM['LOCATION_FILE']}"
			cat ${ALARM['LOCATION_FILE']} | parallel-ssh --host "$_allstring"  -O StrictHostKeyChecking=no "cat >> ${ALARM['LOCATION_FILE']}"
			;;
		"DELETE")
			#in order to prevent quadratic scaling on ssh connections, distribute only own alarm deletions
			if [[ "${ALARM['IP',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"* ]]; then
				parallel-ssh --host "$_allstring" -O StrictHostKeyChecking=no "rm ${ALARM['LOCATION_FILE']}"
			fi
			;;
	esac
}

function logAlarm() { 
	case "${ALARM['ONOFF']}" in
		"CREATE")		
			echo "$(date): emergency alarm SET OFF by ${ALARM['LOCATION']}, received from $(cat ${ALARM['LOCATION_FILE']})" >> ${ALARM['LOGFILE']}
			;;
		"DELETE")
			echo "$(date): emergency alarm CANCELLED by ${ALARM['LOCATION']}" >> ${ALARM['LOGFILE']}
			;;
	esac
}


distributeAlarm&
logAlarm
