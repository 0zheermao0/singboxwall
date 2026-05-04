'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Subscriptions'), _('Subscription import supports common ss, vmess, trojan, vless, hysteria2, and tuic URI forms. Unknown protocols are logged as warnings.'));
		let s;

		s = sbw.grid(m, 'subscribe', _('Subscriptions'));
		s.addbtntitle = _('Add subscription');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'label', _('Label')).editable = true;
		sbw.value(s, 'url', _('URL'), null, null, 'https://example.com/sub').editable = true;
		sbw.value(s, 'filter', _('Filter keyword'), _('Reserved for future filtering.')).modalonly = true;
		sbw.value(s, 'target_group', _('Target group'), _('Imported nodes can be referenced by group member tags.')).modalonly = true;
		sbw.value(s, 'update_interval', _('Update interval'), null, null, '1d').modalonly = true;

		s = m.section(form.TypedSection, 'global', _('Subscription Actions'));
		s.anonymous = true;
		sbw.actionButton(s, '_update_subscriptions', _('Update subscriptions'), sbw.callUpdateSubscriptions);

		return m.render();
	}
});
