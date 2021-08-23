#!/bin/bash
#alarm_configurator.sh
#
#
## update and read global conf
declare -A ALARM

. /etc/alarm/alarm_global.conf
. /etc/alarm/alarm_local.conf
. /tmp/alarm_session.conf

_tmp=false;

ALARM['MYIP']="$(ip -4 addr | grep "inet ${ALARM['NETWORK']}" | awk '{print $2; } ' | sed "s/\/.*//; s/${ALARM['NETWORK']}//")"

## get locations
_locations=()
for _key in "${!ALARM[@]}"; do
	if [[ "$_key" == "DESCRIPTION,"* ]]; then
		_locations+=("${_key#DESCRIPTION,}")
	fi
done

## choose location to edit
_config=()
for ((i=0; i<${#_locations[@]}; i++)); do
	_config+=("FALSE" "${_locations[$i]}" "${ALARM['DESCRIPTION',${_locations[i]}]}")
	_active[$i]="TRUE"
	if [[ "${ALARM['IP',${_locations[$i]}]}" == *"${ALARM['MYIP']}"* ]]; then _active[$i]="FALSE"; fi
	case "${ALARM['ACTIVE',${_locations[$i]}]}" in
		"TRUE") _active[$i]="TRUE";;
		"FALSE") _active[$i]="FALSE";;	
	esac
	case "${_active[$i]}" in
		"TRUE") _config+=("checkbox-checked-symbolic.symbolic");;
		"FALSE") _config+=("checkbox-symbolic.symbolic");;
	esac
	case "${ALARM['VIDEO',${_locations[$i]}]}" in
		"fullscreen") _config+=("Vollbild");;
		"normal") _config+=("Normal");;
		"") _config+=("Kein");;
	esac
	case "${ALARM['AUDIO',${_locations[$i]}]}" in
		"") _config+=("Stumm");;
		*) _config+=("${ALARM['AUDIO',${_locations[$i]}]}");;
	esac
	case "${ALARM['AUDIO_VOLUME',${_locations[$i]}]}" in
		"") _config+=("3");;
		*) _config+=("${ALARM['AUDIO_VOLUME',${_locations[$i]}]}");;
	esac
	case "${ALARM['TMP',${_locations[$i]}]}" in
		"TRUE") _config+=("appointment-soon");;
		*) _config+=("format-justify-fill");;
	esac
done
_choose_location=""
# implement the choice to alter the config only for this session: variable for config file and in yad: button?
# already done: session changes choosable; but if you change the local conf after that this change will not effect immediately... change that!
while [[ "$_choose_location" == "" ]]; do
	_choose_location="$(yad --center --on-top --list --title 'Alarmkonfiguration Übersicht' --text "Zum Bearbeiten bitte einen Button wählen" --button=gtk-edit:0 --button="Nur für diese Session ändern":4 --button="Session zurücksetzen":5 --button=gtk-quit:2 --width 600 --height 600 --column '':RD --column Button:TEXT --column Ort:TEXT --column "Alarm an":IMG --column Video:TEXT --column Audio:TEXT --column Lautstärke:NUM --column '':IMG  ${_config[@]})"
	case $? in
		4) _configfile="/tmp/alarm_session.conf"; _tmp=true;;
		2) exit 2;;
		5) 	rm /tmp/alarm_session.conf
			alarm_configurator.sh &
			exit 0;;
		*) _configfile="/etc/alarm/alarm_local.conf";;
	esac
	_choose_location="$(echo $_choose_location | grep TRUE)"
done

OIFS=$IFS
IFS='|'
entry=( $_choose_location )
IFS=$OIFS
## construct form
_video_init=${entry[4]}; _audio_init=${entry[5]}
_options_video="$_video_init,Normal,Vollbild,Kein"; 
_options_sound=("$_audio_init" "Stumm" $(ls /usr/share/alarm/audio/ ))
_options_sound="$(echo ${_options_sound[@]} | sed 's/ /,/g')"
_options_active="${_active[@]}"
#_field=()

_location="${_choose_location#TRUE\|}"; _location="${_location%%\|*}"
_edit_location="$(yad --title="Bearbeite Alarmkonfiguration" --text="<b>${ALARM['DESCRIPTION',$_location]}</b>" --width 700 --item-separator="," --form --field="Aktiv":CHK "${ALARM['ACTIVE',$_location]}" --field="Video":CB "$_options_video" --field="Audio":CB "$_options_sound" --field="Lautstärke":NUM "${entry[6]},1..3,1,0" --field="Audio anhören":CHK FALSE)"
if [[ "$?" != "0" ]]; then 
	alarm_configurator.sh &
	exit 0
fi
OIFS=$IFS
IFS='|'
entry=( $_edit_location )
IFS=$OIFS

grep -v "$_location" "$_configfile" > /tmp/tmp.conf
case ${entry[1]} in
	"Vollbild") entry[1]="fullscreen";;
	"Normal") entry[1]="normal";;
	"Kein") entry[1]="";;
esac
case ${entry[2]} in
	"Stumm") entry[2]="";;
esac
echo -e "ALARM['ACTIVE','$_location']=\"${entry[0]}\"\nALARM['AUDIO','$_location']=\"${entry[2]}\"\nALARM['AUDIO_VOLUME','$_location']=\"${entry[3]}\"\nALARM['VIDEO','$_location']=\"${entry[1]}\"" >> /tmp/tmp.conf
$_tmp && echo -e "ALARM['TMP','$_location']=\"TRUE\"" >> /tmp/tmp.conf
mv /tmp/tmp.conf "$_configfile"
if [[ "${entry[2]}" != "" ]] && [[ "${entry[4]}" == "TRUE" ]]; then 
	_audiofile="/usr/share/alarm/audio/${entry[2]}"
	_audiolength="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $_audiofile)"
	_loops="$(echo ${ALARM['AUDIO_DURATION']}/$_audiolength | bc)";
	_volume_user="$(amixer get Master | grep '%'  | awk '{ print $4; }' | tail -n1)"
	amixer set Master $((21845*${entry[3]}))
	ffplay -nodisp -autoexit -loop $_loops $_audiofile
	amixer set Master $_volume_user	
fi
alarm_configurator.sh &
exit 0
