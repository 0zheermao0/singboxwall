'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('DNS'), _('sing-box handles DNS routing internally. FakeIP is available but disabled by default to avoid LAN compatibility surprises.'));
		let s, o;

		s = m.section(form.TypedSection, 'inbound', _('Local DNS Inbound'));
		s.anonymous = true;
		sbw.flag(s, 'dns_enabled', _('Enable DNS inbound'), _('Creates a direct UDP inbound whose destination is hijacked by sing-box DNS route rules.'), '1');
		sbw.value(s, 'dns_listen', _('Listen address'), null, 'ipaddr', '127.0.0.1');
		sbw.value(s, 'dns_port', _('Listen port'), null, 'port', '5353');

		s = m.section(form.TypedSection, 'dns', _('DNS Servers and Policy'));
		s.anonymous = true;
		sbw.value(s, 'direct_dns', _('Direct DNS'), _('Plain IP, tls://host, or https://host/dns-query.'), null, '223.5.5.5');
		sbw.value(s, 'direct_dns_port', _('Direct DNS port'), null, 'port', '53');
		sbw.value(s, 'remote_dns', _('Remote DNS'), _('Plain IP, tls://host, or https://host/dns-query. Remote DNS is dialed through the default group.'), null, 'https://1.1.1.1/dns-query');
		o = sbw.list(s, 'strategy', _('Domain strategy'), null, [ [ 'prefer_ipv4', 'prefer_ipv4' ], [ 'prefer_ipv6', 'prefer_ipv6' ], [ 'ipv4_only', 'ipv4_only' ], [ 'ipv6_only', 'ipv6_only' ] ], 'prefer_ipv4');
		sbw.flag(s, 'cache', _('Enable DNS cache'), null, '1');
		sbw.flag(s, 'fakeip', _('Enable FakeIP'), _('Default is off. Enable only after validating LAN/client compatibility.'), '0');
		sbw.value(s, 'fakeip_range', _('FakeIP range'), null, null, '198.18.0.0/15');
		sbw.value(s, 'final', _('Final DNS server tag'), null, null, 'remote-dns');

		return m.render();
	}
});
