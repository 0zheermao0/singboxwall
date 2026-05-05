#!/usr/bin/env lua

local VERSION = "0.1.0"

local json = nil
for _, name in ipairs({ "luci.jsonc", "luci.json", "cjson", "dkjson" }) do
	local ok, mod = pcall(require, name)
	if ok and mod then
		json = mod
		break
	end
end

local uci = nil
local ok_uci, uci_mod = pcall(require, "uci")
if ok_uci and uci_mod and uci_mod.cursor then
	uci = uci_mod.cursor()
end

local function die(msg)
	io.stderr:write("singboxwall generate: " .. msg .. "\n")
	os.exit(1)
end

local function encode_json(value)
	if json then
		if json.stringify then
			return json.stringify(value, true)
		elseif json.encode then
			local ok, out = pcall(json.encode, value, { indent = true })
			if ok and out then return out end
			return json.encode(value)
		end
	end
	die("no JSON encoder module found")
end

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run_capture(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return nil end
	local out = p:read("*a")
	p:close()
	return out
end

local function file_exists(path)
	local f = io.open(path, "r")
	if f then f:close(); return true end
	return false
end

local function mkdir_p(path)
	if not path or path == "" or path == "/" then return end
	os.execute("mkdir -p " .. shell_quote(path))
end

local function dirname(path)
	return (path:gsub("/[^/]+$", ""))
end

local function write_file(path, data)
	mkdir_p(dirname(path))
	local tmp = path .. "." .. tostring(os.time()) .. ".tmp"
	local f, err = io.open(tmp, "w")
	if not f then die("failed to write " .. path .. ": " .. tostring(err)) end
	f:write(data)
	f:write("\n")
	f:close()
	os.rename(tmp, path)
end

local function trim(s)
	return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function split_words(s)
	local out = {}
	if type(s) == "table" then
		for _, v in ipairs(s) do
			if trim(v) ~= "" then out[#out + 1] = trim(v) end
		end
		return out
	end
	for token in tostring(s or ""):gmatch("%S+") do
		out[#out + 1] = token
	end
	return out
end

local function uniq(list)
	local out, seen = {}, {}
	for _, v in ipairs(list or {}) do
		if v ~= nil and tostring(v) ~= "" and not seen[tostring(v)] then
			seen[tostring(v)] = true
			out[#out + 1] = v
		end
	end
	return out
end

local function truthy(v)
	v = tostring(v or ""):lower()
	return v == "1" or v == "true" or v == "yes" or v == "on" or v == "enabled"
end

local function toint(v, default)
	local n = tonumber(v)
	if not n then return default end
	return math.floor(n)
end

local function valid_port(v)
	local n = toint(v, nil)
	return n and n >= 1 and n <= 65535
end

local function section_name(section)
	return section[".name"] or section["name"] or section["tag"] or "unnamed"
end

local config = { sections = {} }

local function add_section(s)
	config.sections[#config.sections + 1] = s
end

local function read_uci_cli()
	local out = run_capture("uci -q show singboxwall") or ""
	for line in out:gmatch("[^\n]+") do
		local key, value = line:match("^singboxwall%.([^=]+)=(.*)$")
		if key and value then
			value = value:gsub("^'", ""):gsub("'$", ""):gsub("'\\''", "'")
			local name = key:match("^([^%.]+)$")
			if name then
				add_section({ [".name"] = name, [".type"] = value })
			else
				local sec, optname = key:match("^([^%.]+)%.(.+)$")
				if sec and optname then
					local target = nil
					for _, s in ipairs(config.sections) do
						if s[".name"] == sec then target = s; break end
					end
					if not target then
						target = { [".name"] = sec, [".type"] = "unknown" }
						add_section(target)
					end
					if target[optname] ~= nil then
						if type(target[optname]) ~= "table" then target[optname] = { target[optname] } end
						target[optname][#target[optname] + 1] = value
					else
						target[optname] = value
					end
				end
			end
		end
	end
end

local function read_uci_file(path)
	local f = io.open(path, "r")
	if not f then die("cannot open UCI fixture: " .. tostring(path)) end
	local current = nil
	for raw in f:lines() do
		local line = trim(raw:gsub("#.*$", ""))
		if line ~= "" then
			local stype, name = line:match("^config%s+(%S+)%s+'([^']*)'")
			if not stype then stype, name = line:match('^config%s+(%S+)%s+"([^"]*)"') end
			if not stype then stype = line:match("^config%s+(%S+)%s*$") end
			if stype then
				current = { [".type"] = stype, [".name"] = name or (stype .. tostring(#config.sections + 1)) }
				add_section(current)
			else
				local optname, value = line:match("^option%s+(%S+)%s+'(.*)'")
				if not optname then optname, value = line:match('^option%s+(%S+)%s+"(.*)"') end
				if not optname then optname, value = line:match("^option%s+(%S+)%s+(%S+)") end
				if optname and current then
					current[optname] = value or ""
				else
					local listname, listvalue = line:match("^list%s+(%S+)%s+'(.*)'")
					if not listname then listname, listvalue = line:match('^list%s+(%S+)%s+"(.*)"') end
					if not listname then listname, listvalue = line:match("^list%s+(%S+)%s+(%S+)") end
					if listname and current then
						if type(current[listname]) ~= "table" then current[listname] = current[listname] and { current[listname] } or {} end
						current[listname][#current[listname] + 1] = listvalue or ""
					end
				end
			end
		end
	end
	f:close()
end

local fixture_path = os.getenv("SINGBOXWALL_UCI_FILE")
if fixture_path and fixture_path ~= "" then
	read_uci_file(fixture_path)
elseif uci then
	uci:foreach("singboxwall", nil, function(s)
		add_section(s)
	end)
else
	read_uci_cli()
end

local function sections_by_type(t)
	local out = {}
	for _, s in ipairs(config.sections) do
		if s[".type"] == t then out[#out + 1] = s end
	end
	return out
end

local function named_section(name, stype)
	for _, s in ipairs(config.sections) do
		if s[".name"] == name and (not stype or s[".type"] == stype) then return s end
	end
	return {}
end

local global = named_section("global", "global")
local inbound = named_section("main", "inbound")
local dns_uci = named_section("dns", "dns")

local function opt(section, key, default)
	local v = section and section[key]
	if v == nil or v == "" then return default end
	return v
end

local function list_opt(section, key)
	return split_words(section and section[key] or nil)
end

local function version_tuple(v)
	local a, b, c = tostring(v or "0.0.0"):match("(%d+)%.(%d+)%.(%d+)")
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function version_ge(v, req)
	local a, b, c = version_tuple(v)
	local x, y, z = version_tuple(req)
	if a ~= x then return a > x end
	if b ~= y then return b > y end
	return c >= z
end

local sing_box_bin = opt(global, "sing_box_bin", "/usr/bin/sing-box")
local version_output = run_capture(shell_quote(sing_box_bin) .. " version") or ""
local sing_box_version = version_output:match("(%d+%.%d+%.%d+)") or os.getenv("SINGBOXWALL_ASSUME_VERSION") or opt(global, "assume_sing_box_version", "1.13.11")
local supports_113 = version_ge(sing_box_version, "1.13.0")
local supports_1133 = version_ge(sing_box_version, "1.13.3")
local supports_114 = version_ge(sing_box_version, "1.14.0")
local tmp_dir = os.getenv("SINGBOXWALL_OUTPUT_DIR") or opt(global, "temp_dir", "/tmp/etc/singboxwall")
local data_dir = os.getenv("SINGBOXWALL_DATA_DIR") or opt(global, "data_dir", "/etc/singboxwall")
local resource_dir = opt(global, "resource_dir", "/usr/share/singboxwall")
local warnings = {}

local function warn(msg)
	warnings[#warnings + 1] = msg
end

local function tls_from_section(s)
	if not truthy(opt(s, "tls_enabled", opt(s, "tls", "0"))) then return nil end
	local tls = { enabled = true }
	local server_name = opt(s, "server_name", opt(s, "tls_server_name", ""))
	if server_name ~= "" then tls.server_name = server_name end
	if opt(s, "alpn", "") ~= "" then tls.alpn = list_opt(s, "alpn") end
	if opt(s, "insecure", "") ~= "" then tls.insecure = truthy(opt(s, "insecure", "0")) end
	if opt(s, "utls_enabled", "") ~= "" then
		tls.utls = { enabled = truthy(opt(s, "utls_enabled", "0")) }
		if opt(s, "utls_fingerprint", "") ~= "" then tls.utls.fingerprint = opt(s, "utls_fingerprint", "chrome") end
	end
	if opt(s, "reality_enabled", "") ~= "" then
		tls.reality = { enabled = truthy(opt(s, "reality_enabled", "0")) }
		if opt(s, "reality_public_key", "") ~= "" then tls.reality.public_key = opt(s, "reality_public_key", "") end
		if opt(s, "reality_short_id", "") ~= "" then tls.reality.short_id = opt(s, "reality_short_id", "") end
	end
	return tls
end

local function server_tls_from_section(s)
	if not truthy(opt(s, "tls_enabled", opt(s, "tls", "0"))) then return nil end
	local cert = opt(s, "tls_certificate_path", opt(s, "certificate_path", ""))
	local key = opt(s, "tls_key_path", opt(s, "key_path", ""))
	if cert == "" or key == "" then
		warn("server " .. section_name(s) .. " has TLS enabled but certificate/key path is missing; server skipped")
		return nil, "missing_tls"
	end
	local tls = { enabled = true, certificate_path = cert, key_path = key }
	if opt(s, "alpn", "") ~= "" then tls.alpn = list_opt(s, "alpn") end
	return tls
end

local function transport_from_section(s)
	local t = opt(s, "transport", "")
	if t == "" or t == "tcp" then return nil end
	local tr = { type = t }
	if opt(s, "transport_path", "") ~= "" then tr.path = opt(s, "transport_path", "") end
	if opt(s, "transport_host", "") ~= "" then tr.host = opt(s, "transport_host", "") end
	if opt(s, "transport_headers", "") ~= "" then tr.headers = { Host = opt(s, "transport_headers", "") } end
	return tr
end

local function outbound_tag(s)
	local tag = opt(s, "tag", section_name(s))
	if tag == "direct" or tag == "block" or tag == "dns-out" then
		warn("node tag " .. tag .. " is reserved; node skipped")
		return nil
	end
	return tag
end

local function add_required(o, key, value, errs)
	if value == nil or value == "" then errs[#errs + 1] = key else o[key] = value end
end

local function node_to_outbound(s)
	if not truthy(opt(s, "enabled", "1")) then return nil end
	local typ = opt(s, "protocol", opt(s, "type", "")):lower()
	local tag = outbound_tag(s)
	if not tag then return nil end
	local errs = {}
	local o = { type = typ, tag = tag }
	if typ == "shadowsocks" or typ == "ss" then
		o.type = "shadowsocks"
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "method", opt(s, "method", ""), errs)
		add_required(o, "password", opt(s, "password", ""), errs)
	elseif typ == "vmess" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "uuid", opt(s, "uuid", ""), errs)
		if opt(s, "security", "") ~= "" then o.security = opt(s, "security", "") end
		if opt(s, "alter_id", "") ~= "" then o.alter_id = toint(opt(s, "alter_id", "0"), 0) end
	elseif typ == "trojan" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "password", opt(s, "password", ""), errs)
	elseif typ == "vless" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "uuid", opt(s, "uuid", ""), errs)
		if opt(s, "flow", "") ~= "" then o.flow = opt(s, "flow", "") end
	elseif typ == "hysteria2" or typ == "hy2" then
		o.type = "hysteria2"
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "password", opt(s, "password", ""), errs)
		if opt(s, "obfs", "") ~= "" then o.obfs = { type = opt(s, "obfs", "salamander"), password = opt(s, "obfs_password", "") } end
	elseif typ == "tuic" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "uuid", opt(s, "uuid", ""), errs)
		add_required(o, "password", opt(s, "password", ""), errs)
		if opt(s, "congestion_control", "") ~= "" then o.congestion_control = opt(s, "congestion_control", "") end
	elseif typ == "anytls" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "password", opt(s, "password", ""), errs)
	elseif typ == "wireguard" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "")), nil)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		if opt(s, "local_address", "") ~= "" then o.local_address = list_opt(s, "local_address") end
		add_required(o, "private_key", opt(s, "private_key", ""), errs)
		add_required(o, "peer_public_key", opt(s, "peer_public_key", ""), errs)
	elseif typ == "ssh" then
		add_required(o, "server", opt(s, "server", ""), errs)
		local port = toint(opt(s, "server_port", opt(s, "port", "22")), 22)
		if not valid_port(port) then errs[#errs + 1] = "server_port" else o.server_port = port end
		add_required(o, "user", opt(s, "user", ""), errs)
		if opt(s, "password", "") ~= "" then o.password = opt(s, "password", "") end
		if opt(s, "private_key", "") ~= "" then o.private_key = opt(s, "private_key", "") end
		if opt(s, "private_key_path", "") ~= "" then o.private_key_path = opt(s, "private_key_path", "") end
	else
		warn("unsupported node protocol for " .. section_name(s) .. ": " .. tostring(typ))
		return nil
	end
	if #errs > 0 then
		warn("node " .. section_name(s) .. " skipped; missing/invalid fields: " .. table.concat(errs, ","))
		return nil
	end
	if opt(s, "network", "") ~= "" and (o.type == "shadowsocks" or o.type == "vmess" or o.type == "trojan" or o.type == "vless") then o.network = opt(s, "network", "") end
	local tls = tls_from_section(s)
	if tls then o.tls = tls end
	local transport = transport_from_section(s)
	if transport then o.transport = transport end
	if opt(s, "multiplex_enabled", "") ~= "" then o.multiplex = { enabled = truthy(opt(s, "multiplex_enabled", "0")) } end
	return o
end

local node_tags = {}
local outbounds = {
	{ type = "direct", tag = "direct" },
	{ type = "block", tag = "block" }
}
if not supports_113 then
	outbounds[#outbounds + 1] = { type = "dns", tag = "dns-out" }
end

for _, s in ipairs(sections_by_type("node")) do
	local o = node_to_outbound(s)
	if o then
		outbounds[#outbounds + 1] = o
		node_tags[#node_tags + 1] = o.tag
	end
end

local function known_outbound_tags()
	local set = {}
	for _, o in ipairs(outbounds) do set[o.tag] = true end
	return set
end

local function group_to_outbound(s)
	if not truthy(opt(s, "enabled", "1")) then return nil end
	local tag = opt(s, "tag", section_name(s))
	if tag == "direct" or tag == "block" or tag == "dns-out" then
		warn("group tag " .. tag .. " is reserved; group skipped")
		return nil
	end
	local kind = opt(s, "group_type", opt(s, "type", "selector"))
	if kind ~= "selector" and kind ~= "urltest" then
		warn("group " .. section_name(s) .. " has unsupported type " .. kind .. "; group skipped")
		return nil
	end
	local known = known_outbound_tags()
	local members = {}
	for _, tagname in ipairs(list_opt(s, "outbound")) do
		if known[tagname] then members[#members + 1] = tagname else warn("group " .. tag .. " references unknown outbound " .. tagname) end
	end
	if #members == 0 then members = (#node_tags > 0) and node_tags or { "direct" } end
	local o = { type = kind, tag = tag, outbounds = uniq(members) }
	if kind == "selector" then
		local default = opt(s, "default", o.outbounds[1])
		if known[default] then o.default = default else o.default = o.outbounds[1] end
	else
		if opt(s, "url", "") ~= "" then o.url = opt(s, "url", "") end
		if opt(s, "interval", "") ~= "" then o.interval = opt(s, "interval", "") end
		if opt(s, "tolerance", "") ~= "" then o.tolerance = toint(opt(s, "tolerance", "50"), 50) end
		if opt(s, "idle_timeout", "") ~= "" then o.idle_timeout = opt(s, "idle_timeout", "") end
	end
	if opt(s, "interrupt_exist_connections", "") ~= "" then o.interrupt_exist_connections = truthy(opt(s, "interrupt_exist_connections", "0")) end
	return o
end

for _, s in ipairs(sections_by_type("group")) do
	local o = group_to_outbound(s)
	if o then outbounds[#outbounds + 1] = o end
end

local function final_group()
	local tag = opt(global, "default_group", "proxy")
	for _, o in ipairs(outbounds) do
		if o.tag == tag then return tag end
	end
	if #node_tags > 0 then return node_tags[1] end
	return "direct"
end

local function dns_server_from_uri(tag, uri, port, detour)
	uri = trim(uri)
	if uri:match("^https://") then
		local host, path = uri:match("^https://([^/]+)(/.*)$")
		host = host or uri:gsub("^https://", "")
		local h, p = host:match("^%[?([^%]]+)%]?:([0-9]+)$")
		return { type = "https", tag = tag, server = h or host, server_port = tonumber(p) or 443, path = path or "/dns-query", detour = detour ~= "" and detour or nil }
	elseif uri:match("^tls://") then
		local host = uri:gsub("^tls://", "")
		local h, p = host:match("^%[?([^%]]+)%]?:([0-9]+)$")
		return { type = "tls", tag = tag, server = h or host, server_port = tonumber(p) or 853, detour = detour ~= "" and detour or nil }
	else
		local h, p = uri:match("^%[?([^%]]+)%]?:([0-9]+)$")
		return { type = "udp", tag = tag, server = h or uri, server_port = tonumber(p) or toint(port, 53) or 53, detour = detour ~= "" and detour or nil }
	end
end

local inbounds = {}
if truthy(opt(inbound, "mixed_enabled", "1")) then
	local port = toint(opt(inbound, "mixed_port", "1080"), 1080)
	if not valid_port(port) then die("invalid mixed inbound port: " .. tostring(port)) end
	inbounds[#inbounds + 1] = {
		type = "mixed",
		tag = "mixed-in",
		listen = opt(inbound, "mixed_listen", "127.0.0.1"),
		listen_port = port,
		set_system_proxy = truthy(opt(inbound, "mixed_set_system_proxy", "0"))
	}
end
if truthy(opt(inbound, "tun_enabled", "1")) then
	local mtu = toint(opt(inbound, "tun_mtu", "9000"), 9000)
	local tun = {
		type = "tun",
		tag = "tun-in",
		interface_name = opt(inbound, "tun_interface_name", "singboxwall0"),
		address = list_opt(inbound, "tun_address"),
		mtu = mtu,
		auto_route = truthy(opt(inbound, "tun_auto_route", "1")),
		auto_redirect = truthy(opt(inbound, "tun_auto_redirect", "1")),
		stack = opt(inbound, "tun_stack", "system")
	}
	if supports_1133 then
		tun.strict_route = truthy(opt(inbound, "tun_strict_route", "1"))
	elseif truthy(opt(inbound, "tun_strict_route", "1")) then
		warn("TUN strict_route requires sing-box >= 1.13.3; omitted for " .. sing_box_version)
	end
	if #tun.address == 0 then tun.address = { "172.19.0.1/30" } end
	inbounds[#inbounds + 1] = tun
end
if truthy(opt(inbound, "dns_enabled", "1")) then
	local port = toint(opt(inbound, "dns_port", "5353"), 5353)
	if not valid_port(port) then die("invalid DNS inbound port: " .. tostring(port)) end
	inbounds[#inbounds + 1] = {
		type = "direct",
		tag = "dns-in",
		listen = opt(inbound, "dns_listen", "127.0.0.1"),
		listen_port = port,
		network = "udp",
		override_address = "8.8.8.8",
		override_port = 53
	}
end
if #inbounds == 0 then die("at least one inbound must be enabled") end

local direct_dns = dns_server_from_uri("direct-dns", opt(dns_uci, "direct_dns", "223.5.5.5"), opt(dns_uci, "direct_dns_port", "53"), "direct")
local remote_dns = dns_server_from_uri("remote-dns", opt(dns_uci, "remote_dns", "https://1.1.1.1/dns-query"), opt(dns_uci, "remote_dns_port", "443"), final_group())
local dns_conf = {
	servers = { direct_dns, remote_dns },
	rules = {},
	final = opt(dns_uci, "final", "remote-dns"),
	strategy = opt(dns_uci, "strategy", "prefer_ipv4"),
	disable_cache = not truthy(opt(dns_uci, "cache", "1"))
}
if truthy(opt(dns_uci, "fakeip", "0")) then
	dns_conf.servers[#dns_conf.servers + 1] = { type = "fakeip", tag = "fakeip" }
	dns_conf.fakeip = { enabled = true, inet4_range = opt(dns_uci, "fakeip_range", "198.18.0.0/15") }
end

local route_rule_sets = {}
local route_rules = {}
local function add_rule_set(s)
	if not truthy(opt(s, "enabled", "1")) then return end
	local tag = opt(s, "tag", section_name(s))
	local typ = opt(s, "type", "local")
	local rs = { type = typ, tag = tag }
	local format = opt(s, "format", "")
	if format ~= "" then rs.format = format end
	if typ == "local" then
		local path = opt(s, "path", "")
		if path == "" then warn("rule-set " .. tag .. " missing path; skipped"); return end
		rs.path = path
	elseif typ == "remote" then
		local url = opt(s, "url", "")
		if url == "" then warn("rule-set " .. tag .. " missing url; skipped"); return end
		rs.url = url
		if opt(s, "update_interval", "") ~= "" then rs.update_interval = opt(s, "update_interval", "") end
		if supports_114 and opt(s, "http_client", "") ~= "" then rs.http_client = opt(s, "http_client", "") end
		if not supports_114 and opt(s, "download_detour", "") ~= "" then rs.download_detour = opt(s, "download_detour", "") end
	elseif typ == "inline" then
		warn("inline rule-set " .. tag .. " not accepted from UCI for injection safety; use a local source file")
		return
	else
		warn("rule-set " .. tag .. " unsupported type " .. typ)
		return
	end
	route_rule_sets[#route_rule_sets + 1] = rs
end
for _, s in ipairs(sections_by_type("rule_set")) do add_rule_set(s) end

local rule_set_tags = {}
for _, rs in ipairs(route_rule_sets) do rule_set_tags[rs.tag] = true end
if rule_set_tags.private or rule_set_tags.cn then
	local dns_rule_sets = {}
	if rule_set_tags.private then dns_rule_sets[#dns_rule_sets + 1] = "private" end
	if rule_set_tags.cn then dns_rule_sets[#dns_rule_sets + 1] = "cn" end
	dns_conf.rules[#dns_conf.rules + 1] = { rule_set = dns_rule_sets, action = "route", server = "direct-dns" }
end

local function outbound_for_action(action, fallback)
	if action == "direct" then return "direct" end
	if action == "block" then return "block" end
	if action == "proxy" or action == "route" or action == "" then return fallback or final_group() end
	return action
end

local function outbound_exists(tag)
	for _, o in ipairs(outbounds) do
		if o.tag == tag then return true end
	end
	return false
end

local function validate_outbound(tag, context)
	if outbound_exists(tag) then return tag end
	warn(context .. " references unknown outbound " .. tostring(tag) .. "; using " .. final_group())
	return final_group()
end

local function route_action_rule(base, outbound)
	if outbound == "block" then
		base.action = "reject"
	else
		base.action = "route"
		base.outbound = outbound
	end
	return base
end

local function append_route_rule(rule)
	if rule then route_rules[#route_rules + 1] = rule end
end

if supports_113 then
	append_route_rule({ port = 53, network = { "udp", "tcp" }, action = "hijack-dns" })
else
	append_route_rule(route_action_rule({ port = 53, network = { "udp", "tcp" } }, "dns-out"))
end

for _, s in ipairs(sections_by_type("acl")) do
	if truthy(opt(s, "enabled", "1")) then
		local base = {}
		local ips = list_opt(s, "source_ip_cidr")
		if #ips == 0 then ips = list_opt(s, "ip") end
		if #ips > 0 then base.source_ip_cidr = ips end
		local macs = list_opt(s, "source_mac_address")
		if #macs == 0 then macs = list_opt(s, "mac") end
		if #macs > 0 then
			if supports_114 then base.source_mac_address = macs else warn("ACL " .. section_name(s) .. " uses MAC matching; sing-box " .. sing_box_version .. " lacks source_mac_address, falling back to source_ip_cidr only") end
		end
		local hosts = list_opt(s, "source_hostname")
		if #hosts == 0 then hosts = list_opt(s, "hostname") end
		if #hosts > 0 then
			if supports_114 then base.source_hostname = hosts else warn("ACL " .. section_name(s) .. " uses hostname matching; sing-box " .. sing_box_version .. " lacks source_hostname, falling back to source_ip_cidr only") end
		end
		if next(base) then append_route_rule(route_action_rule(base, validate_outbound(outbound_for_action(opt(s, "action", "proxy"), final_group()), "ACL " .. section_name(s)))) end
	end
end

for _, s in ipairs(sections_by_type("rule")) do
	if truthy(opt(s, "enabled", "1")) then
		local base = {}
		local domains = list_opt(s, "domain")
		if #domains > 0 then base.domain = domains end
		local suffix = list_opt(s, "domain_suffix")
		if #suffix > 0 then base.domain_suffix = suffix end
		local keyword = list_opt(s, "domain_keyword")
		if #keyword > 0 then base.domain_keyword = keyword end
		local regex = list_opt(s, "domain_regex")
		if #regex > 0 then base.domain_regex = regex end
		local cidr = list_opt(s, "ip_cidr")
		if #cidr > 0 then base.ip_cidr = cidr end
		local source = list_opt(s, "source_ip_cidr")
		if #source > 0 then base.source_ip_cidr = source end
		local ports = {}
		for _, p in ipairs(list_opt(s, "port")) do ports[#ports + 1] = toint(p, p) end
		if #ports > 0 then base.port = ports end
		local port_range = list_opt(s, "port_range")
		if #port_range > 0 then base.port_range = port_range end
		local rs = {}
		for _, tag in ipairs(list_opt(s, "rule_set")) do
			if rule_set_tags[tag] then rs[#rs + 1] = tag else warn("rule " .. section_name(s) .. " references unknown rule-set " .. tag) end
		end
		if #rs > 0 then base.rule_set = rs end
		if next(base) then append_route_rule(route_action_rule(base, validate_outbound(outbound_for_action(opt(s, "action", "proxy"), final_group()), "rule " .. section_name(s)))) end
	end
end

local client = {
	log = { level = opt(global, "log_level", "info"), timestamp = true },
	experimental = {
		cache_file = {
			enabled = true,
			path = opt(global, "cache_file", data_dir .. "/cache.db"),
			cache_id = "singboxwall"
		}
	},
	inbounds = inbounds,
	outbounds = outbounds,
	dns = dns_conf,
	route = {
		auto_detect_interface = true,
		rule_set = route_rule_sets,
		rules = route_rules,
		final = final_group()
	}
}
if supports_114 then client.experimental.cache_file.store_dns = truthy(opt(dns_uci, "cache", "1")) end
if truthy(opt(global, "clash_api_enabled", "1")) then
	client.experimental.clash_api = {
		external_controller = opt(global, "clash_api_listen", "127.0.0.1") .. ":" .. tostring(toint(opt(global, "clash_api_port", "9090"), 9090)),
		secret = opt(global, "clash_api_secret", ""),
		default_mode = "Rule"
	}
end

local function server_to_inbound(s)
	if not truthy(opt(s, "enabled", "0")) then return nil end
	local typ = opt(s, "protocol", opt(s, "type", "")):lower()
	local tag = opt(s, "tag", "server-" .. section_name(s))
	local listen = opt(s, "listen", "::")
	local port = toint(opt(s, "listen_port", opt(s, "port", "")), nil)
	if not valid_port(port) then warn("server " .. section_name(s) .. " invalid listen_port; skipped"); return nil end
	local ib = { type = typ, tag = tag, listen = listen, listen_port = port }
	if typ == "shadowsocks" or typ == "ss" then
		ib.type = "shadowsocks"
		if opt(s, "method", "") == "" or opt(s, "password", "") == "" then warn("server " .. section_name(s) .. " missing method/password; skipped"); return nil end
		ib.method = opt(s, "method", "")
		ib.password = opt(s, "password", "")
	elseif typ == "trojan" then
		local tls, err = server_tls_from_section(s); if err then return nil end
		if not tls then warn("server " .. section_name(s) .. " trojan requires TLS; skipped"); return nil end
		ib.tls = tls
		ib.users = { { password = opt(s, "password", "") } }
		if ib.users[1].password == "" then warn("server " .. section_name(s) .. " missing password; skipped"); return nil end
	elseif typ == "vless" or typ == "vmess" then
		local uuid = opt(s, "uuid", "")
		if uuid == "" then warn("server " .. section_name(s) .. " missing uuid; skipped"); return nil end
		ib.users = { { uuid = uuid } }
		if typ == "vless" and opt(s, "flow", "") ~= "" then ib.users[1].flow = opt(s, "flow", "") end
		local tls, err = server_tls_from_section(s); if err then return nil end
		if tls then ib.tls = tls end
	elseif typ == "hysteria2" then
		local tls, err = server_tls_from_section(s); if err then return nil end
		if not tls then warn("server " .. section_name(s) .. " hysteria2 requires TLS; skipped"); return nil end
		ib.tls = tls
		ib.users = { { password = opt(s, "password", "") } }
		if ib.users[1].password == "" then warn("server " .. section_name(s) .. " missing password; skipped"); return nil end
	elseif typ == "tuic" then
		local tls, err = server_tls_from_section(s); if err then return nil end
		if not tls then warn("server " .. section_name(s) .. " tuic requires TLS; skipped"); return nil end
		ib.tls = tls
		ib.users = { { uuid = opt(s, "uuid", ""), password = opt(s, "password", "") } }
		if ib.users[1].uuid == "" or ib.users[1].password == "" then warn("server " .. section_name(s) .. " missing uuid/password; skipped"); return nil end
	elseif typ == "anytls" then
		local tls, err = server_tls_from_section(s); if err then return nil end
		if not tls then warn("server " .. section_name(s) .. " anytls requires TLS; skipped"); return nil end
		ib.tls = tls
		ib.users = { { password = opt(s, "password", "") } }
		if ib.users[1].password == "" then warn("server " .. section_name(s) .. " missing password; skipped"); return nil end
	else
		warn("unsupported server protocol for " .. section_name(s) .. ": " .. typ)
		return nil
	end
	local tr = transport_from_section(s)
	if tr then ib.transport = tr end
	return ib
end

local server_inbounds = {}
for _, s in ipairs(sections_by_type("server")) do
	local ib = server_to_inbound(s)
	if ib then server_inbounds[#server_inbounds + 1] = ib end
end

local server = nil
if #server_inbounds > 0 then
	server = {
		log = { level = opt(global, "log_level", "info"), timestamp = true },
		inbounds = server_inbounds,
		outbounds = { { type = "direct", tag = "direct" } },
		route = { final = "direct" }
	}
end


mkdir_p(tmp_dir)
write_file(tmp_dir .. "/client.json", encode_json(client))
if server then
	write_file(tmp_dir .. "/server.json", encode_json(server))
else
	os.remove(tmp_dir .. "/server.json")
end
write_file(tmp_dir .. "/warnings.json", encode_json({ warnings = warnings, sing_box_version = sing_box_version, supports_1133 = supports_1133, supports_114 = supports_114 }))

if #warnings > 0 then
	for _, msg in ipairs(warnings) do io.stderr:write("warning: " .. msg .. "\n") end
end
