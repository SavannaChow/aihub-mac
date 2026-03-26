(function() {
    if (typeof navigator.share === 'function') {
        const originalShare = navigator.share;
        navigator.share = function(data) {
            try {
                AndroidWebShare.share(data.title || '', data.text || '', data.url || '');
                return Promise.resolve();
            } catch(e) {
                return Promise.reject(e);
            }
        };
    } else {
        navigator.share = function(data) {
            try {
                AndroidWebShare.share(data.title || '', data.text || '', data.url || '');
                return Promise.resolve();
            } catch(e) {
                return Promise.reject(e);
            }
        };
    }
})();