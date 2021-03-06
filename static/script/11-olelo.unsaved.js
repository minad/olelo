(function($) {
    "use strict";

    // Add treeview translations
    $.translations({
	en: {
	    confirmUnsaved: 'The page was not saved. Continue?',
	    pageUnsaved: 'The page was not saved.'
	},
	de: {
	    confirmUnsaved: 'Die Seite wurde nicht gespeichert. Fortsetzen?',
	    pageUnsaved: 'Die Seite wurde nicht gespeichert.'
	},
 	cs: {
	    confirmUnsaved: 'Stránka nebyla uložena. Pokračovat?',
	    pageUnsaved: 'Stránka nebyla uložena.'
	},
	fr: {
	    confirmUnsaved: "La page n'a pas été enregistrée. Voulez vous continuer ?",
	    pageUnsaved: "La page n'a pas été enregistrée."
	}
    });

    function updateUnsaved() {
	var unsaved = false;
	switch (this.type) {
	case 'checkbox':
	case 'radio':
	    unsaved = this.checked != this.defaultChecked;
	    break;
	case 'hidden':
	case 'password':
	case 'text':
	case 'textarea':
	case 'file':
	    unsaved = this.value != this.defaultValue;
	    break;
	case 'select-one':
	case 'select-multiple':
	    for (var i = 0; i < this.options.length && !unsaved; ++i) {
                unsaved = this.options[i].selected != this.options[i].defaultSelected;
	    }
	    break;
	}
	$('label[for=' + this.id + ']').toggleClass('unsaved', unsaved);
	$(this).toggleClass('unsaved', unsaved);
    }

    function hasUnsavedChanges(element) {
	$('input.observe, textarea.observe, select.observe').each(function() {
	    updateUnsaved.call(this);
	});
	return $('.unsaved', element).size() !== 0;
    }

    $.fn.confirmUnsaved = function() {
	return !hasUnsavedChanges(this) || confirm($.t('confirmUnsaved'));
    };

    $(document).on('change autocompletechange', 'input.observe, textarea.observe, select.observe', updateUnsaved);

    var submitForm = false;
    $(document).on('submit', 'form', function() {
	submitForm = true;
    }).bind('reset', function() {
	$('.unsaved', this).removeClass('unsaved');
    });

    $(window).bind('beforeunload', function() {
	if (!submitForm && hasUnsavedChanges(document)) {
	    return $.t('pageUnsaved');
	}
    });
})(jQuery);
