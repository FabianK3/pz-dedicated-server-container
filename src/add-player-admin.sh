#!/bin/bash
# Helper script to assist in making a player admin
# Usage: docker exec -it container /usr/local/bin/add-player-admin
set -euo pipefail

control=/opt/pzserver/zomboid.control
if [[ ! -p "$control" ]]; then
	printf 'Server control FIFO is not available\n' >&2
	exit 1
fi

IFS= read -rp 'Player name: ' player
printf '\n' >&2
if [[ -z "$player" ]]; then
	printf 'Player name cannot be empty\n' >&2
	exit 1
fi
if [[ "$player" == *\"* ]]; then
	printf 'Player name cannot contain a double quote\n' >&2
	exit 1
fi
printf 'setaccesslevel "%s" "admin"\n' "$player" > "$control"