function handler(event) {
    var request = event.request;
    var uri = request.uri;
    var hasExtension = uri.split('/').pop().includes(".");
    if (!hasExtension) {
        if (!uri.endsWith("/")) {
            uri += "/";
        }
        request.uri = uri + "index.html";
    }
    return request;
}
