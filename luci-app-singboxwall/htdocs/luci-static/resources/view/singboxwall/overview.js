'use strict';
'require view';
'require form';
'require ui';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	load: function() {
		return Promise.all([ sbw.callStatus() ]);
	},

	renderStatus: function(status) {
		let fields = [
			_('Running'), status.running ? _('Yes') : _('No'),
			_('sing-box version'), status.sing_box_version || _('Unknown'),
			_('Client config generated'), status.client_config ? _('Yes') : _('No'),
			_('Server config generated'), status.server_config ? _('Yes') : _('No')
		];
		let table = E('table', { 'class': 'table' });
		for (let i = 0; i < fields.length; i += 2)
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ fields[i] ]),
				E('td', { 'class': 'td left' }, [ fields[i + 1] ])
			]));
		return table;
	},

	render: function(data) {
		let status = data[0] || {};
		let m = new form.Map('singboxwall', _('SingBoxWall'), _('sing-box based transparent proxy, DNS routing, policy groups, server mode, subscriptions, and backup/restore.'));
		let s, o;

		s = m.section(form.TypedSection, 'global', _('Global Settings'));
		s.anonymous = true;
		s.option(form.DummyValue, '_status', _('Runtime Status')).cfgvalue = L.bind(function() {
			return this.renderStatus(status);
		}, this);
		sbw.flag(s, 'enabled', _('Enable service'), _('The init script generates and checks sing-box JSON before starting procd instances.'), '0');
		sbw.list(s, 'log_level', _('Log level'), null, [ [ 'trace', 'trace' ], [ 'debug', 'debug' ], [ 'info', 'info' ], [ 'warn', 'warn' ], [ 'error', 'error' ], [ 'fatal', 'fatal' ], [ 'panic', 'panic' ] ], 'info');
		sbw.value(s, 'sing_box_bin', _('sing-box binary'), null, null, '/usr/bin/sing-box');
		sbw.value(s, 'work_dir', _('Runtime directory'), null, null, '/var/run/singboxwall');
		sbw.value(s, 'temp_dir', _('Generated config directory'), null, null, '/tmp/etc/singboxwall');
		sbw.value(s, 'data_dir', _('Persistent data directory'), null, null, '/etc/singboxwall');
		sbw.value(s, 'cache_file', _('Cache file'), _('Used by experimental.cache_file. DNS cache persistence is generated only when the binary is at least sing-box 1.14.'), null, '/etc/singboxwall/cache.db');
		sbw.value(s, 'default_group', _('Default outbound or group'), _('Route final target. Use a policy group tag or node tag.'), null, 'proxy');

		s = m.section(form.TypedSection, 'global', _('Clash API'));
		s.anonymous = true;
		sbw.flag(s, 'clash_api_enabled', _('Enable Clash API'), _('Selectors are controlled through the Clash API.'), '1');
		sbw.value(s, 'clash_api_listen', _('Listen address'), null, 'ipaddr', '127.0.0.1');
		sbw.value(s, 'clash_api_port', _('Listen port'), null, 'port', '9090');
		o = sbw.value(s, 'clash_api_secret', _('Secret'), _('Always set a secret if listening outside localhost.'));
		o.password = true;

		s = m.section(form.TypedSection, 'global', _('Actions'));
		s.anonymous = true;
		sbw.actionButton(s, '_generate', _('Generate config'), sbw.callGenerate);
		sbw.actionButton(s, '_check', _('Generate and check'), sbw.callCheck);
		sbw.actionButton(s, '_restart', _('Restart service'), sbw.callRestart);

		return m.render();
	}
});
