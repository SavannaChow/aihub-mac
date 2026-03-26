(function() {
  if (window.__blobInterceptorInjected) {
    return;
  }
  window.__blobInterceptorInjected = true;
  if (!window.__blobStorage) {
    window.__blobStorage = new Map();
  }
  const originalCreateObjectURL = window.URL.createObjectURL;
  window.URL.createObjectURL = function(blob) {
    const blobUrl = originalCreateObjectURL(blob);
    window.__blobStorage.set(blobUrl, blob);
    return blobUrl;
  };
  function downloadBlob(blobUrl, filename) {
    const blob = window.__blobStorage.get(blobUrl);
    if (blob) {
      const reader = new FileReader();
      reader.onload = function() {
        let base64 = reader.result;
        if (base64.includes(',')) {
          base64 = base64.split(',')[1];
        }
        AndroidBlobHandler.saveBase64File(base64, filename, blob.type);
      };
      reader.onerror = function(error) {
        AndroidBlobHandler.downloadFailed('Failed to read blob');
      };
      reader.readAsDataURL(blob);
    } else {
      AndroidBlobHandler.downloadFailed('Blob reference lost');
    }
  }
  document.addEventListener('click', function(e) {
    const link = e.target.closest('a[href]');
    if (link && link.href && link.href.startsWith('blob:')) {
      e.preventDefault();
      e.stopPropagation();
      const filename = link.getAttribute('download') ||
                     link.href.split('/').pop() ||
                     'download';
      downloadBlob(link.href, filename);
    }
  }, true);
  const originalCreateElement = document.createElement;
  document.createElement = function(tagName, options) {
    const element = originalCreateElement.call(document, tagName, options);
    if (tagName.toLowerCase() === 'a') {
      const originalSetAttribute = element.setAttribute;
      element.setAttribute = function(name, value) {
        if (name === 'href' && value && value.startsWith('blob:')) {
          element._blobUrl = value;
        }
        return originalSetAttribute.call(this, name, value);
      };
      const originalClick = element.click;
      element.click = function() {
        if (element._blobUrl) {
          const filename = element.getAttribute('download') || 'download';
          downloadBlob(element._blobUrl, filename);
          return;
        }
        originalClick.call(this);
      };
    }
    return element;
  };
})();