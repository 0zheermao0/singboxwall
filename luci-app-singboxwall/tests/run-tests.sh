#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="$ROOT/tests/out"
FIXTURE="$ROOT/tests/fixtures/full.uci"

rm -rf "$OUT"
mkdir -p "$OUT"

check_shell() {
	sh -n "$ROOT/root/etc/init.d/singboxwall"
	sh -n "$ROOT/root/etc/uci-defaults/99-singboxwall"
	sh -n "$ROOT/root/usr/share/singboxwall/app.sh"
	sh -n "$ROOT/root/usr/share/singboxwall/lib/common.sh"
}

check_lua() {
	if command -v luac >/dev/null 2>&1; then
		luac -p "$ROOT/root/usr/share/singboxwall/generate.lua"
		luac -p "$ROOT/root/usr/share/singboxwall/rules.lua"
		luac -p "$ROOT/root/usr/share/singboxwall/subscribe.lua"
		luac -p "$ROOT/root/usr/share/singboxwall/backup.lua"
		luac -p "$ROOT/root/usr/share/singboxwall/status.lua"
	else
		printf '%s\n' 'SKIP luac: Lua compiler not available'
	fi
}

check_ucode() {
	if command -v ucode >/dev/null 2>&1; then
		ucode -c "$ROOT/root/usr/share/rpcd/ucode/singboxwall.uc"
	else
		printf '%s\n' 'SKIP ucode: ucode compiler not available'
	fi
}

check_json() {
	node - <<'NODE' "$ROOT"
const fs = require('fs');
const root = process.argv[2];
for (const p of [
	'root/usr/share/luci/menu.d/luci-app-singboxwall.json',
	'root/usr/share/rpcd/acl.d/luci-app-singboxwall.json',
	'root/usr/share/singboxwall/defaults/rules/private.json',
	'root/usr/share/singboxwall/defaults/rules/cn.json',
	'root/usr/share/singboxwall/defaults/rules/block.json',
	'root/usr/share/singboxwall/schema/node-fields.json',
	'root/usr/share/singboxwall/schema/server-fields.json',
	'root/usr/share/singboxwall/app.json'
]) JSON.parse(fs.readFileSync(root + '/' + p, 'utf8'));
NODE
}

check_js() {
	node - <<'NODE' "$ROOT"
const fs = require('fs');
const root = process.argv[2];
for (const p of [
	'htdocs/luci-static/resources/singboxwall/common.js',
	'htdocs/luci-static/resources/view/singboxwall/overview.js',
	'htdocs/luci-static/resources/view/singboxwall/nodes.js',
	'htdocs/luci-static/resources/view/singboxwall/groups.js',
	'htdocs/luci-static/resources/view/singboxwall/rules.js',
	'htdocs/luci-static/resources/view/singboxwall/access-control.js',
	'htdocs/luci-static/resources/view/singboxwall/dns.js',
	'htdocs/luci-static/resources/view/singboxwall/subscriptions.js',
	'htdocs/luci-static/resources/view/singboxwall/server.js',
	'htdocs/luci-static/resources/view/singboxwall/backup.js',
	'htdocs/luci-static/resources/view/singboxwall/log.js'
]) {
	const src = fs.readFileSync(root + '/' + p, 'utf8');
	const filtered = src.split(/\n/).filter(line => !line.startsWith("'require ")).join('\n');
	new Function('form','rpc','ui','view','sbw','L','E','_', 'document', filtered);
}
NODE
}

run_generator_fixture() {
	if command -v lua >/dev/null 2>&1; then
		LUA=lua
	elif command -v lua5.1 >/dev/null 2>&1; then
		LUA=lua5.1
	else
		printf '%s\n' 'SKIP generator runtime: Lua interpreter not available'
		return 0
	fi
	SINGBOXWALL_UCI_FILE="$FIXTURE" \
	SINGBOXWALL_OUTPUT_DIR="$OUT/generated" \
	SINGBOXWALL_DATA_DIR="$OUT/data" \
	SINGBOXWALL_ASSUME_VERSION='1.14.0' \
		"$LUA" "$ROOT/root/usr/share/singboxwall/generate.lua"
	node - <<'NODE' "$OUT/generated"
const fs = require('fs');
const out = process.argv[2];
const client = JSON.parse(fs.readFileSync(out + '/client.json', 'utf8'));
const server = JSON.parse(fs.readFileSync(out + '/server.json', 'utf8'));
function assert(cond, msg) { if (!cond) throw new Error(msg); }
assert(client.inbounds.some(i => i.type === 'tun' && i.auto_redirect === true), 'missing tun auto_redirect');
assert(client.outbounds.some(o => o.tag === 'proxy' && o.type === 'selector'), 'missing proxy selector');
assert(client.outbounds.some(o => o.tag === 'auto' && o.type === 'urltest'), 'missing urltest group');
assert(client.route.rule_set.length >= 3, 'missing rule sets');
assert(client.route.rules.some(r => r.source_mac_address), 'missing 1.14 MAC ACL');
assert(client.experimental.cache_file.store_dns === true, 'missing 1.14 store_dns gate');
assert(server.inbounds.some(i => i.type === 'shadowsocks'), 'missing server shadowsocks');
NODE
	if command -v sing-box >/dev/null 2>&1; then
		sing-box check -c "$OUT/generated/client.json"
		sing-box check -c "$OUT/generated/server.json"
	else
		printf '%s\n' 'SKIP sing-box check: sing-box binary not available'
	fi
}

check_shell
check_lua
check_ucode
check_json
check_js
run_generator_fixture
node "$ROOT/tests/generate_test.js"
printf '%s\n' 'OK'
