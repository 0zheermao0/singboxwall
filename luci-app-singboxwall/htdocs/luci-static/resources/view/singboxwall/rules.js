'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Rules'), _('Rules are rendered as sing-box rule-set and route rules. Deprecated geoip/geosite fields are intentionally not exposed.'));
		let s, o;

		s = sbw.grid(m, 'rule_set', _('Rule Sets'));
		s.addbtntitle = _('Add rule-set');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'tag', _('Tag'), null, 'uciname').editable = true;
		o = sbw.list(s, 'type', _('Type'), null, [ [ 'local', _('Local file') ], [ 'remote', _('Remote') ] ], 'local');
		o.editable = true;
		o = sbw.list(s, 'format', _('Format'), null, [ [ 'source', _('Source JSON') ], [ 'binary', _('Binary SRS') ] ], 'source');
		o.editable = true;
		sbw.value(s, 'path', _('Local path'), _('Use source JSON or compiled .srs files.')).modalonly = true;
		sbw.value(s, 'url', _('Remote URL'), _('Remote .json or .srs rule-set URL.')).modalonly = true;
		sbw.value(s, 'update_interval', _('Update interval'), null, null, '1d').modalonly = true;
		sbw.value(s, 'download_detour', _('Download detour for < 1.14'), _('Generated only before sing-box 1.14; newer versions use http_client.')).modalonly = true;
		sbw.value(s, 'http_client', _('HTTP client tag for >= 1.14'), _('Generated only when sing-box >= 1.14.')).modalonly = true;

		s = sbw.grid(m, 'rule', _('Route Rules'));
		s.addbtntitle = _('Add route rule');
		sbw.flag(s, 'enabled', _('Enable'), null, '1').editable = true;
		sbw.value(s, 'label', _('Label')).editable = true;
		o = sbw.list(s, 'action', _('Action'), null, [ [ 'proxy', _('Proxy / default group') ], [ 'direct', _('Direct') ], [ 'block', _('Block') ] ], 'proxy');
		o.editable = true;
		sbw.dynlist(s, 'rule_set', _('Rule-set tags')).modalonly = true;
		sbw.dynlist(s, 'domain', _('Domains')).modalonly = true;
		sbw.dynlist(s, 'domain_suffix', _('Domain suffixes')).modalonly = true;
		sbw.dynlist(s, 'domain_keyword', _('Domain keywords')).modalonly = true;
		sbw.dynlist(s, 'domain_regex', _('Domain regex')).modalonly = true;
		sbw.dynlist(s, 'ip_cidr', _('IP CIDR')).modalonly = true;
		sbw.dynlist(s, 'source_ip_cidr', _('Source IP CIDR')).modalonly = true;
		sbw.dynlist(s, 'port', _('Destination ports')).modalonly = true;
		sbw.dynlist(s, 'port_range', _('Destination port ranges')).modalonly = true;

		s = m.section(form.TypedSection, 'global', _('Rule Actions'));
		s.anonymous = true;
		sbw.actionButton(s, '_rule_update', _('Update remote rule-sets'), sbw.callRuleUpdate);

		return m.render();
	}
});
