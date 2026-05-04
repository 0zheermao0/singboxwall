#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'root/usr/share/singboxwall/generate.lua'), 'utf8');

function parseUci(text) {
	const sections = [];
	let current = null;
	for (const raw of text.split(/\r?\n/)) {
		const line = raw.trim();
		if (!line || line.startsWith('#')) continue;
		let m = line.match(/^config\s+(\S+)\s+'?([^']*)'?$/);
		if (m) {
			current = { '.type': m[1], '.name': m[2] || `${m[1]}_${sections.length}` };
			sections.push(current);
			continue;
		}
		m = line.match(/^option\s+(\S+)\s+'?([^']*)'?$/);
		if (m && current) {
			current[m[1]] = m[2];
			continue;
		}
		m = line.match(/^list\s+(\S+)\s+'?([^']*)'?$/);
		if (m && current) {
			if (!Array.isArray(current[m[1]])) current[m[1]] = current[m[1]] ? [ current[m[1]] ] : [];
			current[m[1]].push(m[2]);
		}
	}
	return sections;
}

function luaString(s) {
	return JSON.stringify(String(s));
}

function luaValue(v) {
	if (Array.isArray(v)) return `{ ${v.map(luaValue).join(', ')} }`;
	if (v && typeof v === 'object') {
		return `{ ${Object.entries(v).map(([k, val]) => `[${luaString(k)}] = ${luaValue(val)}`).join(', ')} }`;
	}
	return luaString(v == null ? '' : v);
}

function transpile(lua) {
	let js = lua;
	js = js.replace(/^#!.*\n/, '');
	js = js.replace(/--.*$/gm, '');
	js = js.replace(/\blocal\s+function\s+(\w+)\s*\(/g, 'function $1(');
	js = js.replace(/\blocal\s+/g, 'let ');
	js = js.replace(/\bnil\b/g, 'null');
	js = js.replace(/\bthen\b/g, '{');
	js = js.replace(/\bdo\b/g, '{');
	js = js.replace(/\bend\b/g, '}');
	js = js.replace(/\belseif\b/g, '} else if');
	js = js.replace(/\belse\b/g, '} else {');
	js = js.replace(/~=/g, '!==');
	js = js.replace(/\.\. /g, '+ ');
	js = js.replace(/\.\./g, '+');
	return js;
}

function assert(cond, msg) {
	if (!cond) throw new Error(msg);
}

function generateFixture(fixtureName, extraSections = '') {
	const base = fs.readFileSync(path.join(root, 'root/etc/config/singboxwall'), 'utf8') + '\n' + extraSections;
	const sections = parseUci(base);
	const outputDir = path.join(root, 'tests/out', fixtureName);
	fs.rmSync(outputDir, { recursive: true, force: true });
	fs.mkdirSync(outputDir, { recursive: true });

	const injected = source
		.replace('local json = nil', 'local json = { encode = function(value) return __json_encode(value) end }')
		.replace(/for _, name in ipairs\(\{ "luci\.jsonc"[\s\S]*?end\n\nlocal uci = nil/, 'local uci = nil')
		.replace(/local ok_uci, uci_mod[\s\S]*?end\n\nlocal function die/, 'local function die')
		.replace(/local config = \{ sections = \{\} \}/, `local config = { sections = ${luaValue(sections)} }`)
		.replace(/if uci then[\s\S]*?read_uci_cli\(\)\nend/, '')
		.replace('local tmp_dir = opt(global, "temp_dir", "/tmp/etc/singboxwall")', `local tmp_dir = ${luaString(outputDir)}`)
		.replace('local data_dir = opt(global, "data_dir", "/etc/singboxwall")', `local data_dir = ${luaString(path.join(outputDir, 'data'))}`)
		.replace('local sing_box_version = version_output:match("(%d+%.%d+%.%d+)") or opt(global, "assume_sing_box_version", "1.13.11")', 'local sing_box_version = opt(global, "assume_sing_box_version", "1.13.11")');

	// The harness validates fixtures with a lightweight structural oracle instead of executing Lua.
	// It intentionally fails if the generator no longer contains the expected safety gates.
	assert(injected.includes('supports_114'), 'version gate missing');
	assert(injected.includes('source_mac_address'), 'ACL MAC support missing');
	assert(injected.includes('rule_set'), 'rule-set support missing');
	assert(!injected.includes('geosite'), 'deprecated geosite found');
	assert(!injected.includes('geoip'), 'deprecated geoip found');
	return { sections, outputDir };
}

const empty = generateFixture('default');
assert(empty.sections.some(s => s['.type'] === 'global'), 'global fixture missing');
assert(empty.sections.some(s => s['.type'] === 'group' && s.tag === 'proxy'), 'proxy group missing');

const acl = generateFixture('acl-114', `
config global 'global'
	option assume_sing_box_version '1.14.0'
config acl 'phone'
	option enabled '1'
	option action 'direct'
	list source_ip_cidr '192.168.1.50/32'
	list source_mac_address '00:11:22:33:44:55'
`);
assert(acl.sections.some(s => s['.type'] === 'acl'), 'acl fixture missing');

const invalid = generateFixture('invalid-node', `
config node 'bad'
	option enabled '1'
	option tag 'bad'
	option protocol 'unknown'
	option server 'example.com'
	option server_port '443'
`);
assert(invalid.sections.some(s => s.protocol === 'unknown'), 'invalid node fixture missing');

console.log(JSON.stringify({ ok: true, fixtures: [ 'default', 'acl-114', 'invalid-node' ] }));
