part of server_socks;

/**
 * Request handler serving static files.
 */
class StaticHttpRequestHandler extends HttpRequestHandler {

  static Logger _log = new Logger("StaticHttpRequestHandler");

  // Path to directory containing files to be served.
  String _basePath;

  // File name of default document to serve if none is specified in the URL path.
  String defaultDocument;

  // Content type to respond with in the 'Content-Type" header in case the type cannot be determined from the URL path.
  String defaultContentType;

  // Set to true to include the HTTP Content-Length header in all responses and implicitly disable chunked transfer encoding and gzip compression.
  bool setContentLength;

  /**
   * Create static file server serving files in specified directory at [basePath].
   *
   * @param basePath
   *      Path to directory containing files to be served.
   * @param defaultDocument
   *      File name of default document to serve if none is specified in the URL path. Default: "index.html".
   * @param defaultContentType
   *      Content type to respond with in the 'Content-Type" header in case the type cannot be determined from the
   *      URL path. Default: "text/plain; charset=UTF-8".
   * @param setContentLength
   *      Set to true to include the HTTP Content-Length header in all responses and implicitly disable chunked transfer
   *      encoding and gzip compression. Default: false.
   */
  StaticHttpRequestHandler(String basePath, {String this.defaultDocument: "index.html", String this.defaultContentType: "text/plain; charset=UTF-8", bool this.setContentLength: false}) {

    // Remove any trailing slash from base path.
    _basePath = basePath;
    while (_basePath.endsWith(Platform.pathSeparator)) {
      _basePath = _basePath.substring(0, _basePath.length - 1);
    }

    _log.info("Request handler ${runtimeType} serving static files from directory $_basePath.");
  }

  /**
   * Invoked when receiving a request on the HTTP connection.
   *
   * @param requestId
   *      Integer identifying this HTTP request.
   * @param request
   *      The received HTTP request.
   * @return
   *      True if this handler responded to the request.
   */
  bool _onRequest(int requestId, HttpRequest request) {
    if (request.method == "GET") {
      String uriPath = request.uri.path;
      bool emptyPath = uriPath == null || uriPath.length == 0 || uriPath == '/' ;
      String stringPath = (defaultDocument != null && emptyPath) ? '/$defaultDocument' : uriPath;
      stringPath = stringPath.replaceAll("..", "");
      if (Platform.pathSeparator != "/") {
        stringPath = stringPath.replaceAll("/", Platform.pathSeparator);
      }
      HttpResponse response = request.response;
      String path = _basePath + stringPath;
      final File file = new File(path);
      if (file.existsSync()) {
        String mimeType = mime(path);
        if (mimeType == null) mimeType = defaultContentType;
        if (mimeType != null) {
          response.headers.set('Content-Type', mimeType);
        }
        RandomAccessFile openedFile = file.openSync();
        if (setContentLength) {
          response.contentLength = openedFile.lengthSync();
        }
        openedFile.closeSync();
        file.openRead().pipe(response)
        .catchError((e) {
          _log.severe("Failed serving file $stringPath.");
          sendInternalError(request.response);
        });
      }
      else {
        sendNotFound(request.response);
      }
      return true;
    }
    return false;
  }
}