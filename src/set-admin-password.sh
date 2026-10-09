#!/bin/bash
# Helper script to assist in setting the admin password during first boot
# Usage: docker exec -it container /usr/local/bin/set-admin-password
set -euo pipefail

control=/opt/pzserver/zomboid.control
if [[ ! -p "$control" ]]; then
	printf 'Server control FIFO is not available\n' >&2
	exit 1
fi

IFS= read -rsp 'Admin password: ' password
printf '\n' >&2
if [[ -z "$password" ]]; then
	printf 'Password cannot be empty\n' >&2
	exit 1
fi
printf '%s\n' "$password" > "$control"
sleep 1
printf '%s\n' "$password" > "$control"