$(function() {
    "use strict";

    function initFancybox() {
        $('a.fancybox').each(function() {
            var href = this.href.replace(/aspect=\w+/g, '');
            this.href = href + (href.indexOf('?') < 0 ? '?' : '&') + 'aspect=image&geometry=800x800>';
        });
        $('a.fancybox').fancybox();
    }

    $('#content').bind('pageLoaded', initFancybox);
    initFancybox();
});
