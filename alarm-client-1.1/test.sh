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
#	mv /tmp/alarms.tmp /tmp/alarms.pid
	echo $_yadname, $_option
}
