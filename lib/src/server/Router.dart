part of server_socks;

/**
 * Routes HTTP requests to registered handlers.
 */
class Router {

  static Logger _log = new Logger("Router");
  static int _REQUEST_ID_SEQUENCE_GENERATOR = 0;
  List<HttpRequestHandler> _requestHandlers = new List<HttpRequestHandler>();
  bool _send404;

  /**
   * Construct router.
   *
   * @param send404
   *      Set to true to respond with HTTP status 404 upon all request handlers failing to process a given request.
   */
  Router({bool send404: true}) {
    _send404 = send404;
  }

  /**
   * Add request handler.
   *
   * @param requestHandler
   *      Request handler.
   */
  void addRequestHandler(HttpRequestHandler requestHandler) {
    _log.info(() => "Adding request handler ${requestHandler.runtimeType.toString()}.");
    _requestHandlers.add(requestHandler);
  }

  /**
   * Route HTTP request.
   *
   * @return Future referencing boolean value specifying whether a route exists to handle the request.
   */
  Future<bool> handleRequest(HttpRequest httpRequest) {

    // Assign unique request ID
    int requestId = ++_REQUEST_ID_SEQUENCE_GENERATOR;
    String path = httpRequest.uri.path;
    _log.info(() => "Received HTTP ${httpRequest.method} request $requestId targeting $path.");

    // Forward request to first handler matching the URI path
    int numRequestHandlers = _requestHandlers.length;
    for (int requestHandlerIndex = 0; requestHandlerIndex < numRequestHandlers; requestHandlerIndex++) {
      HttpRequestHandler requestHandler = _requestHandlers[requestHandlerIndex];
      if (requestHandler._onRequest(requestId, httpRequest)) {
        return new Future.value(true);
      }
    }

    // Optionally respond with HTTP 404 if no route matched request path
    if (_send404) {
      _log.warning(() => "No route registered to handle HTTP request $requestId.");
      httpRequest.response.statusCode = HttpStatus.NOT_FOUND;
      httpRequest.response.reasonPhrase = "Not found";
      httpRequest.response.close();
      return new Future.value(true);
    }

    // Signal failure to process request
    return new Future.value(false);
  }

}