(function($) {
    'use strict';
    var getForward = function($element) {
        var forward = [];
        var data = $element.data();
        for (var key in data) {
            if (key.startsWith("forward-")) {
                var target = key.slice(8);
                var source = $("#" + data[key]).val();
                forward.push(source);
                forward.push(target.toLowerCase());
            }
        }
        return forward.join("|");
    };

    var init = function($element, options) {
        var settings = $.extend({
            ajax: {
                data: function(params) {
                    return {
                        term: params.term,
                        page: params.page,
                        forward: getForward($element)
                    };
                }
            }
        }, options);
        $element.select2(settings);
    };

    $.fn.djangoAdminSelect2 = function(options) {
        var settings = $.extend({}, options);
        $.each(this, function(i, element) {
            var $element = $(element);
            init($element, settings);
        });
        return this;
    };

    $(function() {
        // Initialize all autocomplete widgets except the one in the template
        // form used when a new formset is added.
        $('.admin-autocomplete').not('[name*=__prefix__]').djangoAdminSelect2();
    });

    $(document).on('formset:added', (function() {
        return function(event, $newFormset) {
            return $newFormset.find('.admin-autocomplete').djangoAdminSelect2();
        };
    })(this));
}(django.jQuery));
