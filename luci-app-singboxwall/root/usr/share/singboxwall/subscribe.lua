#!/usr/bin/env lua

local action = arg[1] or "update"
local uci_ok, uci_mod = pcall(require, "uci")
local uci = uci_ok and uci_mod.cursor and uci_mod.cursor() or nil
local warnings = {}

local function warn(msg)
	warnings[#warnings + 1] = msg
	io.stderr:write("warning: " .. msg .. "\n")
end

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run_capture(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return "" end
	local out = p:read("*a") or ""
	p:close()
	return out
end

local function run_ok(cmd)
	local a, b, c = os.execute(cmd)
	if a == true then return true end
	if type(a) == 'number' then return a == 0 end
	if b == 'exit' then return c == 0 end
	return false
end

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64decode(data)
	data = tostring(data or ''):gsub('%s', ''):gsub('%-', '+'):gsub('_', '/')
	local bitstr = data:gsub('[^' .. b64chars .. '=]', ''):gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (b64chars:find(x, 1, true) or 1) - 1
		for i = 6, 1, -1 do r = r .. ((f % 2 ^ i - f % 2 ^ (i - 1) > 0) and '1' or '0') end
		return r
	end)
	return bitstr:gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end)
end

local function url_decode(s)
	s = tostring(s or ''):gsub('+', ' ')
	return (s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end))
end

local function parse_query(q)
	local out = {}
	for k, v in tostring(q or ''):gmatch('([^&=?]+)=?([^&]*)') do out[url_decode(k)] = url_decode(v) end
	return out
end

local function parse_host_port(rest)
	local host, port = rest:match('^%[([^%]]+)%]:(%d+)')
	if host then return host, tonumber(port) end
	host, port = rest:match('^([^:/?#]+):(%d+)')
	return host, tonumber(port)
end

local function parse_ss(uri)
	local body, name = uri:match('^ss://([^#]+)#?(.*)$')
	if not body then return nil, 'invalid ss uri' end
	body = body:gsub('/.*$', '')
	local userinfo, hostpart = body:match('^([^@]+)@(.+)$')
	if not userinfo then
		local decoded = b64decode(body)
		userinfo, hostpart = decoded:match('^([^@]+)@(.+)$')
	end
	if not userinfo or not hostpart then return nil, 'invalid ss credentials' end
	local method, password = b64decode(userinfo):match('^([^:]+):(.+)$')
	if not method then method, password = userinfo:match('^([^:]+):(.+)$') end
	local host, port = parse_host_port(hostpart)
	if not host or not port then return nil, 'invalid ss server' end
	return { protocol = 'shadowsocks', label = url_decode(name or host), server = host, server_port = tostring(port), method = method, password = password }
end

local function parse_standard(uri, scheme)
	local body = uri:match('^' .. scheme .. '://(.+)$')
	if not body then return nil, 'invalid ' .. scheme .. ' uri' end
	local before_hash, label = body:match('^([^#]*)#?(.*)$')
	local main, query = before_hash:match('^([^?]*)%??(.*)$')
	local auth, hostpart = main:match('^([^@]+)@(.+)$')
	if not auth or not hostpart then return nil, 'missing credentials' end
	local host, port = parse_host_port(hostpart)
	if not host or not port then return nil, 'invalid server' end
	local q = parse_query(query)
	local node = { protocol = scheme, label = url_decode(label ~= '' and label or host), server = host, server_port = tostring(port) }
	if scheme == 'trojan' then node.password = url_decode(auth)
	elseif scheme == 'vless' or scheme == 'vmess' then node.uuid = url_decode(auth)
	elseif scheme == 'tuic' then
		local uuid, password = auth:match('^([^:]+):(.+)$')
		node.uuid = url_decode(uuid or auth)
		node.password = url_decode(q.password or password or '')
	elseif scheme == 'hysteria2' then node.password = url_decode(auth)
	end
	if q.security == 'tls' or q.tls == '1' then node.tls_enabled = '1' end
	if q.sni then node.server_name = q.sni end
	if q.flow then node.flow = q.flow end
	if q.type then node.transport = q.type end
	if q.path then node.transport_path = q.path end
	if q.host then node.transport_host = q.host end
	return node
end

local function parse_vmess(uri)
	local payload = uri:match('^vmess://(.+)$')
	if not payload then return nil, 'invalid vmess uri' end
	local decoded = b64decode(payload)
	local add = decoded:match('"add"%s*:%s*"([^"]+)"')
	local port = decoded:match('"port"%s*:%s*"?([0-9]+)"?')
	local uuid = decoded:match('"id"%s*:%s*"([^"]+)"')
	if not add or not port or not uuid then return nil, 'unsupported vmess JSON' end
	local ps = decoded:match('"ps"%s*:%s*"([^"]+)"') or add
	local tls = decoded:match('"tls"%s*:%s*"([^"]*)"')
	return { protocol = 'vmess', label = ps, server = add, server_port = port, uuid = uuid, security = 'auto', alter_id = decoded:match('"aid"%s*:%s*"?([0-9]+)"?') or '0', tls_enabled = tls == 'tls' and '1' or '0' }
end

local function parse_line(line)
	line = tostring(line or ''):match('^%s*(.-)%s*$')
	if line == '' or line:match('^#') then return nil end
	if line:match('^ss://') then return parse_ss(line) end
	if line:match('^vmess://') then return parse_vmess(line) end
	for _, scheme in ipairs({ 'trojan', 'vless', 'hysteria2', 'tuic' }) do
		if line:match('^' .. scheme .. '://') then return parse_standard(line, scheme) end
	end
	return nil, 'unsupported subscription line'
end

local function download(url)
	if url == '' then return '' end
	local cmd
	if run_ok('command -v uclient-fetch >/dev/null 2>&1') then
		cmd = 'uclient-fetch -q -O - ' .. shell_quote(url)
	elseif run_ok('command -v curl >/dev/null 2>&1') then
		cmd = 'curl -fsSL ' .. shell_quote(url)
	else
		warn('no downloader found')
		return ''
	end
	return run_capture(cmd)
end

local function load_subscriptions()
	local sections = {}
	if uci then uci:foreach('singboxwall', 'subscribe', function(s) sections[#sections + 1] = s end) end
	return sections
end

local function set_node(idx, node, subname)
	if not uci then return end
	local sid = 'sub_' .. tostring(idx)
	uci:section('singboxwall', 'node', sid)
	uci:set('singboxwall', sid, 'enabled', '1')
	uci:set('singboxwall', sid, 'tag', sid)
	uci:set('singboxwall', sid, 'label', node.label or sid)
	uci:set('singboxwall', sid, 'protocol', node.protocol)
	uci:set('singboxwall', sid, 'server', node.server)
	uci:set('singboxwall', sid, 'server_port', node.server_port)
	for _, k in ipairs({ 'method', 'password', 'uuid', 'security', 'alter_id', 'tls_enabled', 'server_name', 'flow', 'transport', 'transport_path', 'transport_host' }) do
		if node[k] and node[k] ~= '' then uci:set('singboxwall', sid, k, node[k]) end
	end
	uci:set('singboxwall', sid, 'subscription', subname)
end

local function clear_subscription_nodes(subname)
	if not uci then return end
	local remove = {}
	uci:foreach('singboxwall', 'node', function(s)
		if s.subscription == subname then remove[#remove + 1] = s['.name'] end
	end)
	for _, sid in ipairs(remove) do uci:delete('singboxwall', sid) end
end

local function update()
	if not uci then warn('uci Lua module unavailable; cannot import subscriptions'); print('{"ok":false,"imported":0}'); return end
	local count = 0
	for _, sub in ipairs(load_subscriptions()) do
		local subname = sub['.name'] or ''
		clear_subscription_nodes(subname)
		if tostring(sub.enabled or '1') == '1' then
			local content = download(sub.url or '')
			if content ~= '' and not content:match('://') then content = b64decode(content) end
			for line in content:gmatch('[^\r\n]+') do
				local node, err = parse_line(line)
				if node then count = count + 1; set_node(count, node, subname) else warn(err or 'unparsed line') end
			end
		end
	end
	uci:commit('singboxwall')
	print(string.format('{"ok":true,"imported":%d,"warnings":%d}', count, #warnings))
end

if action == 'update' then
	update()
else
	io.stderr:write('unsupported action: ' .. tostring(action) .. '\n')
	os.exit(2)
end
