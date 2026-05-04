#!/usr/bin/env ucode

'use strict';

import { access, popen, readfile } from 'fs';

const APP = '/usr/share/singboxwall/app.sh';

function shell_quote(s) {
	if (s == null || s == '')
		return "''";
	return "'" + replace('' + s, "'", "'\\''") + "'";
}

function exec(command) {
	let stdout = '';
	let p = popen(command, 'r');
	if (p == null)
		return { code: -1, stdout: '', stderr: 'Failed to execute: ' + command };
	for (let line = p.read('line'); length(line); line = p.read('line'))
		stdout += line;
	let code = p.close();
	return { code: code, stdout: stdout, stderr: code == 0 ? '' : stdout };
}

function app(command, args) {
	let cmd = shell_quote(APP) + ' ' + command;
	if (args != null) {
		for (let arg in args)
			cmd += ' ' + shell_quote(arg);
	}
	let res = exec(cmd);
	let parsed = null;
	try { parsed = json(res.stdout); } catch (e) { parsed = null; }
	return {
		ok: res.code == 0,
		code: res.code,
		stdout: res.stdout,
		stderr: res.stderr,
		result: parsed
	};
}

function parse_status() {
	let res = app('status');
	if (res.result != null)
		return res.result;
	return { running: false, error: res.stderr || res.stdout || 'status failed' };
}

const methods = {};

methods.status = {
	call: function() {
		let status = parse_status();
		status.app_present = access(APP);
		return status;
	}
};

methods.check = {
	call: function() {
		return app('check');
	}
};

methods.restart = {
	call: function() {
		return app('restart');
	}
};

methods.generate = {
	call: function() {
		return app('generate');
	}
};

methods.tail_log = {
	args: { lines: 32 },
	call: function(request) {
		let lines = request?.args?.lines || 80;
		let res = app('tail-log', [ lines ]);
		return { ok: res.code == 0, log: res.stdout, code: res.code };
	}
};

methods.urltest = {
	call: function() {
		let status = parse_status();
		return {
			ok: true,
			message: 'URLTest results are maintained by sing-box selector/urltest outbounds and exposed through the Clash API when enabled.',
			clash_api: status?.clash_api || null
		};
	}
};

methods.update_subscriptions = {
	call: function() {
		return app('update-subscriptions');
	}
};

methods.backup_create = {
	args: { path: '' },
	call: function(request) {
		let path = request?.args?.path || '';
		return app('backup', path != '' ? [ path ] : []);
	}
};

methods.backup_restore = {
	args: { path: '' },
	call: function(request) {
		let path = request?.args?.path || '';
		if (path == '')
			return { ok: false, code: 2, stderr: 'backup_restore requires path' };
		return app('restore', [ path ]);
	}
};

methods.rule_update = {
	call: function() {
		return app('update-rules');
	}
};

return { singboxwall: methods };
