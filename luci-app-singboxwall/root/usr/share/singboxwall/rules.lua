#!/usr/bin/env lua

local uci_ok, uci_mod = pcall(require, "uci")
local uci = uci_ok and uci_mod.cursor and uci_mod.cursor() or nil
local action = arg[1] or "update"
local data_dir = "/etc/singboxwall"
local bin = "/usr/bin/sing-box"
local warnings = {}

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run(cmd)
	local code = os.execute(cmd)
	if type(code) == "number" then return code == 0 end
	return code == true
end

local function capture(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return "" end
	local out = p:read("*a") or ""
	p:close()
	return out
end

local function mkdir_p(path)
	os.execute("mkdir -p " .. shell_quote(path))
end

local function opt(section, key, default)
	local v = section and section[key]
	if v == nil or v == "" then return default end
	return v
end

local function truthy(v)
	v = tostring(v or ""):lower()
	return v == "1" or v == "true" or v == "yes" or v == "on" or v == "enabled"
end

local function warn(msg)
	warnings[#warnings + 1] = msg
	io.stderr:write("warning: " .. msg .. "\n")
end

local function read_sections(stype)
	local out = {}
	if uci then
		uci:foreach("singboxwall", stype, function(s) out[#out + 1] = s end)
	end
	return out
end

local function init_paths()
	if uci then
		local g = uci:get_all("singboxwall", "global") or {}
		data_dir = opt(g, "data_dir", data_dir)
		bin = opt(g, "sing_box_bin", bin)
	end
	mkdir_p(data_dir .. "/rules")
end

local function download(url, dest)
	local tmp = dest .. ".tmp"
	local cmd
	if run("command -v uclient-fetch >/dev/null 2>&1") then
		cmd = "uclient-fetch -q -O " .. shell_quote(tmp) .. " " .. shell_quote(url)
	elseif run("command -v curl >/dev/null 2>&1") then
		cmd = "curl -fsSL -o " .. shell_quote(tmp) .. " " .. shell_quote(url)
	else
		warn("no downloader found for " .. url)
		return false
	end
	if run(cmd) then
		os.rename(tmp, dest)
		return true
	end
	os.remove(tmp)
	warn("failed to download rule-set " .. url)
	return false
end

local function maybe_compile(source_path, binary_path)
	if run("command -v " .. shell_quote(bin) .. " >/dev/null 2>&1") then
		local cmd = shell_quote(bin) .. " rule-set compile --output " .. shell_quote(binary_path) .. " " .. shell_quote(source_path)
		if run(cmd) then return true end
		warn("sing-box rule-set compile failed for " .. source_path)
	end
	return false
end

local function update()
	init_paths()
	local changed = 0
	for _, s in ipairs(read_sections("rule_set")) do
		if truthy(opt(s, "enabled", "1")) and opt(s, "type", "local") == "remote" then
			local tag = opt(s, "tag", s[".name"] or "remote")
			local url = opt(s, "url", "")
			if url == "" then
				warn("remote rule-set " .. tag .. " has no URL")
			else
				local clean_url = url:gsub('[?#].*$', '')
				local format = opt(s, "format", "source")
				local ext = clean_url:match("%.([A-Za-z0-9]+)$") or format
				if format == "binary" or ext == "srs" then ext = "srs" else ext = "json" end
				local dest = data_dir .. "/rules/" .. tag .. "." .. ext
				if download(url, dest) then
					changed = changed + 1
					if ext == "json" then maybe_compile(dest, data_dir .. "/rules/" .. tag .. ".srs") end
				end
			end
		end
	end
	print(string.format('{"ok":true,"updated":%d,"warnings":%d}', changed, #warnings))
end

if action == "update" then
	update()
else
	io.stderr:write("unsupported action: " .. tostring(action) .. "\n")
	os.exit(2)
end
