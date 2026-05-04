#!/usr/bin/env lua

local action = arg[1] or "summary"
local lines = tonumber(arg[2] or "80") or 80
local log_path = "/var/log/singboxwall.log"

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function capture(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return "" end
	local out = p:read("*a") or ""
	p:close()
	return out
end

local function json_escape(s)
	s = tostring(s or "")
	s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
	return s
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function tail(path, n)
	local data = read_file(path) or ""
	local arr = {}
	for line in data:gmatch("[^\n]*\n?") do
		if line ~= "" then arr[#arr + 1] = line:gsub("\n$", "") end
	end
	local start = math.max(1, #arr - n + 1)
	local out = {}
	for i = start, #arr do out[#out + 1] = arr[i] end
	return table.concat(out, "\n")
end

local function summary()
	local bin = capture("uci -q get singboxwall.global.sing_box_bin"):gsub("%s+$", "")
	local tmp = capture("uci -q get singboxwall.global.temp_dir"):gsub("%s+$", "")
	if bin == "" then bin = "/usr/bin/sing-box" end
	if tmp == "" then tmp = "/tmp/etc/singboxwall" end
	local version = capture(shell_quote(bin) .. " version"):match("(%d+%.%d+%.%d+)") or "unknown"
	local client_exists = read_file(tmp .. "/client.json") ~= nil
	local server_exists = read_file(tmp .. "/server.json") ~= nil
	local warnings = read_file(tmp .. "/warnings.json") or "{}"
	local running = capture("pidof sing-box") ~= ""
	print(string.format('{"running":%s,"client_config":%s,"server_config":%s,"sing_box_version":"%s","warnings":%s}', running and "true" or "false", client_exists and "true" or "false", server_exists and "true" or "false", json_escape(version), warnings))
end

if action == "summary" then
	summary()
elseif action == "log" then
	print(tail(log_path, lines))
else
	io.stderr:write("unsupported action: " .. tostring(action) .. "\n")
	os.exit(2)
end
