#!/usr/bin/env bash

PATHSTORE=~/.server-store
SSH="ssh"
SCP="scp"
set -o pipefail

# Manage plateform specific
PLATEFORM=$(uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]')
case $PLATEFORM in
	darwin)
		GETOPT="/usr/local/opt/gnu-getopt/bin/getopt" # Need brew install gnu-getopt
		;;
	*)
		GETOPT="getopt"
		;;
esac

yesno() {
	[[ -t 0 ]] || return 0
	local response
	read -r -p "$1 [y/N] " response
	[[ $response == [yY] ]] || exit 1
}
die() {
	echo "$@" >&2
	exit 1
}
check_sneaky_paths() {
	local path
	for path in "$@"; do
		[[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: Sneaky path."
	done
}

cmd_version() {
	cat <<-_EOF
	=======================================
	= Server-Store: Simple server manager =
	=                                     =
	=                  v1	              =
	=======================================
	_EOF
}

cmd_usage() {
	cmd_version
	echo
	cat <<-_EOF
	Usage:
	    $PROGRAM init
	        Initialize new server store.
	    $PROGRAM [ls] [subfolder] [file_to_transfers]
	        List or connect to server. Ex. $PROGRAM folder/server or $PROGRAM folder/server file_to_transfert
	    $PROGRAM find servers...
	    	List server that match servers.
	    $PROGRAM insert [-f, --force] server
	        Insert a new server in the store. Ex. « $PROGRAM insert perso/my-server »
	    $PROGRAM edit server
	        Insert or edit a server with ${EDITOR:-vi}.
	    $PROGRAM rm [--recursive,-r] [--force,-f] server
	        Remove existing server or directory, optionally forcefully.
	    $PROGRAM help
	        Show this text.
	    $PROGRAM version
	        Show version information.

	_EOF
}

cmd_init() {
	if [[ -d $PATHSTORE ]]; then
		die "Server store already initialized."
	else
		mkdir $PATHSTORE
		echo "Server store initialized in $PATHSTORE"
	fi
}

cmd_show_connect() {
	local path="$1"
	local serverfile="$PATHSTORE/$path"
	check_sneaky_paths "$path"

	if [[ -f $serverfile ]]; then
		if [[ $2 != "" ]]; then
			$SCP $(pwd)/$2 $(cat $serverfile):~
		else
			$SSH $(cat $serverfile)
		fi
	elif [[ -d $PATHSTORE/$path ]]; then
		if [[ -z $path ]]; then
			echo "Server Store"
		else
			echo "${path%\/}"
		fi
		tree -C -l --noreport "$PATHSTORE/$path" | tail -n +2
	else
		die "Incorrect server path"
	fi
}

cmd_find() {
	[[ -z "$@" ]] && die "Usage: $PROGRAM $COMMAND servers-names..."
	IFS="," eval 'echo "Search Terms: $*"'
	local terms="*$(printf '%s*|*' "$@")"
	tree -C -l --noreport -P "${terms%|*}" --prune --matchdirs --ignore-case "$PATHSTORE" | tail -n +2
}

cmd_insert(){
	local opts force=0
	opts="$($GETOPT -o f -l force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done

	[[ $err -ne 0 || $# -lt 1 ]] && die "Usage: $PROGRAM $COMMAND [--force,-f] server-name"
	local path="${1%/}"
	local serverfile="$PATHSTORE/$path"
	check_sneaky_paths "$path"

	[[ $force -eq 0 && -e $serverfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	mkdir -p -v "$PATHSTORE/$(dirname "$path")"

	local server
	read -r -p "Enter « login@server » for $path: " -e server
	echo "$server" > $serverfile
}

cmd_mv(){
	[[ $# -lt 2 ]] && die "Usage: $PROGRAM old-path new-path"
	[[ ! -e $PATHSTORE/$1 ]] && die "You cant't mv a non existent server."
	[[ -e $PATHSTORE/$2 ]] && yesno "An entry already exists for $path. Overwrite it?"

	mv $PATHSTORE/$1 $PATHSTORE/$2
}

cmd_edit(){
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND server-name"
	local path="${1%/}"
	mkdir -p -v "$PATHSTORE/$(dirname "$path")"
	local serverfile="$PATHSTORE/$path"
	check_sneaky_paths "$path"

	${EDITOR:-vim} $serverfile
}

cmd_delete(){
	local opts recursive="" force=0
	opts="$($GETOPT -o rf -l recursive,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
		-r|--recursive) recursive="-r"; shift ;;
		-f|--force) force=1; shift ;;
		--) shift; break ;;
	esac done
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--recursive,-r] [--force,-f] server-name"
	local path="$1"
	check_sneaky_paths "$path"

	local serverdir="$PATHSTORE/${path%/}"
	local serverfile="$PATHSTORE/$path"
	[[ -f $serverfile && -d $serverdir && $path == */ || ! -f $serverfile ]] && serverfile="$serverdir"
	[[ -e $serverfile ]] || die "Error: $path is not in the server store."

	[[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

	rm $recursive -f -v "$serverfile"
	rmdir -p "${serverfile%/*}" 2>/dev/null
}

PROGRAM="${0##*/}"
COMMAND="$1"

case "$1" in
	init) shift;				cmd_init "$@" ;;
	help|--help) shift;			cmd_usage "$@" ;;
	version|--version) shift;	cmd_version "$@" ;;
	connect|ls|list) shift;		cmd_show_connect "$@" ;;
	find|search) shift;			cmd_find "$@" ;;
	insert|add) shift;			cmd_insert "$@" ;;
	mv|move) shift;					cmd_mv "$@" ;;
	edit) shift;				cmd_edit "$@" ;;
	delete|rm|remove) shift;	cmd_delete "$@" ;;
	*) COMMAND="connect";		cmd_show_connect "$@" ;;
esac
exit 0
