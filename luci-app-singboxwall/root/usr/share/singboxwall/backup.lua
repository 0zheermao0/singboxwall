#!/usr/bin/env lua

local action = arg[1] or "create"
local target = arg[2] or ""
local data_dir = "/etc/singboxwall"
local backup_dir = data_dir .. "/backups"
local config_path = "/etc/config/singboxwall"
local generator = "/usr/share/singboxwall/generate.lua"

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run(cmd)
	local a, b, c = os.execute(cmd)
	if a == true then return true end
	if type(a) == "number" then return a == 0 end
	if b == "exit" then return c == 0 end
	return false
end

local function capture(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return "" end
	local out = p:read("*a") or ""
	p:close()
	return out
end

local function mkdir_p(path)
	return run("mkdir -p " .. shell_quote(path))
end

local function exists(path)
	local f = io.open(path, "r")
	if f then f:close(); return true end
	return false
end

local function rm_rf(path)
	if path and path ~= "" and path ~= "/" then run("rm -rf " .. shell_quote(path)) end
end


local function cp(src, dst)
	return run("cp -R " .. shell_quote(src) .. " " .. shell_quote(dst))
end

local function read_global()
	local out = capture("uci -q get singboxwall.global.data_dir"):gsub("%s+$", "")
	if out ~= "" then data_dir = out end
	backup_dir = data_dir .. "/backups"
end

local function json_escape(s)
	s = tostring(s or "")
	return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
end

local function validate_uci_config(path)
	if not exists(path) then return false, "missing /etc/config/singboxwall" end
	local content = assert(io.open(path, "r")):read("*a")
	if not content:match("config%s+global") then return false, "backup config has no global section" end
	if content:match("config%s+[^\n]*passwall") then return false, "backup appears to contain passwall data" end
	return true
end

local function archive_members_safe(path)
	local members = capture("tar -tzf " .. shell_quote(path))
	if members == "" then return false, "backup archive is empty or unreadable" end
	for member in members:gmatch("[^\n]+") do
		if member:match("^/") or member:match("%.%./") or member:match("/%..%./") then
			return false, "backup archive contains unsafe path: " .. member
		end
		if not (member == "etc/config/singboxwall" or member:match("^etc/singboxwall/?")) then
			return false, "backup archive contains unexpected path: " .. member
		end
	end
	return true
end

local function find_lua()
	if run("command -v lua >/dev/null 2>&1") then return "lua" end
	if run("command -v lua5.1 >/dev/null 2>&1") then return "lua5.1" end
	return nil
end

local function generated_check()
	local lua = find_lua()
	if not lua then return false, "Lua interpreter not found" end
	if not run(lua .. " " .. shell_quote(generator)) then return false, "generator failed after restore" end
	local bin = capture("uci -q get singboxwall.global.sing_box_bin"):gsub("%s+$", "")
	if bin == "" then bin = "/usr/bin/sing-box" end
	if not run("[ -x " .. shell_quote(bin) .. " ]") then return false, "sing-box binary not executable: " .. bin end
	if not run(shell_quote(bin) .. " check -c /tmp/etc/singboxwall/client.json") then return false, "sing-box client check failed after restore" end
	if exists("/tmp/etc/singboxwall/server.json") and not run(shell_quote(bin) .. " check -c /tmp/etc/singboxwall/server.json") then return false, "sing-box server check failed after restore" end
	return true
end

local function create()
	read_global()
	mkdir_p(backup_dir)
	mkdir_p(data_dir)
	local ts = os.date("%Y%m%d-%H%M%S")
	local path = target ~= "" and target or (backup_dir .. "/singboxwall-" .. ts .. ".tar.gz")
	local manifest = data_dir .. "/backup-manifest.json"
	local f = io.open(manifest, "w")
	if f then
		f:write('{"name":"singboxwall","created_at":"' .. ts .. '","format":1,"generator":"0.1.0"}\n')
		f:close()
	end
	local include_cache = capture("uci -q get singboxwall.backup.include_cache"):gsub("%s+$", "")
	local exclude_cache = ""
	if include_cache ~= "1" and include_cache ~= "true" and include_cache ~= "yes" then
		exclude_cache = " --exclude=etc/singboxwall/cache.db --exclude=etc/singboxwall/cache.db-*"
	end
	local cmd = "tar -czf " .. shell_quote(path) .. exclude_cache .. " -C / etc/config/singboxwall -C / etc/singboxwall"
	if run(cmd) then
		print('{"ok":true,"path":"' .. json_escape(path) .. '"}')
	else
		io.stderr:write("failed to create backup\n")
		os.exit(1)
	end
end

local function restore()
	read_global()
	if target == "" then io.stderr:write("restore requires archive path\n"); os.exit(2) end
	if not exists(target) then io.stderr:write("backup not found: " .. target .. "\n"); os.exit(1) end
	local members_ok, members_err = archive_members_safe(target)
	if not members_ok then
		io.stderr:write(members_err .. "\n")
		os.exit(1)
	end
	local stamp = tostring(os.time()) .. "." .. tostring(math.random(1000, 9999))
	local tmp = "/tmp/singboxwall-restore-" .. stamp
	local backup_config = "/tmp/singboxwall-current-config-" .. stamp
	local backup_data = "/tmp/singboxwall-current-data-" .. stamp
	mkdir_p(tmp)
	if not run("tar -xzf " .. shell_quote(target) .. " -C " .. shell_quote(tmp)) then
		io.stderr:write("backup archive is not a readable tar.gz\n")
		rm_rf(tmp)
		os.exit(1)
	end
	local ok, err = validate_uci_config(tmp .. "/etc/config/singboxwall")
	if not ok then
		io.stderr:write(err .. "\n")
		rm_rf(tmp)
		os.exit(1)
	end
	mkdir_p("/etc/config")
	mkdir_p("/tmp")
	if exists(config_path) and not cp(config_path, backup_config) then io.stderr:write("failed to stage current config\n"); os.exit(1) end
	if exists(data_dir) and not cp(data_dir, backup_data) then io.stderr:write("failed to stage current data\n"); os.exit(1) end
	local function rollback(reason)
		if exists(backup_config) then cp(backup_config, config_path) end
		if exists(backup_data) then rm_rf(data_dir); cp(backup_data, data_dir) end
		rm_rf(tmp); rm_rf(backup_config); rm_rf(backup_data)
		io.stderr:write(reason .. "\n")
		os.exit(1)
	end
	if not cp(tmp .. "/etc/config/singboxwall", config_path) then rollback("failed to restore UCI config") end
	if exists(tmp .. "/etc/singboxwall") then
		rm_rf(data_dir)
		if not cp(tmp .. "/etc/singboxwall", data_dir) then rollback("failed to restore data directory") end
	end
	local check_ok, check_err = generated_check()
	if not check_ok then rollback(check_err) end
	rm_rf(tmp); rm_rf(backup_config); rm_rf(backup_data)
	print('{"ok":true}')
end

if action == "create" then
	create()
elseif action == "restore" then
	restore()
else
	io.stderr:write("unsupported action: " .. tostring(action) .. "\n")
	os.exit(2)
end
