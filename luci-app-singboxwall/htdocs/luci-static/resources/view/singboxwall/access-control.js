'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	load: function() { return Promise.all([ sbw.callStatus() ]); },
	render: function(data) {
		let status = data[0] || {};
		let supports114 = status.sing_box_version && status.sing_box_version != 'unknown' && status.sing_box_version.localeCompare('1.14.0', undefined, { numeric: true }) >= 0;
		let desc = supports114 ? _('This binary can use source MAC and source hostname rules.') : _('This binary cannot use source MAC or hostname rules; ACL falls back to source_ip_cidr. Upgrade sing-box to 1.14+ for MAC/hostname matching.');
		let m = new form.Map('singboxwall', _('Access Control'), desc);
		let s, o;

		s = sbw.grid(m, 'acl', _('Client Rules'));
		s.addbtntitle = _('Add client rule');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'label', _('Label')).editable = true;
		o = sbw.list(s, 'action', _('Action'), null, [ [ 'proxy', _('Proxy / default group') ], [ 'direct', _('Direct') ], [ 'block', _('Block') ] ], 'proxy');
		o.editable = true;
		sbw.dynlist(s, 'source_ip_cidr', _('Source IP CIDR'), _('Always supported.')).modalonly = true;
		sbw.dynlist(s, 'source_mac_address', _('Source MAC address'), _('Generated only when sing-box >= 1.14.')).modalonly = true;
		sbw.dynlist(s, 'source_hostname', _('Source hostname'), _('Generated only when sing-box >= 1.14 and neighbor/DHCP information is available.')).modalonly = true;

		return m.render();
	}
});
