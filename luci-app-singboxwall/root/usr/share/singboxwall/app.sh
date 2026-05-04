#!/bin/sh

set -u

SCRIPT_DIR='/usr/share/singboxwall'
COMMON="$SCRIPT_DIR/lib/common.sh"
GENERATOR="$SCRIPT_DIR/generate.lua"
RULES="$SCRIPT_DIR/rules.lua"
SUBSCRIBE="$SCRIPT_DIR/subscribe.lua"
BACKUP="$SCRIPT_DIR/backup.lua"
STATUS="$SCRIPT_DIR/status.lua"

[ -r "$COMMON" ] || { echo "missing common library: $COMMON" >&2; exit 1; }
. "$COMMON"

sbw_lua() {
	if command -v lua >/dev/null 2>&1; then
		lua "$@"
	elif command -v lua5.1 >/dev/null 2>&1; then
		lua5.1 "$@"
	else
		sbw_die 'Lua interpreter not found'
	fi
}

sbw_generate() {
	sbw_prepare_dirs || sbw_die 'failed to prepare directories'
	sbw_lua "$GENERATOR"
}

sbw_check() {
	local bin client server
	bin="$(sbw_singbox_bin)"
	[ -x "$bin" ] || sbw_die "sing-box binary not executable: $bin"
	sbw_generate || return 1
	sbw_load_paths
	client="$SINGBOXWALL_TMP_DIR/client.json"
	server="$SINGBOXWALL_TMP_DIR/server.json"
	"$bin" check -c "$client" || return 1
	if [ -s "$server" ]; then
		"$bin" check -c "$server" || return 1
	fi
}

sbw_restart_service() {
	if [ -x /etc/init.d/singboxwall ]; then
		/etc/init.d/singboxwall restart
	else
		sbw_die 'init script not found'
	fi
}

sbw_status() {
	sbw_lua "$STATUS" summary
}

sbw_tail_log() {
	sbw_lua "$STATUS" log "${1:-80}"
}

sbw_update_rules() {
	sbw_lua "$RULES" update
}

sbw_update_subscriptions() {
	sbw_lua "$SUBSCRIBE" update
}

sbw_backup_create() {
	sbw_lua "$BACKUP" create "${1:-}"
}

sbw_backup_restore() {
	[ $# -ge 1 ] || sbw_die 'restore requires a backup path'
	sbw_lua "$BACKUP" restore "$1"
}

usage() {
	cat <<'USAGE'
Usage: singboxwall <command> [args]

Commands:
  start                 Generate and start through init script
  stop                  Stop through init script
  restart              Regenerate, check, and restart through init script
  reload               Same as restart
  generate             Generate client/server JSON
  check                Generate and run sing-box check on generated JSON
  status               Print JSON status summary
  tail-log [lines]     Print recent log lines
  update-rules         Update remote rule-set cache/compiled files
  update-subscriptions Update configured subscriptions
  backup [path]        Create a backup archive
  restore <path>       Validate and restore a backup archive
USAGE
}

cmd="${1:-}"
[ $# -gt 0 ] && shift || true

case "$cmd" in
	start)
		/etc/init.d/singboxwall start
		;;
	stop)
		/etc/init.d/singboxwall stop
		;;
	restart|reload)
		sbw_check && sbw_restart_service
		;;
	generate)
		sbw_with_lock sbw_generate
		;;
	check)
		sbw_with_lock sbw_check
		;;
	status)
		sbw_status
		;;
	tail-log)
		sbw_tail_log "$@"
		;;
	update-rules|rule-update)
		sbw_with_lock sbw_update_rules
		;;
	update-subscriptions)
		sbw_with_lock sbw_update_subscriptions
		;;
	backup)
		sbw_with_lock sbw_backup_create "$@"
		;;
	restore)
		sbw_with_lock sbw_backup_restore "$@"
		;;
	-h|--help|help|'')
		usage
		;;
	*)
		usage >&2
		exit 2
		;;
esac
