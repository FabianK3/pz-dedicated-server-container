#!/bin/bash
# The Project Zomboid server needs an interactive console and does not natively
# support running in the background. This entrypoint uses a FIFO as its stdin
# so it can run in the background while still receiving save and quit commands
# for graceful container shutdown.
set -eu

if [[ -n ${AUTO_RESTART_HOURS:-} && ! ${AUTO_RESTART_HOURS} =~ ^[1-9][0-9]*$ ]]; then
	printf 'AUTO_RESTART_HOURS must be a positive whole number of hours\n' >&2
	exit 1
fi

# Set a fixed initial heap and a configurable maximum heap.
max_ram_alloc_gb=${MAX_RAM_ALLOC_GB:-8}
case "$max_ram_alloc_gb" in
	*[!0-9]*)
		max_ram_alloc_gb=2
		;;
esac
if [ "$max_ram_alloc_gb" -lt 2 ]; then
	max_ram_alloc_gb=2
fi
ram_config=$(mktemp ./ProjectZomboid64.json.XXXXXX)
if jq --arg ram "-Xmx${max_ram_alloc_gb}g" '
	if (.vmArgs | type == "array") and
		([.vmArgs[] | select(type == "string" and test("^-Xmx[0-9]+[gGmMkK]$"))] | length == 1) then
		.vmArgs |= (map(select(type != "string" or (test("^-X[mM][sS][0-9]+[gGmMkK]$") | not))) |
			map(if type == "string" and test("^-Xmx[0-9]+[gGmMkK]$") then $ram else . end) + ["-Xms2g"])
	else error("ProjectZomboid64.json must contain one -Xmx heap setting in vmArgs") end
' ProjectZomboid64.json > "$ram_config"; then
	chmod --reference=ProjectZomboid64.json "$ram_config"
	mv "$ram_config" ProjectZomboid64.json
else
	rm -f "$ram_config"
	exit 1
fi

# Create the console input and output pipes.
control=/opt/pzserver/zomboid.control
if [ -e "$control" ]; then
	[ -p "$control" ] || exit 1
	rm "$control"
fi
mkfifo -m 660 "$control"
output=/opt/pzserver/zomboid.output
if [ -e "$output" ]; then
	[ -p "$output" ] || exit 1
	rm "$output"
fi
mkfifo -m 600 "$output"
# Keep a writer open so the server does not see EOF between commands.
exec 3<> "$control"

write_pz_command() {
	printf '%s\n' "$1" >&3
}

stop_server() {
	trap 'action=exit' TERM INT
	trap '' USR1
	kill "$workshop_update_pid" 2>/dev/null || :
	kill "$auto_restart_pid" 2>/dev/null || :
	write_pz_command "save"
	sleep 30 # Give the server time to save gracefully before quitting.
	write_pz_command "quit"
}

check_mod_updates() {
	[[ ${AUTO_UPDATE_MODS:-false} == true ]] || return 0
	while sleep 1800; do
		write_pz_command "checkModsNeedUpdate"
	done
}

warn_and_restart() {
	local reason=$1
	write_pz_command "servermsg \"Server restart in 5 minutes for $reason!\""
	sleep 240
	write_pz_command "servermsg \"Server restart in 1 minute for $reason!\""
	sleep 60
	kill -USR1 "$$"
}

auto_restart() {
	[[ -n ${AUTO_RESTART_HOURS:-} ]] || return 0
	sleep "$((AUTO_RESTART_HOURS * 3600 - 300))"
	warn_and_restart 'scheduled restart'
}

monitor_output() {
	local line update_pending=0
	while IFS= read -r line; do
		if [[ ${AUTO_UPDATE_MODS:-false} == true && $update_pending -eq 0 && $line == *'CheckModsNeedUpdate: Mods need update.'* ]]; then
			update_pending=1
			kill "$workshop_update_pid" 2>/dev/null || :
			kill "$auto_restart_pid" 2>/dev/null || :
			warn_and_restart 'workshop update' &
		fi
	done
}

while :; do
	action=none
	trap 'action=exit; stop_server' TERM INT
	trap 'action=restart; stop_server' USR1
	./start-server.sh -servername server <&3 > "$output" 2>&1 &
	server_pid=$!
	check_mod_updates &
	workshop_update_pid=$!
	auto_restart &
	auto_restart_pid=$!

	# tee forwards the original output to Docker logs and a copy to the monitor.
	tee >(monitor_output) < "$output" &
	tee_pid=$!

	status=0
	wait "$server_pid" || status=$?
	if [[ $action != none ]]; then
		status=0
		wait "$server_pid" || status=$?
	fi
	kill "$workshop_update_pid" 2>/dev/null || :
	kill "$auto_restart_pid" 2>/dev/null || :
	wait "$tee_pid" || :
	[[ $action == restart ]] || exit "$status"
done
