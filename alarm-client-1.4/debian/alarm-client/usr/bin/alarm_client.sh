#!/bin/bash
# alarm_client.sh
# lives in /usr/bin/ of each client
[[ "$2" != "alarm."* ]] && exit 0

declare -A ALARM
#inotifywait on /tmp passes alarm file name
ALARM['ONOFF']="$1" #values: CREATE, DELETE
ALARM['LOCATION_FILE']="/tmp/$2" #values: /tmp/alarm.*
ALARM['LOCATION']="${ALARM['LOCATION_FILE']#*alarm.}"

. /etc/alarm/alarm_global.conf
. /etc/alarm/alarm_local.conf
. $HOME/.config/alarm/alarm_user.conf
. /tmp/alarm_session.conf

ALARM['MYIP']="$(ip -4 addr | grep "inet ${ALARM['NETWORK']}" | awk '{print $2; } ' | sed "s/\/.*//; s/${ALARM['NETWORK']}//" | head -n1 )"
[[ "${ALARM['MYIP']}" == "" ]] && ALARM['MYIP']="XXX"

 _allstring=""
for _ip in ${ALARM['ALL']}; do
	# do not send to self
	[[ "$_ip" == "${ALARM['MYIP']}" ]] && continue
	# take full ip if no dot is in ip, add alarm network prefix otherwise
	echo $_ip | grep '\.' && _allstring+="alarm@$_ip " || _allstring+="alarm@${ALARM['NETWORK']}$_ip "
done

function _yad {
	_yadname="$1"
	shift 
	yad "$@" &
	echo "$_yadname $!" >> /tmp/alarms.pid
}

function _unyad {
	_single=true
	_yadname="$1"
	if [[ "$_yadname" == "-x" ]]; then _yadname="$2"; _single=false; fi
	while read _name _pid; do
		[[ "$_name" == "$_yadname" ]]; _w1=$?;
		$_single; _w2=$?
		[[ $(( $_w1 ^ $_w2 )) == 0 ]] && kill $_pid
	done < /tmp/alarms.pid
	_option="i"; $_single && _option="v"
	grep -$_option "$_yadname" /tmp/alarms.pid > /tmp/alarms.tmp
	mv /tmp/alarms.tmp /tmp/alarms.pid
}

function distributeAlarm() {
	case "${ALARM['ONOFF']}" in
		"CREATE")
			#in order to prevent quadratic scaling on ssh connections, check where the alarm came from
			#do nothing if file did not come from AP (so it has a non-zero size)
			#adapt for messages
			grep -E ^[0-9]+$ ${ALARM['LOCATION_FILE']} && return 1
#			[[ -s ${ALARM['LOCATION_FILE']} ]] && return 1
			#distribute if file did come from AP
			ssh alarm@localhost "echo ${ALARM['MYIP']} >> ${ALARM['LOCATION_FILE']}"
			cat ${ALARM['LOCATION_FILE']} | parallel-ssh --host "$_allstring" "cat >> ${ALARM['LOCATION_FILE']}"
			;;
		"DELETE")
			#in order to prevent quadratic scaling on ssh connections, distribute only own alarm deletions
			if [[ "${ALARM['IP',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"*  || "${ALARM['ALLCLEAR',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"* ]] ; then
				parallel-ssh --host "$_allstring" "rm ${ALARM['LOCATION_FILE']}"
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

function notifyAboutAlarm() {
	#update status bar
	_unyad -x revoke
	_alarmstring=""; _bg_color=""; _fg_color=""
	for _file in $(ls /tmp/alarm.*); do _alarmstring+="${ALARM['DESCRIPTION',${_file#/tmp/alarm.}]}|"; done
	#separate colors from alarmstring
	_bg_color="${ALARM['BGCOLOR',${ALARM['LOCATION']}]}"
	_fg_color="${ALARM['FGCOLOR',${ALARM['LOCATION']}]}"
	#do proper notification
	case "${ALARM['ONOFF']}" in
		"CREATE")
			#check for ALLCLEAR permissions		
			if [[ "${ALARM['IP',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"*  || "${ALARM['ALLCLEAR',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"* ]]; then
				_yad revoke --notification --image="dialog-warning" --text="Klicke, um zu entwarnen" --command="ssh alarm@localhost 'rm ${ALARM['LOCATION_FILE']}'" & 
			fi
			#check for NOALARM setting
			if [[ "${ALARM['IP',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"*  || "${ALARM['NOALARM',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"* ]]; then
				[[ "${ALARM['ACTIVE',${ALARM['LOCATION']}]}" != "TRUE" ]] && return
			fi
			#check for ACTIVE setting
			if [[ "${ALARM['ACTIVE',${ALARM['LOCATION']}]}" == "FALSE" ]]; then return; fi
			if [[ ${ALARM['VIDEO',${ALARM['LOCATION']}]} != "" ]]; then
			{
				# display message instead of alarm if "message" is part of alarm file
				if [[ "$(grep -i message ${ALARM['LOCATION_FILE']})" != "" ]]; then
					echo "$(date +%H:%M:%S)"> alarm.txt
					#remove last line (IP) and first line ("message")
					head -n -1 ${ALARM['LOCATION_FILE']} | tail -n +2 >> alarm.txt
					_bg_color="#ffdd00" #orange
					_fg_color="#000000" #white
				else
					echo -e "$(date +%H:%M:%S)\n\nALARM\n\n${ALARM['DESCRIPTION',${ALARM['LOCATION']}]}" > alarm.txt
					if [[ "$_bg_color" == "" ]]; then _bg_color="#ff0000"; fi #red if not set
					if [[ "$_fg_color" == "" ]]; then _fg_color="#ffffff"; fi #white if not set
				fi
				_fullscreen=""; _size=24
				if [[ "${ALARM['VIDEO',${ALARM['LOCATION']}]}" == "fullscreen" ]]; then _size=72; _fullscreen="--fullscreen"; fi
				_morealarms="$(echo $_alarmstring | sed "s/${ALARM['DESCRIPTION',${ALARM['LOCATION']}]}|//")"
				if [[ "$_morealarms" != "" ]]; then _morealarms="Weitere Alarme: $_morealarms"; fi
				_yad "create.${ALARM['LOCATION']}" --title "" --text-info --filename="alarm.txt" --text="<span foreground=\"red\" size=\"x-large\">$_morealarms</span>" --back="$_bg_color" --fore="$_fg_color"  --justify='center' --no-buttons --width=500 --height=300 --sticky --on-top --fontname="Sans Bold $_size" $_fullscreen &
			}& 
			fi
			if [[ ${ALARM['AUDIO',${ALARM['LOCATION']}]} != "" ]]; then
			{
				_audiofile="/usr/share/alarm/audio/${ALARM['AUDIO',${ALARM['LOCATION']}]}"
				if [[ "${ALARM['AUDIO_VOLUME',${ALARM['LOCATION']}]}" != "" ]]; then
					_audiovolume=${ALARM['AUDIO_VOLUME',${ALARM['LOCATION']}]}
				else
					_audiovolume=3
				fi				
				_audiolength="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $_audiofile)"
				_loops="$(echo ${ALARM['AUDIO_DURATION']}/$_audiolength | bc)";
				if [[ $_loops == 0 ]]; then _loops=1; fi #0 means endless loop...
				_volume_user="$(amixer get Master | grep '%'  | awk '{ print $4; }' | tail -n1)"
				amixer set Master $((21845*$_audiovolume))
				ffplay -nodisp -autoexit -loop $_loops $_audiofile
				amixer set Master $_volume_user	
			}&
			fi
			;;
		"DELETE")
			_unyad -x revoke
			if [[ "${ALARM['VIDEO',${ALARM['LOCATION']}]}" != "" ]]; then
			{
				if [[ "${ALARM['IP',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"*  || "${ALARM['NOALARM',${ALARM['LOCATION']}]}" == *"${ALARM['MYIP']}"* ]]; then
					echo -e "$(date +%H:%M:%S) Daten wurden gesendet" > alarm.txt
					_yad revoked --title "" --text-info --filename="alarm.txt" --back='#ffffff' --fore='#464646' --width=300 --no-buttons --sticky --on-top --fontname="Sans 10" &
					_unyad revoke
				else
					echo -e "$(date +%H:%M:%S)\n\nEntwarnung\n\n${ALARM['DESCRIPTION',${ALARM['LOCATION']}]}" > alarm.txt
					_fullscreen=""; _size=24
					if [[ "${ALARM['VIDEO',${ALARM['LOCATION']}]}" == "fullscreen" ]]; then _size=72; _fullscreen="--fullscreen"; fi
					_morealarms="$(echo $_alarmstring | sed "s/${ALARM['DESCRIPTION',${ALARM['LOCATION']}]}|//")"
					if [[ "$_morealarms" != "" ]]; then _morealarms="Noch aktive Alarme: $_morealarms"; fi
					_yad "delete.${ALARM['LOCATION']}" --title "" --text-info --text="<span foreground=\"red\" size=\"x-large\">$_morealarms</span>" --filename="alarm.txt" --back='#00ff00' --fore='#464646'  --justify='center' --no-buttons --width=500 --height=300 --sticky --on-top --fontname="Sans Bold $_size" $_fullscreen &
				fi
			}& 
			fi
			;;
	esac
	#update status bar, part ii
	if [[ "$_alarmstring" == "" ]]; then _icon="emblem-default"; else _icon="software-update-urgent"; fi
	_yad status --notification --image="$_icon" --text="Aktuelle Notfallalarme" --command=menu --menu="$_alarmstring"'|Nicht mehr anzeigen!quit' &		 	
}

notifyAboutAlarm&
distributeAlarm&
logAlarm
