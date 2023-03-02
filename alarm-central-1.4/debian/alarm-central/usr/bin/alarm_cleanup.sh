#!/bin/bash
AUTH="/home/alarm/auth.log"
KEYS="/home/alarm/.ssh/authorized_keys"
BLACKLIST="/home/alarm/blacklist"

function _cleanAuthorizedKeys {
	# concatenate auth logs
	rm /tmp/auth.log
	for log in $AUTH; do cat $log >> /tmp/auth.log; done
	# remove all non-sense entries
	grep -E 'ssh-rsa [^ ]* [^  @]*@[^ @]*$' "$KEYS" > /tmp/authorized_keys
	cp /tmp/authorized_keys "$KEYS" # cp+rm instead of mv for preserving ownership of target
	rm /tmp/authorized_keys
	# remove doublets
	cat "$KEYS" | sort | uniq > /tmp/authorized_keys
	cp /tmp/authorized_keys "$KEYS"
	rm /tmp/authorized_keys	
	# remove blacklisted users (patterns)
	sed -i 's/ //g' "$BLACKLIST" #remove (accidental) spaces from blacklist file before parsing (every entry must be on a separate line!)
	while read line; do
		if [[ "$line" != "" && "$line" != "#"* ]]; then
			grep -v "$line" "$KEYS" > /tmp/authorized_keys
			cp /tmp/authorized_keys "$KEYS"
		fi
	done < "$BLACKLIST"
	# scan auth logs for ssh key fingerprints
	cp "$KEYS" /tmp/authorized_keys
	grep SHA256 /tmp/auth.log | sed 's/.*SHA256://' | sort | uniq | while read fingerprint; do
		# find user in authorized_keys and collect all entries matching this fingerprint
		_user="$(ssh-keygen -E sha256 -lf "$KEYS" | grep "${fingerprint}" | awk '{ printf $3 }' | tail -n1 )"
		if [[ "$_user" != *"@"* ]]; then echo "No proper user: $_user"; continue; fi
		touch /tmp/authorized_keys".$_user"
		grep "$_user" "$KEYS" | while read _key; do 
			echo "$_key" | ssh-keygen -E sha256 -lf - | grep $_user && echo "$_key" >> /tmp/authorized_keys".$_user"	
		done
		# remove _user from temporary file of other keys
		grep -v "$_user" /tmp/authorized_keys >> /tmp/authorized_keys.tmp
		mv /tmp/authorized_keys.tmp /tmp/authorized_keys
	done
	# now remove all remaining entries affecting users with current fingerprints
	# order authorized_keys so that keys with matching fingerprints occur first
	cat /tmp/authorized_keys.* /tmp/authorized_keys > /tmp/ak
	cp /tmp/ak "$KEYS"
	rm /tmp/ak /tmp/authorized_keys*
}

# save original authorized_keys at first run
[[ ! -f "$KEYS".orig ]] && cp "$KEYS" "$KEYS".orig
# clean authorized_keys file 
_cleanAuthorizedKeys 2>/dev/null
exit 0
