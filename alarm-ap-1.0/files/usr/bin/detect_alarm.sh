#!/bin/ash
# detect_alarm.sh
# lives in /usr/bin/ of AP
#
_interface="$1"
_status="$2"
_mac="$3"

. /etc/alarm/alarm_ap.conf #contains list of mac addresses of dash buttons and translates them to rooms/persons

for _allowedMac in $ALARM_MAC; do
	if [[ "${_allowedMac#$_mac}" != "$_allowedMac" ]]; then
		if [[ $_status == "AP-STA-CONNECTED" ]]
		then
			for _target in $ALARM_TARGETS; do
				ssh -i /etc/dropbear/dropbear_rsa_host_key -y "alarm@$ALARM_NETWORK$_target" "touch /tmp/alarm.${_allowedMac#*=}"
			done
		fi

	fi
done
