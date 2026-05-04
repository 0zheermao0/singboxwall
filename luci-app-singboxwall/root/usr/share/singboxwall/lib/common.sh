#!/bin/sh

SINGBOXWALL_NAME='singboxwall'
SINGBOXWALL_UCI='singboxwall'
SINGBOXWALL_RUN_DIR='/var/run/singboxwall'
SINGBOXWALL_TMP_DIR='/tmp/etc/singboxwall'
SINGBOXWALL_DATA_DIR='/etc/singboxwall'
SINGBOXWALL_RESOURCE_DIR='/usr/share/singboxwall'
SINGBOXWALL_LOG='/var/log/singboxwall.log'
SINGBOXWALL_LOCK='/var/lock/singboxwall.lock'

sbw_log() {
	local level msg
	level="$1"
	shift
	msg="$*"
	logger -t "$SINGBOXWALL_NAME" "[$level] $msg"
	mkdir -p "$(dirname "$SINGBOXWALL_LOG")" 2>/dev/null || true
	printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >>"$SINGBOXWALL_LOG" 2>/dev/null || true
}

sbw_die() {
	sbw_log error "$*"
	printf '%s\n' "$*" >&2
	exit 1
}

sbw_uci_get() {
	local section option default value
	section="$1"
	option="$2"
	default="$3"
	value="$(uci -q get "$SINGBOXWALL_UCI.$section.$option" 2>/dev/null || true)"
	if [ -n "$value" ]; then
		printf '%s\n' "$value"
	else
		printf '%s\n' "$default"
	fi
}

sbw_bool() {
	case "$1" in
		1|on|true|yes|enabled) return 0 ;;
		*) return 1 ;;
	esac
}

sbw_load_paths() {
	SINGBOXWALL_RUN_DIR="$(sbw_uci_get global work_dir "$SINGBOXWALL_RUN_DIR")"
	SINGBOXWALL_TMP_DIR="$(sbw_uci_get global temp_dir "$SINGBOXWALL_TMP_DIR")"
	SINGBOXWALL_DATA_DIR="$(sbw_uci_get global data_dir "$SINGBOXWALL_DATA_DIR")"
	SINGBOXWALL_RESOURCE_DIR="$(sbw_uci_get global resource_dir "$SINGBOXWALL_RESOURCE_DIR")"
	SINGBOXWALL_LOCK="/var/lock/singboxwall.lock"
}

sbw_singbox_bin() {
	sbw_uci_get global sing_box_bin '/usr/bin/sing-box'
}

sbw_prepare_dirs() {
	sbw_load_paths
	mkdir -p "$SINGBOXWALL_RUN_DIR" "$SINGBOXWALL_TMP_DIR" "$SINGBOXWALL_DATA_DIR" \
		"$SINGBOXWALL_DATA_DIR/rules" "$SINGBOXWALL_DATA_DIR/subscriptions" "$SINGBOXWALL_DATA_DIR/backups" || return 1
	chmod 0700 "$SINGBOXWALL_DATA_DIR" "$SINGBOXWALL_DATA_DIR/backups" 2>/dev/null || true
	chmod 0755 "$SINGBOXWALL_RUN_DIR" "$SINGBOXWALL_TMP_DIR" "$SINGBOXWALL_DATA_DIR/rules" "$SINGBOXWALL_DATA_DIR/subscriptions" 2>/dev/null || true
}

sbw_with_lock() {
	local cmd lockdir wait
	cmd="$1"
	shift
	wait=0
	lockdir="${SINGBOXWALL_LOCK}.d"
	mkdir -p /var/lock
	while ! mkdir "$lockdir" 2>/dev/null; do
		wait=$((wait + 1))
		[ "$wait" -le 30 ] || return 1
		sleep 1
	done
	trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT INT TERM
	"$cmd" "$@"
	local rc=$?
	rmdir "$lockdir" 2>/dev/null || true
	trap - EXIT INT TERM
	return "$rc"
}

sbw_atomic_write() {
	local dest tmp
	dest="$1"
	tmp="$dest.$$"
	cat >"$tmp" || return 1
	chmod 0600 "$tmp" 2>/dev/null || true
	mv "$tmp" "$dest"
}

sbw_version_number() {
	local bin out version
	bin="$1"
	out="$("$bin" version 2>/dev/null | sed -n '1p' || true)"
	version="$(printf '%s\n' "$out" | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
	printf '%s\n' "${version:-0.0.0}"
}

sbw_version_ge() {
	local actual required actual_num required_num
	actual="$1"
	required="$2"
	actual_num="$(printf '%s\n' "$actual" | awk -F. '{ printf "%d%03d%03d", $1, $2, $3 }')"
	required_num="$(printf '%s\n' "$required" | awk -F. '{ printf "%d%03d%03d", $1, $2, $3 }')"
	[ "$actual_num" -ge "$required_num" ]
}

sbw_supports_114() {
	local bin version
	bin="$(sbw_singbox_bin)"
	version="$(sbw_version_number "$bin")"
	sbw_version_ge "$version" '1.14.0'
}

sbw_json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}
