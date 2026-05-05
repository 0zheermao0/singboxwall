'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
'require ui';
/* global sbw */

return view.extend({
	render: function() {
		let m = new form.Map('singboxwall', _('Backup / Restore'), _('Backups include UCI config, subscriptions, manual rules, server config, and generator metadata. Restore validates the archive and runs sing-box check before keeping changes.'));
		let s, o;

		s = m.section(form.TypedSection, 'backup', _('Backup Settings'));
		s.anonymous = true;
		sbw.value(s, 'directory', _('Backup directory'), null, null, '/etc/singboxwall/backups');
		sbw.flag(s, 'include_cache', _('Include cache database'), _('Disabled by default to keep backups deterministic.'), '0');

		s = m.section(form.TypedSection, 'backup', _('Actions'));
		s.anonymous = true;
		o = s.option(form.Value, '_restore_path', _('Restore archive path'));
		o.rmempty = true;
		sbw.actionButton(s, '_create', _('Create backup'), function() { return sbw.callBackupCreate(''); });
		o = s.option(form.Button, '_restore', _('Restore backup'));
		o.inputstyle = 'negative';
		o.inputtitle = _('Restore backup');
		o.onclick = function(ev, section_id) {
			let input = document.getElementById('widget.cbid.singboxwall.' + section_id + '._restore_path') || document.getElementById('widget.cbid.singboxwall.backup._restore_path');
			let path = input ? input.value : '';
			return sbw.callBackupRestore(path).then(function(res) {
				ui.addNotification(null, E('pre', [ sbw.renderCommandResult(res) ]));
			});
		};

		return m.render();
	}
});
