// Replace timestamps with relative time
// Written by Daniel Mendler
(function($) {
    $.translations({
         en: {
              less_than_a_minute_ago: 'less than a minute ago',
              a_minute_ago:           'a minute ago',
              n_minutes_ago:          '#{n} minutes ago',
              one_hour_ago:           '1 hour ago',
              n_hours_ago:            '#{n} hours ago',
              one_day_ago:            '1 day ago',
              n_days_ago:             '#{n} days ago',
              one_month_ago:          '1 month ago',
              n_months_ago:           '#{n} months ago',
              one_year_ago:           '1 year ago',
              over_n_years_ago:       'over #{n} years ago'
         },
         de: {
              less_than_a_minute_ago: 'vor weniger als einer Minute',
              a_minute_ago:           'vor einer Minute',
              n_minutes_ago:          'vor #{n} Minuten',
              one_hour_ago:           'vor einer Stunde',
              n_hours_ago:            'vor #{n} Stunden',
              one_day_ago:            'vor einem Tag',
              n_days_ago:             'vor #{n} Tagen',
              one_month_ago:          'vor einem Monat',
              n_months_ago:           'vor #{n} Monaten',
              one_year_ago:           'vor einem Jahr',
              over_n_years_ago:       'vor über #{n} Jahren'
         },
         cs: {
              less_than_a_minute_ago: 'méně než 1 minuta',
              a_minute_ago:           'před minutou',
              n_minutes_ago:          'před #{n} minutami',
              one_hour_ago:           'před hodinou',
              n_hours_ago:            'před #{n} hodinami',
              one_day_ago:            'jeden den',
              n_days_ago:             'před #{n} dny',
              one_month_ago:          'jeden měsíc',
              n_months_ago:           'před #{n} měsíci',
              one_year_ago:           '1 rok',
              over_n_years_ago:       'před #{n} lety'
         }        
    });

    function timeAgo(from) {
	var n = Math.floor((new Date().getTime()  - new Date(from * 1000)) / 60000);
	if (n <= 0)      { return $.t('less_than_a_minute_ago'); }
	if (n == 1)      { return $.t('a_minute_ago'); }
	if (n < 45)      { return $.t('n_minutes_ago', {n: n}); }
	if (n < 90)      { return $.t('one_hour_ago'); }
	if (n < 1440)    { return $.t('n_hours_ago', {n: Math.round(n / 60)}); }
	if (n < 2880)    { return $.t('one_day_ago'); }
	if (n < 43200)   { return $.t('n_days_ago', {n: Math.round(n / 1440)}); }
	if (n < 86400)   { return $.t('one_month_ago'); }
	if (n < 525960)  { return $.t('n_months_ago', {n: Math.round(n / 43200)}); }
	if (n < 1051920) { return $.t('one_year_ago'); }
	return $.t('over_n_years_ago', {n: Math.round(n / 525960)});
    }

    $.fn.timeAgo = function() {
	this.each(function() {
	    var elem = $(this);
            var epoch = elem.data('epoch');
	    if (epoch) {
		elem.attr('title', elem.text()).html(timeAgo(epoch));
	    }
	});
    };
})(jQuery);
