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
    }
});

// Start tree view
$('#sidebar').wrapInner('<div id="sidebar-menu"/>').prepend('<div id="sidebar-tree" style="display: none"><h1>' + $.t('tree') +
                                                            '</h1><div id="treeview"/></div>');
$('#menu > ul:first').prepend('<li class="selected" id="sidebar-tab-menu"><a href="#sidebar-menu">' + $.t('menu') +
                              '</a></li><li id="sidebar-tab-tree"><a href="#sidebar-tree">' + $.t('tree') + '</a></li>');
$('#sidebar-tab-menu, #sidebar-tab-tree').tabWidget({store: 'sidebar-tab'});
$('#treeview').treeView({stateStore: 'treeview-state', cacheStore: 'treeview-cache', ajax: function(path, success, error) {
    $.ajax({url: path, data: { aspect: 'treeview.json' }, success: success, error: error, dataType: 'json'});
}});
