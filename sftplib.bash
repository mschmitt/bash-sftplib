function sftp_init {
	set -o monitor

	PIPE_DIR=$(mktemp -d)
	chmod 700 "$PIPE_DIR"

	PIPE_TO="$PIPE_DIR/pipe_to_ssh"
	mkfifo "$PIPE_TO"
	chmod 600 "$PIPE_TO"

	PIPE_FROM="$PIPE_DIR/pipe_from_ssh"
	mkfifo "$PIPE_FROM"
	chmod 600 "$PIPE_FROM"

	sftp "$@" < "$PIPE_TO" > "$PIPE_FROM" &

	exec 3> "$PIPE_TO"
	exec 4< "$PIPE_FROM"

	trap child SIGCHLD
}

function sftp_do {
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
				RCVD=''
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
	trap - SIGCHLD
	sftp_do "bye"
	cleanup
}

function cleanup {
	echo "Cleaning up:" >&2
	echo "1) Closing file descriptors." >&2
	exec 3>&- 
	exec 4<&- 
	echo "2) Deleting fifos." >&2
	rm "$PIPE_TO"
	rm "$PIPE_FROM"
	echo "3) Deleting fifo directory." >&2
	rmdir "$PIPE_DIR"
	echo "Done." >&2
}

function child {
	jobs | grep -v jobs | grep -q 'Running.*sftp'
	if [[ $? -eq 1 ]]
	then
		trap - SIGCHLD
		echo "Unexpected death of SFTP worker." >&2
		cleanup
	fi
}
