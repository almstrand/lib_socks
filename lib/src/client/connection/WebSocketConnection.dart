part of client_socks;

/**
 * Client-side WebSocket connection.
 */
class WebSocketConnection {

  static Logger _log = new Logger("WebSocketConnection");
  String _uri;

  // Globally unique connection ID.
  WebSocket _webSocket;

  // Completer to receive value upon confirming connection open/failed.
  Completer<WebSocketConnection> _openCompleter;

  // WebSocket onOpen subscription.
  StreamSubscription<Event> _openSubscription;

  // WebSocket onClose subscription.
  StreamSubscription<CloseEvent> _closeSubscription;

  // WebSocket onError subscription.
  StreamSubscription<Event> _errorSubscription;

  // WebSocket onMessage subscription.
  StreamSubscription<Event> _messageSubscription;

  /**
   * Construct and open client-side [WebSocket] connection with server at specified URI.
   *
   * @param _uri
   *      The URI to connect to.
   */
  WebSocketConnection(String this._uri);

  /**
   * Open the WebSocket connection.
   *
   * @return
   *      Future completed with reference to this connection upon successfully establishing [WebSocket]
   *      connection, or completed with a [WebSocketException] instance upon error.
   */
  Future<WebSocketConnection> _open() {

    // Ensure connection not opened twice
    if (_openCompleter != null) {
      return new Future.error(new WebSocketException("Prior connection must be closed before calling _open()."));
    }

    // Create completer to receive value when succeeding or failing in opening connection.
    _openCompleter = new Completer<WebSocketConnection>();

    // Instantiate the WebSocket class to trigger connection to be established.
    _log.info(() => "Establishing WebSocket connection with  $_uri.");
    _webSocket = new WebSocket(_uri);

    // Listen for WebSocket's onOpen events occurring while opening the connection.
    _openSubscription = _webSocket.onOpen.listen((Event event) {
      _log.info(() => "Established WebSocket connection with $_uri.");

      // Cancel all WebSocket event subscriptions that were in effect (only) while establishing a connection.
      _cancelSubscriptions();

      // Log any future WebSocket.onError event on this connection.
      _errorSubscription = _webSocket.onError.listen((Event event) {
        _log.severe(() => "Received WebSocket 'error' event for connection with $_uri");
      });

      // Log any future WebSocket.onClose event on this connection, then cancel all subscriptions.
      _closeSubscription = _webSocket.onClose.listen((CloseEvent event) {
        _log.info(() => "Received WebSocket 'closed' event for connection with $_uri.");
        _openCompleter = null;
        _cancelSubscriptions();
      });

      // Log any future WebSocket.onMessage event on this connection.
      _messageSubscription = _webSocket.onMessage.listen((MessageEvent event) {
        _log.info(() => "Received WebSocket message from $_uri: [${shared.Logging.stripNewLinesAndLimitLength(event.data)}]");
      });

      // We are done opening the connection.
      _openCompleter.complete(this);
    });

    // Listen for WebSocket's onError events occurring while opening the connection.
    _errorSubscription = _webSocket.onError.listen((Event event) {
      String errText = "Received WebSocket 'error' event while establishing connection with $_uri.";
      _log.severe(errText);
      _cancelSubscriptions();
      _openCompleter.completeError(new WebSocketException(errText));
    });

    // Listen for WebSocket's onClose events occurring while opening the connection.
    _closeSubscription = _webSocket.onClose.listen((CloseEvent event) {
      String errText = "Received WebSocket 'closed' event while establishing connection with $_uri.";
      _log.severe(errText);
      _cancelSubscriptions();
      _openCompleter.completeError(new WebSocketException(errText));
    });

    return _openCompleter.future;
  }

  /**
   * Cancel any WebSocket subscriptions.
   */
  void _cancelSubscriptions() {
    if (_openSubscription != null) {
      _openSubscription.cancel();
      _openSubscription = null;
    }
    if (_closeSubscription != null) {
      _closeSubscription.cancel();
      _closeSubscription = null;
    }
    if (_errorSubscription != null) {
      _errorSubscription.cancel();
      _errorSubscription = null;
    }
    if (_messageSubscription != null) {
      _messageSubscription.cancel();
      _messageSubscription = null;
    }
  }

  /**
   * Throw exception in case connection not opened and we try to call method that requires an open WebSocket.
   *
   * @throws WebSocketException
   *      If WebSocket connection is not open.
   */
  void _ensureOpened() {
    if (_openCompleter == null || !_openCompleter.isCompleted) {
      throw new WebSocketException("Operation failed as the WebSocket connection is not open.");
    }
  }

  /**
   * Send a message on this connection.
   *
   * @param message
   *      Message to send to client via the WebSocket connection.
   * @throws WebSocketException
   *      If WebSocket connection is not open.
   */
  void _send(String message) {
    _ensureOpened();
    _log.info(() => "Sending WebSocket message to $_uri: [${shared.Logging.stripNewLinesAndLimitLength(message)}]");
    _webSocket.send(message);
  }

  /**
   * Close the WebSocket connection with the client.
   */
  void _close() {
    _webSocket.close();
  }

  /**
   * Get Stream of open events handled by this [WebSocketConnection].
   *
   * @return
   *      Stream receiving [WebSocket.CloseEvent] references upon the WebSocket connection closing.
   * @throws WebSocketException
   *      If WebSocket connection is not open.
   */
  Stream<CloseEvent> get _onClose {
    _ensureOpened();
    return _webSocket.onClose;
  }

  /**
   * Get Stream of message events handled by this [WebSocketConnection].
   *
   * @throws WebSocketException
   *      If WebSocket connection is not open.
   */
  Stream<MessageEvent> get _onMessage {
    _ensureOpened();
    return _webSocket.onMessage;
  }

  /**
   * Get Stream of error events handled by this [WebSocketConnection].
   *
   * @return
   *      Stream receiving [Event] references upon receiving a message on the WebSocket connection.
   * @throws WebSocketException
   *      If WebSocket connection is not open.
   */
  Stream<Event> get _onError {
    _ensureOpened();
    return _webSocket.onError;
  }

  String get uri => _uri;
}