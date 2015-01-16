part of client_socks;

/**
 * Client-side plain-text WebSocket connection.
 */
class WebSocketPlainTextConnection extends WebSocketConnection {

  /**
   * Construct and open client-side WebSocket connection with server at specified URI
   *
   * @param uri
   *      The URI to connect to.
   */
  WebSocketPlainTextConnection(String uri) : super(uri);

  /**
   * Open the WebSocket connection.
   */
  Future<WebSocketConnection> open() {
    return _open();
  }

  /**
   * Send a message on this connection.
   *
   * @param message
   *      Message to send to client via the WebSocket connection.
   */
  void send(String message) {
    _webSocket.send(message);
  }

  /**
   * Close the WebSocket connection.
   */
  void close() {
    _close();
  }

  /**
   * Expose stream of open events handled by this [WebSocketPlainTextConnection].
   */
  Stream<CloseEvent> get onClose => _onClose;

  /**
   * Expose stream of message events handled by this [WebSocketPlainTextConnection].
   */
  Stream<MessageEvent> get onMessage => _onMessage;

  /**
   * Expose stream of error events handled by this [WebSocketPlainTextConnection].
   */
  Stream<Event> get onError => _onError;
}