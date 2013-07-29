// Olelo bootstrap
// Written by Daniel Mendler
$(function() {
    "use strict";

    $('html').removeClass('no-js').addClass('js');
    function pageLoaded() {
        $('#upload-path', this).each(function() {
            var elem = this;
            var old = elem.value;
            var base = elem.value;
            if (base.length === 0 || base.match(/\/$/)) {
                $('#upload-file').change(function() {
                    if (elem.value == old) {
                        elem.value = base + this.value;
                        old = elem.value;
                    }
                });
            }
        });
        $('label, #menu, .tabhead, .pagination, .button-bar', this).disableSelection();
	$('.date', this).timeAgo();
        $('.tabs', this).each(function() {
	    $('> li', this).tabWidget();
	});
        $('*[accesskey]', this).underlineAccessKey();
    }

    $('#content').pagination('.pagination a');
    $('#content').bind('pageLoaded', pageLoaded);
    pageLoaded.apply($(document));

    $(document).on('click', 'button[data-target]', function() {
	var button = $(this);
	var form = $(this.form);
	button.addClass('loading');
        $.ajax({
            type: form.attr('method') || 'get',
            url:  form.attr('action') || window.location.href,
            data: form.serialize() + '&' + button.attr('name') + '=' + button.attr('value') + '&no_layout=1',
            success: function(data) {
		$('#' + button.data('target')).html(data);
		button.removeClass('loading');
		if (window.MathJax)
		    MathJax.Hub.Queue(['Typeset',MathJax.Hub,button.data('target')]);
            }});
	return false;
    });
});
