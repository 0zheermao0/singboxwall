'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Nodes'), _('Nodes are sing-box outbound definitions. Unsupported protocols and missing required fields are rejected by the generator instead of producing partial JSON.'));
		let s, o;

		s = sbw.grid(m, 'node', _('Outbound Nodes'));
		s.addbtntitle = _('Add node');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'tag', _('Tag'), _('Unique sing-box outbound tag. Do not use direct, block, or dns-out.'), 'uciname').editable = true;
		sbw.value(s, 'label', _('Label')).editable = true;
		o = sbw.list(s, 'protocol', _('Protocol'), null, [
			[ 'shadowsocks', 'Shadowsocks' ], [ 'vmess', 'VMess' ], [ 'trojan', 'Trojan' ], [ 'vless', 'VLESS' ],
			[ 'hysteria2', 'Hysteria2' ], [ 'tuic', 'TUIC' ], [ 'anytls', 'AnyTLS' ], [ 'wireguard', 'WireGuard' ], [ 'ssh', 'SSH' ]
		], 'shadowsocks');
		o.editable = true;
		sbw.value(s, 'server', _('Server'), null, 'host').editable = true;
		sbw.value(s, 'server_port', _('Port'), null, 'port').editable = true;

		s.tab('basic', _('Basic'));
		s.tab('auth', _('Authentication'));
		s.tab('tls', _('TLS'));
		s.tab('transport', _('Transport'));

		o = s.taboption('basic', form.Flag, 'enabled', _('Enable'));
		o.default = '1';
		o = s.taboption('basic', form.Value, 'tag', _('Tag'));
		o.datatype = 'uciname';
		s.taboption('basic', form.Value, 'label', _('Label'));
		o = s.taboption('basic', form.ListValue, 'protocol', _('Protocol'));
		[ [ 'shadowsocks', 'Shadowsocks' ], [ 'vmess', 'VMess' ], [ 'trojan', 'Trojan' ], [ 'vless', 'VLESS' ], [ 'hysteria2', 'Hysteria2' ], [ 'tuic', 'TUIC' ], [ 'anytls', 'AnyTLS' ], [ 'wireguard', 'WireGuard' ], [ 'ssh', 'SSH' ] ].forEach(function(v) { o.value(v[0], v[1]); });
		s.taboption('basic', form.Value, 'server', _('Server')).datatype = 'host';
		s.taboption('basic', form.Value, 'server_port', _('Port')).datatype = 'port';
		o = s.taboption('basic', form.ListValue, 'network', _('Network'));
		o.value('', _('Default')); o.value('tcp', 'TCP'); o.value('udp', 'UDP');

		o = s.taboption('auth', form.Value, 'method', _('Shadowsocks method'));
		o.depends('protocol', 'shadowsocks');
		o.placeholder = '2022-blake3-aes-128-gcm';
		o = s.taboption('auth', form.Value, 'password', _('Password'));
		o.password = true;
		o = s.taboption('auth', form.Value, 'uuid', _('UUID'));
		o.depends('protocol', 'vmess'); o.depends('protocol', 'vless'); o.depends('protocol', 'tuic');
		o = s.taboption('auth', form.Value, 'security', _('VMess security'));
		o.depends('protocol', 'vmess'); o.placeholder = 'auto';
		o = s.taboption('auth', form.Value, 'alter_id', _('VMess alterId'));
		o.depends('protocol', 'vmess'); o.datatype = 'uinteger'; o.placeholder = '0';
		o = s.taboption('auth', form.Value, 'user', _('SSH user'));
		o.depends('protocol', 'ssh');
		o = s.taboption('auth', form.Value, 'private_key_path', _('SSH private key path'));
		o.depends('protocol', 'ssh');
		o = s.taboption('auth', form.DynamicList, 'local_address', _('WireGuard local addresses'));
		o.depends('protocol', 'wireguard');
		o = s.taboption('auth', form.Value, 'private_key', _('WireGuard private key'));
		o.depends('protocol', 'wireguard'); o.password = true;
		o = s.taboption('auth', form.Value, 'peer_public_key', _('WireGuard peer public key'));
		o.depends('protocol', 'wireguard');

		o = s.taboption('tls', form.Flag, 'tls_enabled', _('Enable TLS'));
		o.default = '0';
		o = s.taboption('tls', form.Value, 'server_name', _('TLS server name / SNI'));
		o = s.taboption('tls', form.DynamicList, 'alpn', _('ALPN'));
		o = s.taboption('tls', form.Flag, 'insecure', _('Allow insecure TLS'));
		o.default = '0';
		o = s.taboption('tls', form.Flag, 'utls_enabled', _('Enable uTLS'));
		o.default = '0';
		o = s.taboption('tls', form.Value, 'utls_fingerprint', _('uTLS fingerprint'));
		o.placeholder = 'chrome';
		o = s.taboption('tls', form.Flag, 'reality_enabled', _('Enable Reality'));
		o.default = '0';
		o = s.taboption('tls', form.Value, 'reality_public_key', _('Reality public key'));
		o = s.taboption('tls', form.Value, 'reality_short_id', _('Reality short ID'));

		o = s.taboption('transport', form.ListValue, 'transport', _('V2Ray transport'));
		o.value('', _('None / TCP')); o.value('ws', 'WebSocket'); o.value('http', 'HTTP'); o.value('grpc', 'gRPC');
		s.taboption('transport', form.Value, 'transport_path', _('Transport path'));
		s.taboption('transport', form.Value, 'transport_host', _('Transport host'));
		o = s.taboption('transport', form.Flag, 'multiplex_enabled', _('Enable multiplex'));
		o.default = '0';

		return m.render();
	}
});
