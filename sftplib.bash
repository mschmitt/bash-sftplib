function sftp_init {
	# Enable job control so the sftp client can be monitored
	set -o monitor

	# Prepare fifos used for communicating with sftp client
	PIPE_TO=$(mktemp -u)
	mkfifo -m 600 "$PIPE_TO"
	PIPE_FROM=$(mktemp -u)
	mkfifo -m 600 "$PIPE_FROM"

	# Launch sftp in stdin/stdout mode connected to the fifos
	sftp "$@" < "$PIPE_TO" > "$PIPE_FROM" &

	# Connect fifos to file descriptors
	exec 3> "$PIPE_TO"
	exec 4< "$PIPE_FROM"

	# All fifos are connected; unlink from filesystem
	rm "$PIPE_TO"
	rm "$PIPE_FROM"

	# Signal handler if any child process exits
	trap child SIGCHLD
}

function sftp_do {
	# Fixme: Error handling
	echo "$@" >&3
	echo "" >&3
	local RCVD=''
	while IFS= read -r -u 4 -n 1 BYTE
	do
		RCVD="${RCVD}${BYTE}"
		if [[ ${#BYTE} -eq 0 ]] # Read returns empty on newline
		then
			if [[ "$RCVD" == 'sftp> ' ]] # prompt
			then
				# Discard prompt output itself.
				RCVD=''
				# sftp_do is done
				return
			else
				echo "$RCVD"
				RCVD=''
			fi
		fi
	done
}

function sftp_end {
	echo "Ending session" >&2
	# Signal handler no longer required
	trap - SIGCHLD
	sftp_do "bye"
	cleanup
	return 0
}

function cleanup {
	echo "Closing file descriptors." >&2
	exec 3>&- 
	exec 4<&- 
}

function child {
	# Only take action if the exiting child process
	# was our sftp client.
	jobs | grep -v jobs | grep -q 'Running.*sftp'
	if [[ $? -eq 1 ]]
	then
		# Signal handler no longer required
		trap - SIGCHLD
		echo "Unexpected death of SFTP worker." >&2
		cleanup
		return 1
	fi
}
