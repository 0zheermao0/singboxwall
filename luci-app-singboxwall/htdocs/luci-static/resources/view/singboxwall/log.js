'use strict';
'require view';
'require form';
'require singboxwall.common as sbw';
/* global sbw */

return view.extend({
	load: function() { return Promise.all([ sbw.callTailLog(200) ]); },
	render: function(data) {
		let log = (data[0] && data[0].log) || '';
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', _('SingBoxWall Log')),
			E('div', { 'class': 'cbi-section' }, [
				E('pre', { 'style': 'white-space: pre-wrap; max-height: 60vh; overflow: auto;' }, [ log || _('No log output.') ])
			])
		]);
	},
	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
