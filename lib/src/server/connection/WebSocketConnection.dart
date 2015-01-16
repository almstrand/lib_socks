part of server_socks;

/**
 * Represents a server-side WebSocket connection.
 */
class WebSocketConnection {

  static Logger _log = new Logger("WebSocketConnection");

  // Identifies this client connection.
  int _id;

  // WebSocket instance wrapped by ths connection class.
  final WebSocket _webSocket;

  /**
   * Construct server-side WebSocket connection.
   *
   * @param _id
   *      Integer identifying this connection.
   * @param _webSocket
   *      WebSocket instance wrapped by ths connection class.
   */
  WebSocketConnection(int this._id, WebSocket this._webSocket);

  /**
   * Send a message on this connection.
   *
   * @param message
   *      Message to send to client via the WebSocket connection.
   * @throws exception
   *      Should not, but may throw exception when invoking [WebSocket.add]
   *      (e.g. https://code.google.com/p/dart/issues/detail?id=11952).
   */
  void send(String message) {
    _log.info(() => "Sending WebSocket message on connection $_id: [${shared.Logging.stripNewLinesAndLimitLength(message)}]");
    _webSocket.add(message);
  }

  /**
   * Close the WebSocket connection with the client.
   */
  void close() {
    _webSocket.close();
  }

  /**
   * Get unique ID of this connection.
   */
  int get id => _id;
}