'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Server'), _('Server inbounds are generated into an independent sing-box config and procd instance. TLS protocols will not start unless certificate and key paths are configured.'));
		let s, o;

		s = sbw.grid(m, 'server', _('Server Inbounds'));
		s.addbtntitle = _('Add server');
		sbw.flag(s, 'enabled', _('Enable'), null, '0').editable = true;
		sbw.value(s, 'tag', _('Tag'), null, 'uciname').editable = true;
		o = sbw.list(s, 'protocol', _('Protocol'), null, [ [ 'shadowsocks', 'Shadowsocks' ], [ 'trojan', 'Trojan' ], [ 'vless', 'VLESS' ], [ 'vmess', 'VMess' ], [ 'hysteria2', 'Hysteria2' ], [ 'tuic', 'TUIC' ], [ 'anytls', 'AnyTLS' ] ], 'shadowsocks');
		o.editable = true;
		sbw.value(s, 'listen', _('Listen address'), null, null, '::').editable = true;
		sbw.value(s, 'listen_port', _('Listen port'), null, 'port').editable = true;
		sbw.value(s, 'method', _('Shadowsocks method'), null, null, '2022-blake3-aes-128-gcm').modalonly = true;
		o = sbw.value(s, 'password', _('Password'), null, null); o.password = true; o.modalonly = true;
		sbw.value(s, 'uuid', _('UUID'), _('Required for VLESS, VMess, and TUIC.')).modalonly = true;
		sbw.value(s, 'flow', _('VLESS flow')).modalonly = true;
		sbw.flag(s, 'tls_enabled', _('Enable TLS'), _('Required for Trojan, Hysteria2, TUIC, and AnyTLS.'), '0').modalonly = true;
		sbw.value(s, 'tls_certificate_path', _('TLS certificate path'), null, null, '/etc/singboxwall/server.crt').modalonly = true;
		sbw.value(s, 'tls_key_path', _('TLS key path'), null, null, '/etc/singboxwall/server.key').modalonly = true;
		sbw.dynlist(s, 'alpn', _('ALPN')).modalonly = true;
		o = sbw.list(s, 'transport', _('Transport'), null, [ [ '', _('None / TCP') ], [ 'ws', 'WebSocket' ], [ 'http', 'HTTP' ], [ 'grpc', 'gRPC' ] ], '');
		o.modalonly = true;
		sbw.value(s, 'transport_path', _('Transport path')).modalonly = true;
		sbw.value(s, 'transport_host', _('Transport host')).modalonly = true;

		return m.render();
	}
});
