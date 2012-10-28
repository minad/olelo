$(function() {
    // Add treeview translations
    $.translations({
	en: {
	    menu: 'Menu',
	    tree: 'Tree'
	},
	de: {
	    menu: 'Menü',
	    tree: 'Baumansicht'
	},
	cs: {
	    menu: 'Menu',
	    tree: 'Strom'
	},
	fr: {
	    menu: 'Menu',
	    tree: 'Arbre'
	}
    });

    // Start tree view
    $('#sidebar').wrapInner('<div id="sidebar-menu"/>').prepend('<div id="sidebar-tree" style="display: none"><h1>' + $.t('tree') +
								'</h1><div id="treeview"/></div>');
    $('#menu').prepend('<ul><li class="selected" id="sidebar-tab-menu"><a href="#sidebar-menu">' + $.t('menu') +
                       '</a></li><li id="sidebar-tab-tree"><a href="#sidebar-tree">' + $.t('tree') + '</a></li></ul>');
    $('#sidebar-tab-menu, #sidebar-tab-tree').tabWidget({store: 'sidebar-tab'});
    $('#treeview').treeView({stateStore: 'treeview-state', cacheStore: 'treeview-cache', root: Olelo.base_path, ajax: function(path, success, error) {
	$.ajax({url: path, data: { aspect: 'treeview' }, success: success, error: error, dataType: 'json'});
    }});
});
