part of server_socks;

/**
 * WebSocket request handler responsible for upgrading the HTTP connection of any received HTTP WebSocket upgrade
 * requests and providing convenience methods for accessing and responding to messages received from connected clients.
 */
class WebSocketRequestHandler extends HttpRequestHandler {

  static Logger _log = new Logger("WebSocketRequestHandler");
  WebSocketRequestHandler() : super();

  /**
   * Invoked upon receiving a message on the WebSocket connection.
   *
   * @param connection
   *      The WebSocket connection on which the message was received.
   * @param message
   *      The received message.
   */
  void _onMessage(WebSocketConnection connection, String message) {
  }

  /**
   * Get the [WebSocketConnection] class to be instantiated upon accepting a client connection.
   *
   * @return
   *      Class mirror referencing [WebSocketConnection] class used by the concrete request handler.
   */
  ClassMirror get connectionClass => reflectClass(WebSocketConnection);

  /**
   * Invoked when a new WebSocket connection is established.
   */
  void _addConnection(WebSocketConnection connection) {
  }

  /**
   * Invoked when a new WebSocket connection is closed.
   */
  void _removeConnection(WebSocketConnection connection) {
  }

  /**
   * Invoked when succeeding in upgrading an HTTP WebSocket upgrade request. Sets up routing of incoming WebSocket
   * messages on the connection to the [_onMessage] method.
   */
  void _handleWebSocketRequests(int connectionId, WebSocket webSocket) {

    // Create WebSocketConnection representing the connection with this client.
    WebSocketConnection connection = connectionClass.newInstance(const Symbol(''), [connectionId, webSocket]).reflectee;
    _log.info(() => "Listening for messages on new WebSocket connection $connectionId upgraded via HTTP request $connectionId.");

    // Add connection as an active connection via this route.
    _addConnection(connection);

    // Add incoming messages to route.
    webSocket.listen((String message) {
      _onMessage(connection, message);
    }, onDone: () {
      _log.info(() => "Client $connectionId was disconnected.");

      // Remove connection from list of active connections for this route.
      _removeConnection(connection);
    });
  }

  /**
   * Invoked when receiving a request on the HTTP connection.
   *
   * @param requestId
   *      Integer identifying this HTTP request.
   * @param request
   *      Received HTTP request.
   * @return
   *      True if this handler responded to the request.
   */
  bool _onRequest(int requestId, HttpRequest request) {

    // Is this an upgrade request?
    if (request.headers.value(HttpHeaders.UPGRADE) == "websocket") {

      // Yes, upgrade connection and route future messages received on this WebSocket.
      _log.info(() => "Processing WebSocket upgrade for HTTP request $requestId.");
      WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
        _handleWebSocketRequests(requestId, webSocket);
      })
      .catchError((error) {

        // It appears [WebSocketTransformer.upgrade] responds with the appropriate HTTP status/message and close the connection, so just log the error here.
        _log.severe(() => "Failed upgrading request $requestId's connection.");
        request.response.close();
      });
      return true;
    }
    return false;
  }
}