(function() {
    const links = document.querySelectorAll('a[href="<url>"]');
    if (links.length > 0) {
        links[0].click();
    } else {
        const a = document.createElement('a');
        a.href = '<url>';
        a.download = '';
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        setTimeout(() => document.body.removeChild(a), 100);
    }
})();