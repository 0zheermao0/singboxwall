'use strict';
'require form';
'require rpc';
'require ui';

const callStatus = rpc.declare({ object: 'singboxwall', method: 'status', expect: { '': {} } });
const callCheck = rpc.declare({ object: 'singboxwall', method: 'check', expect: { '': {} } });
const callRestart = rpc.declare({ object: 'singboxwall', method: 'restart', expect: { '': {} } });
const callGenerate = rpc.declare({ object: 'singboxwall', method: 'generate', expect: { '': {} } });
const callTailLog = rpc.declare({ object: 'singboxwall', method: 'tail_log', params: [ 'lines' ], expect: { '': {} } });
const callUpdateSubscriptions = rpc.declare({ object: 'singboxwall', method: 'update_subscriptions', expect: { '': {} } });
const callBackupCreate = rpc.declare({ object: 'singboxwall', method: 'backup_create', params: [ 'path' ], expect: { '': {} } });
const callBackupRestore = rpc.declare({ object: 'singboxwall', method: 'backup_restore', params: [ 'path' ], expect: { '': {} } });
const callRuleUpdate = rpc.declare({ object: 'singboxwall', method: 'rule_update', expect: { '': {} } });
const callUrlTest = rpc.declare({ object: 'singboxwall', method: 'urltest', expect: { '': {} } });

function flag(s, name, title, desc, def) {
	let o = s.option(form.Flag, name, title, desc);
	o.default = def == null ? '0' : def;
	o.rmempty = false;
	return o;
}

function value(s, name, title, desc, datatype, placeholder) {
	let o = s.option(form.Value, name, title, desc);
	if (datatype)
		o.datatype = datatype;
	if (placeholder)
		o.placeholder = placeholder;
	return o;
}

function list(s, name, title, desc, values, def) {
	let o = s.option(form.ListValue, name, title, desc);
	(values || []).forEach(function(v) { o.value(v[0], v[1]); });
	if (def != null)
		o.default = def;
	o.rmempty = false;
	return o;
}

function dynlist(s, name, title, desc, placeholder) {
	let o = s.option(form.DynamicList, name, title, desc);
	if (placeholder)
		o.placeholder = placeholder;
	return o;
}

function grid(m, type, title, desc) {
	let s = m.section(form.GridSection, type, title, desc);
	s.anonymous = false;
	s.addremove = true;
	s.nodescriptions = true;
	return s;
}

function renderCommandResult(res) {
	if (!res)
		return _('No response');
	if (res.result)
		return JSON.stringify(res.result, null, 2);
	return res.stdout || res.stderr || JSON.stringify(res, null, 2);
}

function actionButton(s, name, title, method, message) {
	let o = s.option(form.Button, name, title);
	o.inputstyle = 'action';
	o.inputtitle = title;
	o.onclick = function() {
		return method().then(function(res) {
			ui.addNotification(null, E('pre', [ message || renderCommandResult(res) ]));
		});
	};
	return o;
}

return {
	callStatus: callStatus,
	callCheck: callCheck,
	callRestart: callRestart,
	callGenerate: callGenerate,
	callTailLog: callTailLog,
	callUpdateSubscriptions: callUpdateSubscriptions,
	callBackupCreate: callBackupCreate,
	callBackupRestore: callBackupRestore,
	callRuleUpdate: callRuleUpdate,
	callUrlTest: callUrlTest,
	flag: flag,
	value: value,
	list: list,
	dynlist: dynlist,
	grid: grid,
	actionButton: actionButton,
	renderCommandResult: renderCommandResult
};
