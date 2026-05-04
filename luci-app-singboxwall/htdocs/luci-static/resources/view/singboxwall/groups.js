'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Policy Groups'), _('Policy groups are sing-box selector or urltest outbounds. This is not HAProxy-style round-robin load balancing.'));
		let s, o;

		s = sbw.grid(m, 'group', _('Groups'));
		s.addbtntitle = _('Add group');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'tag', _('Tag'), null, 'uciname').editable = true;
		sbw.value(s, 'label', _('Label')).editable = true;
		o = sbw.list(s, 'group_type', _('Type'), null, [ [ 'selector', _('Manual selector') ], [ 'urltest', _('Auto select by URLTest') ] ], 'selector');
		o.editable = true;
		sbw.dynlist(s, 'outbound', _('Members'), _('Outbound node or group tags. Empty means all nodes, or direct when no node exists.')).modalonly = true;
		sbw.value(s, 'default', _('Default member'), _('Only used by selector groups.')).modalonly = true;
		sbw.value(s, 'url', _('Test URL'), _('Only used by urltest groups.'), null, 'https://www.gstatic.com/generate_204').modalonly = true;
		sbw.value(s, 'interval', _('Test interval'), null, null, '10m').modalonly = true;
		sbw.value(s, 'tolerance', _('Tolerance (ms)'), null, 'uinteger', '50').modalonly = true;
		sbw.value(s, 'idle_timeout', _('Idle timeout'), null, null, '30m').modalonly = true;
		sbw.flag(s, 'interrupt_exist_connections', _('Interrupt existing connections'), null, '0').modalonly = true;

		return m.render();
	}
});
