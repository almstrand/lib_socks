part of client_socks;

/**
 * Client-side STOMP 1.2 WebSocket connection.
 */
class WebSocketStompConnection extends WebSocketConnection {

  static Logger _log = new Logger("WebSocketStompConnection");

  // Set to true while STOMP 1.2 connection has been established.
  bool _isStompConnected = false;

  // Name of a virtual host that the client wishes to connect to (i.e. the 'host' header value.)
  String _host;

  // Smallest guaranteed number of milliseconds between frames sent to server, or 0 if this implementation cannot
  // guarantee such minimum heart-beat interval.
  int _guaranteedHeartBeat;

  // Desired number of milliseconds between frames received by server, or 0 if this implementation does not want to
  // receive frames at such minimum heart-beat interval.
  int _desiredHeartBeat;

  // Maximum limit on the number of frame headers allowed in a single frame.
  int maxFrameHeaders;

  // Maximum length of header lines, expressed in number of characters.
  int maxHeaderLen;

  // Maximum size of a frame body, expressed in number of characters. An error frame will be sent to clients exceeding
  // this limit, followed by closing the client connection. Set to null to impose no limit.
  int maxBodyLen;

  // Controller used to submit error events upon detecting problems with the WebSocket connection or failing to process
  // events.
  StreamController<shared.StompException> _onStompErrorStreamController = new StreamController<shared.StompException>.broadcast();

  // Controller used to submit events upon the STOMP connection closing.
  StreamController<bool> _onStompConnectionClosedController = new StreamController<bool>.broadcast();

  // Stream subscription for WebSocket message events.
  StreamSubscription<MessageEvent> _webSocketMessageSubscription;

  // Stream subscription for WebSocket error events.
  StreamSubscription<MessageEvent> _webSocketErrorSubscription;

  // Stream subscription for WebSocket close events.
  StreamSubscription<CloseEvent> _webSocketCloseSubscription;

  // Maps receipt IDs and completers. This allows client to track which completer to complete upon receiving a STOMP
  // frame from the server referencing a particular receipt ID.
  Map<String, Completer<shared.Frame>> _pendingFrameCompleters = new Map<String, Completer<shared.Frame>>();

  // Completer to be completed with reference to CONNECTED frame upon successfully establishing a STOMP connection with
  // server, or a StompException instance upon detecting an error preventing the CONNECT frame from establishing a STOMP
  // server connection.
  Completer<shared.Frame> _pendingConnectCompleter;

  // Receipt ID sequence generator.
  int _nextReceiptId = 0;

  // Transaction ID sequence generator.
  int _nextTransactionId = 0;

  // Subscription ID sequence generator.
  int _nextSubscriptionId = 0;

  // List of all active subscriptions by this client.
  List<StompSubscription> _subscriptions = new List<StompSubscription>();

  /**
   * Construct and open client-side WebSocket connection with server at specified URI.
   *
   * @param uri
   *      URI to connect to.
   * @param host
   *      Name of a virtual host that the client wishes to connect to (i.e. the 'host' header value.)
   *      It is recommended clients set this to the host name that the socket was established against, or to any name
   *      of their choosing. If this header does not match a known virtual host, servers supporting virtual hosting
   *      may select a default virtual host or reject the connection.
   * @param guaranteedHeartBeat
   *      Smallest guaranteed number of milliseconds between frames sent to server, or null (default) if this
   *      implementation cannot guarantee such minimum heart-beat interval.
   * @param desiredHeartBeat
   *      Desired number of milliseconds between frames received from server, or null (default) if this
   *      implementation does not want to receive frames at such minimum heart-beat interval.
   * @param maxFrameHeaders
   *      Maximum limit on the number of frame headers allowed in a single frame. Set to null to impose
   *      no limit.
   * @param maxHeaderLen
   *      Maximum length of header lines, expressed in number of characters. Set to null to impose no limit.
   * @param maxBodyLen
   *      Maximum size of a frame body, expressed in number of characters. Set to null to impose no limit.
   */
  WebSocketStompConnection(String uri, String host, {int guaranteedHeartBeat, int desiredHeartBeat, int this.maxFrameHeaders, int this.maxHeaderLen, int this.maxBodyLen}) : super(uri) {
    _host = host;

    // Stash heart-beat settings.
    _guaranteedHeartBeat = (guaranteedHeartBeat == null ? 0 : guaranteedHeartBeat);
    _desiredHeartBeat = (desiredHeartBeat == null ? 0 : desiredHeartBeat);
  }

  /**
   * Open the WebSocket connection and create STOMP connection.
   *
   * @return
   *      Future referencing this connection upon success or a StompException upon encountering an error
   *      while opening the Socket connection or connecting to the STOMP server.
   */
  Future<WebSocketStompConnection> _connect() {
    _log.info(() => "Establishing STOMP connection with $_uri.");

    // Open WebSocket connection
    Completer<WebSocketStompConnection> _connectedCompleter = new Completer<WebSocketStompConnection>();
    _open().then((WebSocketConnection event) {
      _log.info(() => "Established STOMP connection with $_uri.");

      // Process WebSocket message, error, and close events.
      _log.info(() => "Listening for messages, errors, and close events on WebSocket connection with $_uri.");
      _listenForMessages();
      _listenForWebSocketErrors();
      _listenForWebSocketClosing();

      // We opened the connection, so proceed by sending the CONNECT frame.
      _log.info(() => "Establishing STOMP connection with $_uri.");
      shared.ConnectFrame connectFrame = new shared.ConnectFrame.fromParams(shared.Version.VERSION_1_2, _host);
      _sendFrame(connectFrame)
      .then((shared.ConnectedFrame connectedFrame) {
        _log.info(() => "Established STOMP connection with $_uri for session ${connectedFrame.session}.");

        // Complete future referencing this [WebSocketStompConnection] instance.
        _connectedCompleter.complete(this);
      })
      .catchError((shared.StompException stompException) {
        _log.severe(() => "Failed establishing STOMP connection with $_uri: ${stompException.summary} (${stompException.details})");
        _connectedCompleter.completeError(stompException);
        _close();
      });
    })
    .catchError((webSocketException) {
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "WebSocket connection failed", details: "Failed establishing WebSocket connection with ${_uri}: ${webSocketException.toString()}");
      _connectedCompleter.completeError(stompException);
    }, test: (e) => e is WebSocketException)
    .catchError((stompException) {
      _connectedCompleter.completeError(stompException);
    }, test: (e) => e is shared.StompException);

    // Return future.
    return _connectedCompleter.future;
  }

  /**
   * Listen and parse incoming WebSocket messages, then add events to corresponding stream.
   *
   * @throws
   *      StompException upon failing to access WebSocket.onMessage stream.
   */
  void _listenForMessages() {

    // Access WebSocket onMessage stream.
    Stream<MessageEvent> onMessageStream;
    try {
      onMessageStream = _onMessage;
    }
    catch (error) {
      String errorMessage = "Error accessing WebSocket.onMessage stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "WebSocket message stream access error", details: errorMessage);
      throw stompException;
    }

    // Listen for WebSocket messages.
    _webSocketMessageSubscription = onMessageStream.listen((MessageEvent messageEvent) {

      try {

        // Construct a frame from the received message.
        String message = messageEvent.data;
        shared.Frame frame = new shared.Frame.fromMessage(message, maxFrameHeaders: maxFrameHeaders, maxHeaderLen: maxHeaderLen, maxBodyLen: maxBodyLen);

        // Add event to stream representing type of frame received.
        shared.StompException stompException;
        switch (frame.command) {
          case "CONNECTED":
            stompException = _onConnectedFrame(frame);
            break;
          case "MESSAGE":
            _onMessageFrame(frame)
            .then((_) {
            })
            .catchError((shared.StompException stompException) {
              _log.severe(() => "Caught exception while processing received STOMP MESSAGE frame: ${stompException.summary} (${stompException.details})");
              _onStompErrorStreamController.add(stompException);
              _close();
            })
            .catchError((error) {
              String errStr = "Subscriptions' 'onMessage' implementations must complete with an error referencing a StompException instance upon failing to process messages.";
              _log.severe(errStr);
              shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_NOT_IMPLEMENTED, "Bad implementation", details: errStr, frame: frame.frame, receiptId: frame.receipt);
              _onStompErrorStreamController.add(stompException);
              _close();
            });
            break;
          case "RECEIPT":
            stompException = _onReceiptFrame(frame);
            break;
          case "ERROR":
            _onErrorFrame(frame);
            break;
          default:
            stompException = new shared.StompException(shared.StompException.ERROR_CODE_UNEXPECTED_FRAME, "Unexpected frame", details: "Un-supported command ${frame.command} received from server.", receiptId: frame.receipt, frame: message);
            break;
        }

        // Add error to stream if failed to process the received message.
        if (stompException != null) {
          _log.severe(() => "Caught error while processing received STOMP ${frame.command} frame: ${stompException.summary} (${stompException.details})");
          _onStompErrorStreamController.add(stompException);
        }
      }
      on shared.StompException catch (stompException) {
        _log.severe(() => "Caught unexpected error while parsing received STOMP frame: ${stompException.summary} (${stompException.details})");
        _onStompErrorStreamController.add(stompException);
        _close();
      }
    });

    // Log any errors occurring on WebSocket.onMessage stream.
    _webSocketMessageSubscription.onError((error) {
      String errorMessage = "Received error on WebSocket.onMessage stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Received error on WebSocket.onMessage stream", details: errorMessage);
      _onStompErrorStreamController.add(stompException);
    });
  }

  /**
   * Forward WebSocket errors to STOMP error stream, to consolidate errors into a single stream for
   * all error events.
   *
   * @throws
   *      StompException upon failing to access WebSocket.onError stream.
   */
  void _listenForWebSocketErrors() {

    // Access WebSocket onError stream.
    Stream<Event> onErrorStream;
    try {
      onErrorStream = _onError;
    }
    catch (error) {
      String errorMessage = "Error accessing WebSocket.onError stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "WebSocket error stream access error", details: errorMessage);
      throw stompException;
    }

    // Listen for WebSocket messages.
    _webSocketErrorSubscription = onErrorStream.listen((Event errorEvent) {
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Received WebSocket error", details: "A WebSocket error occurred.");
      _onStompErrorStreamController.add(stompException);
    });

    // Log any errors occurring on WebSocket.onMessage stream.
    _webSocketErrorSubscription.onError((error) {
      String errorMessage = "Received error on WebSocket.onError stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Received error on WebSocket.onError stream", details: errorMessage);
      _onStompErrorStreamController.add(stompException);
    });
  }

  /**
   * Cancel all WebSocket subscriptions (i.e. open, close message, and error events.)
   */
  void _unsubscribeWebSocketEvents() {
    if (_webSocketCloseSubscription != null) {
      _webSocketCloseSubscription.cancel();
      _webSocketCloseSubscription = null;
    }
    if (_webSocketMessageSubscription != null) {
      _webSocketMessageSubscription.cancel();
      _webSocketMessageSubscription = null;
    }
    if (_webSocketErrorSubscription != null) {
      _webSocketErrorSubscription.cancel();
      _webSocketErrorSubscription = null;
    }
  }

  /**
   * Complete pending commands with errors upon closing the STOMP connection or WebSocket connection.
   *
   * @throws
   *      StompException upon failing to access WebSocket.onClose stream.
   */
  void _listenForWebSocketClosing() {

    // Access WebSocket onClose stream.
    Stream<CloseEvent> onCloseStream;
    try {
      onCloseStream = _onClose;
    }
    catch (error) {
      String errorMessage = "Error accessing WebSocket.onClose stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "WebSocket close stream access error", details: errorMessage);
      throw stompException;
    }

    // Listen for WebSocket "close" events.
    _webSocketCloseSubscription = onCloseStream.listen((CloseEvent closeEvent) {
      _log.info(() => "Cancelling WebSocket event subscriptions.");

      // Cancel all WebSocket subscriptions (i.e. open, close message, and error events.)
      _unsubscribeWebSocketEvents();

      // Signal that all STOMP subscriptions on this connection are un-subscribed, and clear the list of STOMP subscriptions.
      _subscriptions.forEach((StompSubscription subscription) {
        subscription._onCancelled(true);
      });
      _subscriptions.clear();

      // Complete pending commands with error.
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_CLOSED, "Missing receipt of frame delivery", details: "Failed confirming that pending command was successfully processed by $_uri due to WebSocket connection unexpectedly closing.");
      if (_pendingConnectCompleter != null) {
        _log.warning(() => "Completing pending STOMP connections to $_uri with error as WebSocket connection is unexpectedly closing.");
        _pendingConnectCompleter.completeError(stompException);
        _pendingConnectCompleter = null;
      }
      _pendingFrameCompleters.forEach((String receiptId, Completer<shared.Frame> pendingFrameCompleter) {
        _log.warning(() => "Completing pending command with receipt ${receiptId} targeting $_uri with error as WebSocket connection is unexpectedly closing.");
        pendingFrameCompleter.completeError(stompException);
      });
      _pendingFrameCompleters.clear();

      _log.info(() => "Closing STOMP error stream.");
      _onStompErrorStreamController.close();

      // Signal connection closed.
      _onStompConnectionClosedController.add(true);
      _onStompConnectionClosedController.close();
    });

    // Log any errors occurring on WebSocket.onClose stream.
    _webSocketCloseSubscription.onError((error) {
      String errorMessage = "Received error on WebSocket.onClose stream" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errorMessage);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Received error on WebSocket.onClose stream", details: errorMessage);
      _onStompErrorStreamController.add(stompException);
    });
  }

  /**
   * If requested per specified subscription's acknowledgement settings, send ACK frame to signal server that client
   * successfully processed a STOMP MESSAGE frame.
   */
  void _sendAck(StompSubscription subscription, String messageId) {
    String subscriptionId;
    String destination;
    if (subscription != null) {
      subscriptionId = subscription.id;
      destination = subscription.destination;
      _log.info(() => "Sending STOMP ACK frame to signal successful processing of message $messageId received via subscription $subscriptionId to destination $destination.");
    }
    else {
      _log.info(() => "Sending STOMP ACK frame to signal successful processing of message $messageId received via unspecified subscription.");
    }
    if (subscription == null || subscription.usesAck) {
      shared.AckFrame ackFrame = new shared.AckFrame.fromParams(messageId);
      _sendFrame(ackFrame, withReceipt: false);
    }
  }

  /**
   * If requested per specified subscription's acknowledgement settings, send NACK frame to signal server that client
   * failed in processing a STOMP MESSAGE frame.
   */
  void _sendNack(StompSubscription subscription, String messageId) {
    String subscriptionId;
    String destination;
    if (subscription != null) {
      subscriptionId = subscription.id;
      destination = subscription.destination;
      _log.warning(() => "Sending STOMP NACK frame to signal failure in processing message received via subscription $subscriptionId to destination $destination.");
    }
    else {
      _log.warning(() => "Sending STOMP NACK frame to signal failure in processing message received via unspecified subscription.");
    }
    if (subscription == null || subscription.usesAck) {
      shared.NackFrame nackFrame = new shared.NackFrame.fromParams(messageId);
      _sendFrame(nackFrame, withReceipt: false);
    }
  }

  /**
   * Process CONNECTED frame received from server.
   *
   * @param connectedFrame
   *      CONNECTED frame received from server.
   *
   * @return
   *      StompException upon failing to process the frame.
   */
  shared.StompException _onConnectedFrame(shared.ConnectedFrame connectedFrame) {

    // Send event if not expecting a CONNECTED frame.
    if (_pendingConnectCompleter == null) {
      _log.severe(() => "Received un-expected STOMP CONNECTED frame from servet at $_uri.");
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_UNEXPECTED_FRAME, "Unexpected frame", details: "Received un-expected STOMP CONNECTED frame.", receiptId: connectedFrame.receipt, frame: connectedFrame.frame);
      return stompException;
    }

    // Determine the interval at which this client must send heart-beat frames (frames of any kind) to the server.
    _log.info(() => "Received STOMP CONNECTED frame from $_uri in response to sent CONNECT frame.");
    int clientToServerHeartBeatInterval;
    int serverDesiredHeartBeat = connectedFrame.desiredHeartBeat;
    if (_guaranteedHeartBeat == 0 || serverDesiredHeartBeat == 0) {
      clientToServerHeartBeatInterval = 0;
    }
    else {
      clientToServerHeartBeatInterval = max(_guaranteedHeartBeat, serverDesiredHeartBeat);
    }

    // Complete completer waiting for this CONNECTED frame confirming the server has successfully established a connection in response to the CONNECT frame we sent previously.
    _pendingConnectCompleter.complete(connectedFrame);
    _pendingConnectCompleter = null;
    return null;
  }

  /**
   * Process MESSAGE frame received from server.
   *
   * @param messageFrame
   *      MESSAGE frame received from server.
   *
   * @return
   *      Future referencing the STOMP MESSAGE frame upon successfully processing the message, or an error value
   *      referencing a StompException upon failing to process the message.
   */
  Future<shared.MessageFrame> _onMessageFrame(shared.MessageFrame messageFrame) {

    // Return error frame if targeting destination not subscribed to by client.
    StompSubscription subscription;
    String destination = messageFrame.destination;
    String subscriptionId = messageFrame.subscription;
    int numSubscriptions = _subscriptions.length;
    for (int subscriptionIndex = 0; subscriptionIndex < numSubscriptions; subscriptionIndex++) {
      StompSubscription thisSubscription = _subscriptions[subscriptionIndex];
      if (thisSubscription.id == subscriptionId) {
        subscription = thisSubscription;
        break;
      }
    }
    if (subscription == null) {
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_NOT_SUBSCRIBED, "No subscripton", details: "Received STOMP message from server at $_uri targeting unknown subscription $subscriptionId.", frame: messageFrame.frame);
      _sendNack(null, messageFrame.ack);
      return new Future.error(stompException);
    }
    else if (subscription.destination != destination) {
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, "Invalid destination", details: "Received STOMP message from server at $_uri specifying invalid destination $destination for subscription $subscriptionId (should be ${subscription.destination}.", frame: messageFrame.frame);
      _sendNack(subscription, messageFrame.ack);
      return new Future.error(stompException);
    }
    else {

      // Call subscriber's message handler.
      Completer<shared.MessageFrame> messageCompleter = new Completer<shared.MessageFrame>();
      _log.info(() => "Received STOMP message from server at $_uri on subscription $subscriptionId targeting destination $destination${messageFrame.body == null ? "." : (": " + shared.Logging.stripNewLinesAndLimitLength(messageFrame.body))}");
      shared.StompMessage message = new shared.StompMessage(messageFrame.body, messageFrame.contentLength, messageFrame.contentType);
      subscription._onMessage(this, message)
      .then((_) {
        _sendAck(subscription, messageFrame.ack);
        messageCompleter.complete(messageFrame);
      })
      .catchError((error) {
        _sendNack(subscription, messageFrame.ack);
        messageCompleter.completeError(error);
      });
      return messageCompleter.future;
    }
  }

  /**
   * Process RECEIPT frame received from server.
   *
   * @param receiptFrame
   *      RECEIPT frame received from server.
   *
   * @return
   *      StompException upon failing to process the frame.
   */
  shared.StompException _onReceiptFrame(shared.ReceiptFrame receiptFrame) {

    // Does this frame have a valid receipt ID?
    String receiptId = receiptFrame.receiptId;
    Completer<shared.Frame> frameCompleter = _pendingFrameCompleters[receiptId];
    if (frameCompleter == null) {
      _log.severe(() => "Received STOMP RECEIPT frame from $_uri referencing unexpected receipt $receiptId.");

      // No, we can't relate this receipt to a particular frame that we send previously, so add an event to the stomp error stream.
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_RECEIPT_ID, "Bad receipt ID", details: "Received receipt $receiptId that does not reference any pending command.", receiptId: receiptFrame.receipt, frame: receiptFrame.frame);
      return stompException;
    }
    _log.info(() => "Received STOMP RECEIPT frame from $_uri referencing receipt $receiptId.");
    _pendingFrameCompleters.remove(receiptId);
    frameCompleter.complete(receiptFrame);
    return null;
  }

  /**
   * Process ERROR frame received from server.
   *
   * @param errorFrame
   *      ERROR frame received from server.
   */
  void _onErrorFrame(shared.ErrorFrame errorFrame) {

    // Reference frame completer to be completed (with error) upon receiving this error.
    String receiptId = errorFrame.receiptId;

    // Create Stomp Exception.
    String details;
    String frame;
    String frameBody = errorFrame.body;
    int framePrefixPos = frameBody.indexOf(shared.StompException.ERROR_FRAME_PREFIX);
    if (framePrefixPos >= 0) {
      if (framePrefixPos > 0) {
        details = frameBody.substring(0, framePrefixPos).trimRight();
      }
      int frameSuffixPos = frameBody.indexOf(shared.StompException.ERROR_FRAME_SUFFIX, framePrefixPos);
      if (frameSuffixPos > 0) {
        frame = frameBody.substring(framePrefixPos + shared.StompException.ERROR_FRAME_PREFIX.length, frameSuffixPos);
        if (frame.length == 0) frame = null;
      }
    }
    else {
      details = frameBody.trimRight();
    }
    shared.StompException stompException = new shared.StompException(errorFrame.errorCode, errorFrame.message, details: details, receiptId: receiptId, frame: frame);

    // Did we receive this error received in response to CONNECT frame sent by this client?
    Completer<shared.Frame> frameCompleter = _pendingFrameCompleters[receiptId];
    if (_pendingConnectCompleter != null) {

      // Yes (likely), so complete the pending CONNECT request.
      _pendingConnectCompleter.completeError(stompException);
      _pendingConnectCompleter = null;
    }

    // Or did we receive this error frame in response to another frame sent by this client?
    else if (frameCompleter != null) {

      // Yes, complete the pending request.
      _log.severe(() => "Received STOMP ERROR frame from $_uri in response to sent frame with receipt $receiptId.");
      _pendingFrameCompleters.remove(receiptId);
      frameCompleter.completeError(stompException);
    }
    else {

      // No, we are unable to relate the received ERROR frame with a frame sent by this client but that may be OK as receipt headers are not required for ERROR frames, so we add the error to the stream.
      _onStompErrorStreamController.add(stompException);
    }
  }

  /**
   * Send STOMP 1.2-formatted frame on this connection.
   *
   * @param frame
   *      STOMP 1.2 frame to send.
   * @param withReceipt
   *      Set to true if the server must respond with a receipt or error to confirm a successful or failed processing
   *      of this command prior to completing the future returned by this method. If set to false, the method completes
   *      the future immediately with a value, where after any resulting errors are communicated via the onStompError
   *      stream. This parameter is ignored when sending a CONNECT frame.
   * @return
   *      If sending a CONNECT frame, this method returns a future to be completed with a reference to the
   *      corresponding CONNECTED frame sent back by the server. If not sending a CONNECT frame and [withReceipt] is
   *      false, this method returns a future that is immediately completed with a reference to the sent frame. In that
   *      case, any server-side errors in processing the frame are communicated via the onStompError stream. If not
   *      sending a CONNECT frame and [withReceipt] is true, this method returns a future to be completed with a
   *      reference to the resulting RECEIPT frame sent back by the server upon successfully processing the message on
   *      the server, or completed with an error referencing a StompException instance upon error.
   */
  Future<shared.Frame> _sendFrame(shared.Frame frame, {bool withReceipt: true}) {

    // Is this a CONNECT frame?
    Completer<shared.Frame> frameCompleter;
    bool isConnectFrame = (frame is shared.ConnectFrame);
    String receipt;
    if (isConnectFrame) {

      // Yes, complete with error if there already is a pending CONNECT frame.
      if (_pendingConnectCompleter != null) {
        return new Future.error(new shared.StompException(shared.StompException.ERROR_CODE_DUPLICATE_CONNECT, "Redundant connect", details: "Pending CONNECT frame already sent to server.", receiptId: frame.receipt, frame: frame.frame));
      }

      // Register this completer as needing a value (or error) upon receiving server response to this CONNECT frame.
      frameCompleter = new Completer<shared.Frame>();
      _pendingConnectCompleter = frameCompleter;
    }
    else {

      // No, generate receipt header, if requested.
      receipt = frame.receipt;
      if (receipt != null) {
        if (withReceipt) {
          _log.warning(() => "Ignoring and replacing specified STOMP receipt $receipt for ${frame.command} command targeting $_uri.");
        }
        else {
          _log.warning(() => "Removing specified STOMP receipt $receipt for ${frame.command} command to be sent without receipt, targeting $_uri.");
          frame.receipt = null;
        }
      }

      // Using a receipt?
      if (withReceipt) {

        // Yes, generate receipt ID
        receipt = (++_nextReceiptId).toString();
        frame.receipt = receipt;

        // Complete future with error if receipt not unique.
        if (_pendingFrameCompleters.containsKey(receipt)) {
          return new Future.error(new shared.StompException(shared.StompException.ERROR_CODE_NON_UNIQUE_RECEIPT, "Non-unique receipt ID", details: "Specified receipt $receipt was already submitted in a pending command.", receiptId: receipt, frame: frame.frame));
        }

        // Add receipt ID and completer to so that we can detect which subsequent RECEIPT frame received from server belongs to this command.
        frameCompleter = new Completer<shared.Frame>();
        _pendingFrameCompleters[receipt] = frameCompleter;
      }
      else {

        // No receipt requested so send the frame and return completed future right away.
        try {
          _send(frame.toString());
        }
        catch (error) {
          String errMsg = "Received error when invoking WebSocket.send to send STOMP command" + (error == null ? "." : (": " + error.toString()));
          _log.severe(() => errMsg);
          return new Future.error(new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Send failed", details: errMsg, receiptId: frame.receipt, frame: frame.frame));
        }
        return new Future.value(frame);
      }
    }

    // Send the frame and return future.
    try {
      _send(frame.toString());
    }
    catch (error) {
      String errMsg = "Received error when invoking WebSocket.send to send STOMP command" + (error == null ? "." : (": " + error.toString()));
      _log.severe(() => errMsg);
      if (isConnectFrame) {
        _pendingConnectCompleter = null;
      }
      if (withReceipt) {
        _pendingFrameCompleters.remove(receipt);
      }
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Send failed", details: errMsg, receiptId: frame.receipt, frame: frame.frame);
      frameCompleter.completeError(stompException);
    }
    return frameCompleter.future;
  }

  /**
   * Convenience method to connect to WebSocket at specified [uri] and receive Future to be completed upon having
   * successfully connected with server or a StompException reference upon failing to connect.
   *
   * @param uri
   *      URI to connect to
   * @param host
   *      Name of a virtual host that the client wishes to connect to (i.e. the 'host' header value.)
   *      It is recommended clients set this to the host name that the socket was established against, or to any name
   *      of their choosing. If this header does not match a known virtual host, servers supporting virtual hosting
   *      may select a default virtual host or reject the connection.
   * @param guaranteedHeartBeat
   *      Smallest guaranteed number of milliseconds between frames sent to server, or null (default) if this
   *      implementation cannot guarantee such minimum heart-beat interval.
   * @param desiredHeartBeat
   *      Desired number of milliseconds between frames received from server, or null (default) if this
   *      implementation does not want to receive frames at such minimum heart-beat interval.
   * @param maxFrameHeaders
   *      Maximum limit on the number of frame headers allowed in a single frame. Set to null to impose
   *      no limit.
   * @param maxHeaderLen
   *      Maximum length of header lines, expressed in number of characters. Set to null to impose no limit.
   * @param maxBodyLen
   *      Maximum size of a frame body, expressed in number of characters. Set to null to impose no limit.
   *
   * @return
   *      Future referencing this connection upon success or a StompException upon encountering an error
   *      while opening the Socket connection or connecting to the STOMP server.
   */
  static Future<WebSocketStompConnection> connect(String uri, String host, {int guaranteedHeartBeat, int desiredHeartBeat, int maxFrameHeaders, int maxHeaderLen, int maxBodyLen}) {
    _log.info(() => "Connecting from STOMP WebSocket connection at $uri.");
    return new WebSocketStompConnection(uri, host, guaranteedHeartBeat: guaranteedHeartBeat, desiredHeartBeat: desiredHeartBeat, maxFrameHeaders: maxFrameHeaders, maxHeaderLen: maxHeaderLen, maxBodyLen: maxBodyLen)._connect();
  }

  /**
   * Disconnect from WebSocket connection and receive Future to be completed upon having successfully disconnected from
   * server or a StompException reference upon failing to connect.
   *
   * @return
   *      Future with no value upon success or a StompException upon encountering an error while closing the connection.
   */
  Future disconnect() {

    // Disconnect.
    _log.info(() => "Disconnecting from STOMP WebSocket connection at $_uri.");
    Completer disconnectCompleter = new Completer();
    shared.DisconnectFrame disconnectFrame = new shared.DisconnectFrame.fromParams();
    _sendFrame(disconnectFrame, withReceipt: true).then((shared.ReceiptFrame receiptFrame) {
      _close();
      disconnectCompleter.complete();
    })
    .catchError((shared.StompException stompException) {
      _log.severe(() => "Failed disconnecting from STOMP WebSocket connection at $_uri: ${stompException.summary} (${stompException.details})");
      disconnectCompleter.completeError(stompException);
    });

    // Return future to be completed when successfully (or failing to) subscribe.
    return disconnectCompleter.future;
  }

  /**
   * Subscribe to destination. If a subscription to the same destination and with the same 'ack' header value already
   * exists, the subscription is immediately returned. Otherwise, a new STOMP subscription is established.
   *
   * @param destination
   *      Identifies the destination to which the client wishes to subscribe.
   * @param ack
   *      The valid values for the ack header are "auto", "client", or "client-individual". If the header is
   *      not set, it defaults to "auto".
   * @return
   *      This method returns a StompSubscription instance. The returned instance may represent a pending subscription.
   *      Listen for stream events on the returned instance to determine whether the subscription succeeded or failed.
   */
  StompSubscription subscribe(String destination, {String ack}) {

    // Are we already subscribed?
    for (StompSubscription subscription in _subscriptions) {
      if (subscription.destination == destination && subscription.ack == ack) {

        // Yes, return the existing subscription.
        return subscription;
      }
    }

    // Instantiate subscription.
    String subscriptionId = (++_nextSubscriptionId).toString();
    StompSubscription subscription = new StompSubscription(subscriptionId, destination, ack: ack);
    _subscriptions.add(subscription);

    // Subscribe.
    _log.info(() => "Subscribing to STOMP destination $destination at $_uri.");
    shared.SubscribeFrame subscribeFrame = new shared.SubscribeFrame.fromParams(subscription.id, destination, ack: subscription.ack);
    _sendFrame(subscribeFrame, withReceipt: true).then((shared.ReceiptFrame receiptFrame) {
      subscription._onSubscribed(this);
    })
    .catchError((shared.StompException stompException) {
      _subscriptions.remove(subscription);
      _log.severe(() => "Failed subscribing to STOMP destination $destination at $_uri: ${stompException.summary} (${stompException.details})");
      subscription._onError(stompException);
    });

    // Return future to be completed when successfully (or failing to) subscribe.
    return subscription;
  }

  /**
   * Un-subscribe from destination.
   *
   * @param subscription
   *      Subscription to no longer be subscribed to its destination.
   * @return
   *      Future referencing this WebSocket connection upon successfully completing the future, or referencing
   *      a StompException upon failing to complete the future.
   */
  Future<WebSocketStompConnection> unsubscribe(StompSubscription subscription) {

    // Un-subscribe.
    String destination = subscription.destination;
    _log.info(() => "Cancelling subscription ${subscription.id} to STOMP destination $destination at $_uri.");
    Completer<WebSocketStompConnection> unsubscribeCompleter = new Completer<WebSocketStompConnection>();
    shared.UnsubscribeFrame unsubscribeFrame = new shared.UnsubscribeFrame.fromParams(subscription.id);
    _sendFrame(unsubscribeFrame, withReceipt: true).then((shared.ReceiptFrame receiptFrame) {
      _subscriptions.remove(subscription);
      subscription._onCancelled(false);
      unsubscribeCompleter.complete(this);
    })
    .catchError((shared.StompException stompException) {
      _log.severe(() => "Failed un-subscribing from STOMP destination $destination at $_uri: ${stompException.summary} (${stompException.details})");
      subscription._onError(stompException);
      unsubscribeCompleter.completeError(stompException);
    });

    // Return future to be completed when successfully (or failing to) un-subscribe.
    return unsubscribeCompleter.future;
  }

  /**
   * Send non-transactional message to specified server destination.
   *
   * @param destination
   *      Identifies the destination where to send the message.
   * @param message
   *      Message to send to server.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param contentType
   *      MIME type which describes the format of the message.
   * @param withReceipt
   *      Set to true if the server must respond with a receipt or error to confirm a successful or failed
   *      processing of this message prior to completing the future returned by this method. If set to false, the method
   *      completes the future immediately with a value, where after any resulting errors are communicated via the
   *      onStompError stream.
   */
  Future<shared.Frame> send(String destination, String message, {int contentLength, String contentType, bool withReceipt: true}) {
    _log.info(() => ("Sending STOMP frame to destination $destination at $_uri: ${message == null ? "" : shared.Logging.stripNewLinesAndLimitLength(message, maxChars: 64)}"));
    shared.SendFrame sendFrame = new shared.SendFrame.fromParams(destination, body: message, contentLength: contentLength, contentType: contentType);
    return _sendFrame(sendFrame, withReceipt: withReceipt);
  }

  /**
   * Begin a transaction.
   *
   * @return
   *      Future completed with reference to StompTransaction instance providing methods to send messages to server via
   *      the transaction, commit or abort the transaction and send ACK/NACK messages that should be part of the
   *      transaction.
   */
  Future<StompTransaction> beginTransaction() {
    String transactionId = (++_nextTransactionId).toString();
    _log.info(() => ("Beginning STOMP transaction $transactionId with WebSocket connection to $_uri."));
    shared.BeginFrame beginFrame = new shared.BeginFrame.fromParams(transactionId);
    Completer<StompTransaction> transactionCompleter = new Completer<StompTransaction>();
    _sendFrame(beginFrame, withReceipt: true)
    .then((shared.ReceiptFrame receiptFrame) {
      StompTransaction stompTransaction = new StompTransaction(transactionId, this);
      transactionCompleter.complete(stompTransaction);
    })
    .catchError((shared.StompException stompException) {
      _log.severe(() => "Failed beginning STOMP transaction $transactionId with WebSocket connection to $_uri: ${stompException.summary} (${stompException.details})");
      transactionCompleter.completeError(stompException);
    });
    return transactionCompleter.future;
  }

  /**
   * Get stream receiving error events that cannot be specifically tied to a command we sent. Errors occurring
   * directly in response to sent commands are instead returned via the related future.
   */
  Stream<shared.StompException> get onStompError => _onStompErrorStreamController.stream;

  /**
   * Get stream receiving close events upon STOMP connection closing.
   */
  Stream<bool> get onStompConnectionClosed => _onStompConnectionClosedController.stream;
}