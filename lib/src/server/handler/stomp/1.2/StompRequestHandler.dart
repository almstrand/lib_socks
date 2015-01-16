part of server_socks;

/**
 * STOMP WebSocket request handler.
 */
class StompRequestHandler extends WebSocketRequestHandler {

  static Logger _log = new Logger("StompRequestHandler");
  InstanceMirror _instanceMirror;

  // Class mirror referencing [WebSocketConnection] class suitable for this environment and sub-protocol.
  static ClassMirror _connectionClass = reflectClass(WebSocketStompConnection);

  // Maximum limit on the number of frame headers allowed in a single frame. An error frame will be sent to clients
  // exceeding this limit, followed by closing the client connection. Set to null to impose no limit.
  int maxFrameHeaders;

  // Maximum length of header lines, expressed in number of characters. An error frame will be sent to clients
  // exceeding this limit, followed by closing the client connection. Set to null to impose no limit.
  int maxHeaderLen;

  // Maximum size of a frame body, expressed in number of characters. An error frame will be sent to clients exceeding
  // this limit, followed by closing the client connection. Set to null to impose no limit.
  int maxBodyLen;

  // Field containing information about the STOMP server. The field must contain a server-name field and may be followed
  // by optional comment fields delimited by a space character. See STOMP 1.2 specification for the correct syntax of
  // the server and server-name components.
  String _server;

  // Smallest guaranteed number of milliseconds between frames sent to each connected client, or 0 (default) if this
  // implementation cannot guarantee such minimum heart-beat interval.
  int _guaranteedHeartBeat;

  // Desired number of milliseconds between frames received from each connected client, or 0 (default) if this
  // implementation does not want to receive frames at such minimum heart-beat interval.
  int _desiredHeartBeat;

  // Currently known destinations.
  Map<String, StompDestination> _destinations = new Map<String, StompDestination>();

  /**
   * Construct new STOMP protocol request handler.
   *
   * @param server
   *      Field containing information about the STOMP server. The field must contain a server-name
   *      field and may be followed by optional comment fields delimited by a space character. Refer to the STOMP 1.2
   *      specification for the correct syntax of the server and server-name components.
   * @param guaranteedHeartBeat
   *      Smallest guaranteed number of milliseconds between frames sent to each connected client, or null if this
   *      implementation cannot guarantee such minimum heart-beat interval.
   * @param desiredHeartBeat
   *      Desired number of milliseconds between frames received from each connected client, or null if this
   *      implementation does not want to receive frames at such minimum heart-beat interval.
   * @param maxFrameHeaders
   *      Maximum limit on the number of frame headers allowed in a single frame. An error frame will be sent to clients
   *      which send messages that exceed this limit, followed by closing the client connection. Set to null to impose
   *      no limit.
   * @param maxHeaderLen
   *      Maximum length of header lines, expressed in number of characters. An error frame will be sent to
   *      clients which send messages that exceed this limit, followed by closing the client connection. Set to null
   *      to impose no limit.
   * @param maxBodyLen
   *      Maximum size of a frame body, expressed in number of characters. An error frame will be sent to
   *      clients which send messages that exceed this limit, followed by closing the client connection. Set to null
   *      to impose no limit.
   */
  StompRequestHandler({String server, int guaranteedHeartBeat, int desiredHeartBeat, int this.maxFrameHeaders, int this.maxHeaderLen, int this.maxBodyLen}) : super() {
    _server = server;
    _guaranteedHeartBeat = (guaranteedHeartBeat == null ? 0 : guaranteedHeartBeat);
    _desiredHeartBeat = (desiredHeartBeat == null ? 0 : desiredHeartBeat);
    _instanceMirror = reflect(this);
  }

  /**
   * Implemented in concrete class to reference the [WebSocketConnection] class to be instantiated upon accepting a
   * client connection, or when establishing a connection with a server.
   *
   * The client/server implementation differs as the availability of the libraries (i.e. dart:io and dart:html)
   * implementing the WebSocket class varies depending on whether used in a client (web) or server application. The
   * appropriate [WebSocketConnection] class is also dependent on the implemented sub-protocol.
   *
   * @return
   *      Class mirror referencing [WebSocketConnection] class suitable for this environment and sub-protocol.
   */
  ClassMirror get connectionClass => _connectionClass;

  /**
   * Add destination.
   *
   * @param stompDestination
   *      Handler tracking subscriptions and processing messages targeting the destination.
   * @throws
   *      StompException if an invalid destination is specified or the destination already exists.
   */
  void addDestination(StompDestination stompDestination) {
    _log.info(() => "Registering STOMP destination ${stompDestination._destination} in request handler ${runtimeType}.");

    // Throwing StompException if specified destination is invalid.
    String destination = stompDestination.destination;
    if (destination == null) {
      String errStr = "Failed registering handler for STOMP destination ${stompDestination._destination}: Destination must be non-null.";
      _log.severe(() => errStr);
      throw new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, "Invalid destination", details: errStr);
    }
    if (_destinations.containsKey(destination)) {
      String errStr = "Failed registering handler for STOMP destination ${stompDestination._destination}: Destination $destination already registered with route.";
      _log.severe(() => errStr);
      throw new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, "Invalid destination", details: errStr);
    }

    // Add destination
    _destinations[destination] = stompDestination;
  }

  /**
   * Add [WebSocketStompConnection] of client connected to this route.
   *
   * @param connection
   *        connection of client connected to this route.
   */
  void _addConnection(WebSocketStompConnection connection) {
  }

  /**
   * Remove [WebSocketStompConnection] of client no longer connected to this route.
   *
   * @param connection
   *        connection of client no longer connected to this route.
   */
  void _removeConnection(WebSocketStompConnection connection) {

    // Abort any pending transactions.
    Map<String, StompTransaction> transactions = connection._transactions;
    int numTransactions = transactions.length;
    if (numTransactions > 0) {
      _log.info("Aborting $numTransactions pending trancation(s) due to WebSocket connection ${connection.id} closing.");
      List<Future> onAbortFunctions = new List<Future>();
      connection._transactions.forEach((String transactionId, StompTransaction transaction) {
        _destinations.forEach((String destinationId, StompDestination destination) {
          onAbortFunctions.add(destination.onAbort(transactionId));
        });
      });
      Future.wait(onAbortFunctions)
      .catchError((stompException) {
        String errStr = "Failed aborting pending transactions on WebSocket connection ${connection.id} as destination's onAbort method returned error: ${stompException.summary} (${stompException.details})";
        _log.severe(errStr);
      });
    }

    // Remove connection if registered as subscriber to any destination.
    _destinations.forEach((String destination, StompDestination stompDestination) {
      stompDestination._removeConnection(connection);
    });
  }

  /**
   * Process SEND frame received from client.
   *
   * @param sendFrame
   *      SEND frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.SendFrame> _onSendFrame(shared.SendFrame sendFrame, WebSocketStompConnection connection) {
    String transactionId = sendFrame.transactionId;
    _log.info(() => "Received STOMP SEND frame ${transactionId == null ? "" : "in transaction $transactionId "}on WebSocket connection ${connection.id} targeting destination ${sendFrame.destination}.");

    // Respond with STOMP ERROR if frame does not target a registered destination.
    String destination = sendFrame.destination;
    StompDestination stompDestination = _destinations[destination];
    if (stompDestination == null) {
      String errStr = "Failed forwarding STOMP SEND frame received on WebSocket connection ${connection.id} to un-registered destination $destination.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, "Invalid destination", details: errStr, receiptId: sendFrame.receipt, frame: sendFrame.frame);
      return new Future.error(stompException);
    }

    // Forward frame to destination.
    Completer<shared.SendFrame> sendCompleter = new Completer<shared.SendFrame>();
    _log.info(() => "Forwarding STOMP SEND frame received on WebSocket connection ${connection.id} to handler for destination $destination.");
    shared.StompMessage message = new shared.StompMessage(sendFrame.body, sendFrame.contentLength, sendFrame.contentType);
    stompDestination.onMessage(sendFrame.transactionId, message)
    .then((_) {
      stompDestination._notifySubscribers(message)
      .then((_) {
        sendCompleter.complete(sendFrame);
      })
      .catchError((shared.StompException stompException) {
        sendCompleter.completeError(stompException);
      });
    })
    .catchError((stompException) {
      _log.severe(() => "Failed forwarding STOMP SEND frame received on WebSocket connection ${connection.id} to handler for destination $destination: ${stompException.summary}");
      sendCompleter.completeError(stompException);
    });

    return sendCompleter.future;
  }

  /**
   * Process SUBSCRIBE frame received from client.
   *
   * @param subscribeFrame
   *      SUBSCRIBE frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.SubscribeFrame> _onSubscribeFrame(shared.SubscribeFrame subscribeFrame, WebSocketStompConnection connection) {
    _log.info(() => "Received STOMP SUBSCRIBE frame on WebSocket connection ${connection.id} targeting destination ${subscribeFrame.destination}.");

    // Reference destination, completing future with StompException if specified destination is invalid.
    String subscriptionId = subscribeFrame.id;
    String destination = subscribeFrame.destination;
    StompDestination stompDestination = _destinations[destination];
    if (stompDestination == null) {
      String errStr = "Failed subscribing WebSocket connection ${connection.id} to un-registered destination $destination.";
      _log.warning(errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, errStr);
      return new Future.error(stompException);
    }

    // Complete future with StompException if already subscribed to destination.
    if (stompDestination._isSubscribed(connection)) {
      String errStr = "WebSocket connection ${connection.id} is already subscribed to destination ${destination}.";
      _log.warning(errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_DESTINATION, errStr);
      return new Future.error(stompException);
    }

    // Complete future with StompException if subscription ID is already in use by connection.
    if (connection._hasSubscription(subscriptionId)) {
      String errStr = "WebSocket connection ${connection.id} is attempting to re-use subscription ${subscriptionId} when subscribing to destination $destination.";
      _log.severe(errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_SUBSCRIBER, "Invalid subscriber", details: errStr);
      return new Future.error(stompException);
    }

    // Add connection as subscriber to destination.
    StompSubscription subscription = new StompSubscription(subscriptionId, destination, subscribeFrame.ack, connection);
    stompDestination._addSubscription(subscription);
    connection._addSubscription(subscription);

    // Return success
    return new Future.value(subscribeFrame);
  }

  /**
   * Process UNSUBSCRIBE frame received from client.
   *
   * @param unsubscribeFrame
   *      UNSUBSCRIBE frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.UnsubscribeFrame> _onUnsubscribeFrame(shared.UnsubscribeFrame unsubscribeFrame, WebSocketStompConnection connection) {
    String subscriptionId = unsubscribeFrame.id;
    _log.info(() => "Received STOMP UNSUBSCRIBE frame on WebSocket connection ${connection.id} referencing subscription $subscriptionId.");

    // Complete future with StompException if specified subscription does not exist.
    StompSubscription subscription = connection._subscriptions[subscriptionId];
    if (subscription == null) {
      String errStr = "Failed cancelling invalid subscription $subscriptionId for WebSocket connection ${connection.id}.";
      _log.warning(errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_INVALID_SUBSCRIBER, "Invalid subscriber", details: errStr);
      return new Future.error(stompException);
    }

    // Complete future with StompException if client has not already responded with ACK or NACK to messages sent to client via this subscription.
    int numPendingAcks = subscription._pendingMessageAck.length;
    if (numPendingAcks > 0) {
      String errStr = "Failed cancelling subscription $subscriptionId awaiting $numPendingAcks message acknowledgments from WebSocket connection ${connection.id}.";
      _log.warning(errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_SUBSCRIPTION_NOT_DRAINED, "Invalid subscriber", details: errStr);
      return new Future.error(stompException);
    }

    // Remove subscriber.
    String destination = subscription.destination;
    StompDestination stompDestination = _destinations[destination];
    stompDestination._removeSubscription(subscription);
    connection._removeSubscription(subscriptionId);
    subscription._cancel(stompDestination.onNack);

    // Return success.
    return new Future.value(unsubscribeFrame);
  }

  /**
   * Process BEGIN frame received from client.
   *
   * @param beginFrame
   *      BEGIN frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.BeginFrame> _onBeginFrame(shared.BeginFrame beginFrame, WebSocketStompConnection connection) {
    String transactionId = beginFrame.transactionId;
    _log.info(() => "Received STOMP BEGIN frame for new transaction $transactionId on WebSocket connection ${connection.id}.");

    // Respond with STOMP ERROR if frame specifies an invalid transaction ID.
    if (transactionId == null) {
      String errStr = "Failed creating new transaction on WebSocket connection ${connection.id} as received frame does not specify required transaction ID.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: beginFrame.receipt, frame: beginFrame.frame);
      return new Future.error(stompException);
    }
    if (connection._hasTransaction(transactionId)) {
      String errStr = "Failed creating new transaction as ID $transactionId is already associated with WebSocket connection ${connection.id}.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: beginFrame.receipt, frame: beginFrame.frame);
      return new Future.error(stompException);
    }

    // Create transaction associated with the connection.
    StompTransaction transaction = new StompTransaction(transactionId);
    connection._addTransaction(transaction);

    // Return success
    return new Future.value(beginFrame);
  }

  /**
   * Process COMMIT frame received from client.
   *
   * @param commitFrame
   *      COMMIT frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.CommitFrame> _onCommitFrame(shared.CommitFrame commitFrame, WebSocketStompConnection connection) {
    String transactionId = commitFrame.transactionId;
    _log.info(() => "Received STOMP COMMIT frame for transaction $transactionId on WebSocket connection ${connection.id}.");

    // Respond with STOMP ERROR if frame specifies an invalid transaction ID.
    if (transactionId == null) {
      String errStr = "Failed comitting transaction on WebSocket connection ${connection.id} as received frame does not specify required transaction ID.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: commitFrame.receipt, frame: commitFrame.frame);
      return new Future.error(stompException);
    }

    // Commit transaction and remove from connection.
    if (connection._removeTransaction(transactionId) == null) {
      String errStr = "Failed comitting transaction as transaction $transactionId is not associated with WebSocket connection ${connection.id}.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: commitFrame.receipt, frame: commitFrame.frame);
      return new Future.error(stompException);
    }

    // Allow server implementation to commit transaction by invoking onCommit on all destinations that may have received messages to be included in the transaction.
    Completer<shared.CommitFrame> commitCompleter = new Completer<shared.CommitFrame>();
    List<Future> onCommitFunctions = new List<Future>();
    _destinations.forEach((String destinationId, StompDestination destination) {
      onCommitFunctions.add(destination.onCommit(transactionId));
    });
    Future.wait(onCommitFunctions)
    .then((_) {
      commitCompleter.complete(commitFrame);
    })
    .catchError((stompException) {
      String errStr = "Failed comitting transaction $transactionId on WebSocket connection ${connection.id} as destination's onCommit method returned an error: ${stompException.summary} (${stompException.details})";
      commitCompleter.completeError(stompException);
    });

    return commitCompleter.future;
  }

  /**
   * Process ABORT frame received from client.
   *
   * @param abortFrame
   *      ABORT frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.AbortFrame> _onAbortFrame(shared.AbortFrame abortFrame, WebSocketStompConnection connection) {
    String transactionId = abortFrame.transactionId;
    _log.info(() => "Received STOMP ABORT frame for transaction $transactionId on WebSocket connection ${connection.id}.");

    // Respond with STOMP ERROR if frame specifies an invalid transaction ID.
    if (transactionId == null) {
      String errStr = "Failed aborting transaction on WebSocket connection ${connection.id} as received frame does not specify required transaction ID.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: abortFrame.receipt, frame: abortFrame.frame);
      return new Future.error(stompException);
    }

    // Abort transaction and remove from connection.
    if (connection._removeTransaction(transactionId) == null) {
      String errStr = "Failed aborting transaction as transaction $transactionId is not associated with WebSocket connection ${connection.id}.";
      _log.warning(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_TRANSACTION, "Invalid transaction", details: errStr, receiptId: abortFrame.receipt, frame: abortFrame.frame);
      return new Future.error(stompException);
    }

    // Allow server implementation to abort transaction by invoking onAbort on all destinations that may have received messages to be included in the transaction.
    Completer<shared.AbortFrame> abortCompleter = new Completer<shared.AbortFrame>();
    List<Future> onAbortFunctions = new List<Future>();
    _destinations.forEach((String destinationId, StompDestination destination) {
      onAbortFunctions.add(destination.onAbort(transactionId));
    });
    Future.wait(onAbortFunctions)
    .then((_) {
      abortCompleter.complete(abortFrame);
    })
    .catchError((stompException) {
      String errStr = "Failed aborting transaction $transactionId on WebSocket connection ${connection.id} as destination's onAbort method returned an error: ${stompException.summary} (${stompException.details})";
      abortCompleter.completeError(stompException);
    });

    return abortCompleter.future;
  }

  /**
   * Process ACK frame received from client.
   *
   * @param ackFrame
   *      ACK frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.AckFrame> _onAckFrame(shared.AckFrame ackFrame, WebSocketStompConnection connection) {
    int messageAckId = int.parse(ackFrame.id);
    String transactionId = ackFrame.transactionId;
    _log.info(() => "Received STOMP ACK frame ${transactionId == null ? "" : "in transaction $transactionId "}on WebSocket connection ${connection.id} referencing MESSAGE frame identified by ${messageAckId}.");
    bool foundPendingAck = false;
    for (String destination in _destinations.keys) {
      StompDestination stompDestination = _destinations[destination];
      foundPendingAck = stompDestination._onAck(transactionId, messageAckId);
      if (foundPendingAck) break;
    }
    if (foundPendingAck) {
      return new Future.value(ackFrame);
    }
    else {
      String errStr = "Received STOMP acknowledgment from connection ${connection.id} referencing invalid message ${messageAckId}.";
      _log.info(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_MESSAGE_ID, "Invalid message ID", details: errStr);
      return new Future.error(stompException);
    }
  }

  /**
   * Process NACK frame received from client.
   *
   * @param nackFrame
   *      NACK frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.NackFrame> _onNackFrame(shared.NackFrame nackFrame, WebSocketStompConnection connection) {
    int messageAckId = int.parse(nackFrame.id);
    String transactionId = nackFrame.transactionId;
    _log.info(() => "Received STOMP NACK frame ${transactionId == null ? "" : "in transaction $transactionId "}on WebSocket connection ${connection.id} referencing MESSAGE frame identified by ${messageAckId}.");
    bool foundPendingAck = false;
    for (String destination in _destinations.keys) {
      StompDestination stompDestination = _destinations[destination];
      foundPendingAck = stompDestination._onNack(transactionId, messageAckId);
      if (foundPendingAck) break;
    }
    if (foundPendingAck) {
      return new Future.value(nackFrame);
    }
    else {
      String errStr = "Received negative STOMP acknowledgment from connection ${connection.id} referencing invalid message ${messageAckId}.";
      _log.info(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_BAD_MESSAGE_ID, "Invalid message ID", details: errStr);
      return new Future.error(stompException);
    }
  }

  /**
   * Process DISCONNECT frame received from client.
   *
   * @param disconnectFrame
   *      DISCONNECT frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.DisconnectFrame> _onDisconnectFrame(shared.DisconnectFrame disconnectFrame, WebSocketStompConnection connection) {
    _log.info(() => "Received STOMP DISCONNECT frame received on WebSocket connection ${connection.id}.");

    // Respond with ERROR frame and close the connection if no active STOMP connection exists.
    if (!connection._isActiveStompConnection) {

      // Respond with error frame and close the connection.
      String errStr = "Failed disconnecting from already-disconnected STOMP session.";
      _log.severe(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_NOT_CONNECTED, "Not connected", details: errStr, receiptId: disconnectFrame.receipt, frame: disconnectFrame.frame);
      return new Future.error(stompException);
    }

    // Mark connection as being disconnected and return success.
    connection._isActiveStompConnection = false;
    return new Future.value(disconnectFrame);
  }

  /**
   * Process CONNECT frame received from client.
   *
   * @param connectFrame
   *      CONNECT frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.ConnectFrame> _onConnectFrame(shared.ConnectFrame connectFrame, WebSocketStompConnection connection) {
    _log.info(() => "Received STOMP CONNECT frame on WebSocket connection ${connection.id}.");

    // Respond with ERROR frame and close the connection if already connected.
    if (connection._isActiveStompConnection) {
      String errStr = "Failed establishing STOMP connection for WebSocket connection ${connection.id}: Already connected";
      _log.severe(() => errStr);
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_ALREADY_CONNECTED, "Already connected", details: errStr, receiptId: connectFrame.receipt, frame: connectFrame.frame);
      return new Future.error(stompException);
    }

    // Determine the interval at which this server must send heart-beat frames (frames of any kind) to the client.
    int serverToClientHeartBeatInterval;
    int clientDesiredHeartBeat = connectFrame.desiredHeartBeat;
    if (_guaranteedHeartBeat == 0 || clientDesiredHeartBeat == 0) {
      serverToClientHeartBeatInterval = 0;
    }
    else {
      serverToClientHeartBeatInterval = max(_guaranteedHeartBeat, clientDesiredHeartBeat);
      _log.info(() => "Using heart-beat interval $serverToClientHeartBeatInterval for WebSocket connection ${connection.id}.");
    }

    // Mark connection as being connected.
    connection._isActiveStompConnection = true;

    // Respond with CONNECTED frame.
    _log.info(() => "Responding with CONNECTED STOMP frame received on WebSocket connection ${connection.id}.");
    shared.ConnectedFrame connectedFrame = new shared.ConnectedFrame.fromParams(shared.Version.VERSION_1_2, server: _server, guaranteedHeartBeat: _guaranteedHeartBeat, desiredHeartBeat: _desiredHeartBeat, session: new DateTime.now().millisecondsSinceEpoch.toString());
    return connection._sendFrame(connectedFrame);
  }

  /**
   * Process STOMP frame received from client.
   *
   * @param stompFrame
   *      STOMP frame received from client.
   * @param connection
   *      WebSocket connection on which frame was received.
   * @return
   *      Future referencing the received frame upon success, or a StompException upon failing to process the frame.
   */
  Future<shared.StompFrame> _onStompFrame(shared.StompFrame stompFrame, WebSocketStompConnection connection) {
    return new Future.value(stompFrame);
  }

  /**
   * Invoke handler to process command received from client.
   *
   * @return
   *      Future referencing received frame upon success, or error referencing StompException.
   */
  Future<shared.Frame> _on(String command, shared.Frame frame, WebSocketStompConnection connection) {
    switch (command) {
      case "SEND" :
        return _onSendFrame(frame, connection);
      case "SUBSCRIBE" :
        return _onSubscribeFrame(frame, connection);
      case "UNSUBSCRIBE":
        return _onUnsubscribeFrame(frame, connection);
      case "BEGIN":
        return _onBeginFrame(frame, connection);
      case "COMMIT":
        return _onCommitFrame(frame, connection);
      case "ABORT":
        return _onAbortFrame(frame, connection);
      case "ACK":
        return _onAckFrame(frame, connection);
      case "NACK":
        return _onNackFrame(frame, connection);
      case "DISCONNECT":
        return _onDisconnectFrame(frame, connection);
      case "CONNECT":
        return _onConnectFrame(frame, connection);
      case "STOMP":
        return _onStompFrame(frame, connection);
      default:
        String errStr = "Failed parsing STOMP frame received on WebSocket connection ${connection.id}: Un-supported command $command.";
        shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_UNEXPECTED_FRAME, "Unexpected frame", details: errStr, receiptId: frame.receipt, frame: frame.frame);
        return new Future.error(stompException);
    }
  }

  /**
   * Process STOMP 1.2 message received from client WebSocket connection.
   *
   * @param connection
   *      Connection on which the client sent a message.
   * @param message
   *      Message received from the client.
   */
  void _onMessage(WebSocketStompConnection connection, String message) {
    _log.info(() => "Processing STOMP frame received on WebSocket connection ${connection.id}.");
    try {

      // Construct a frame from the received message and throw exception if an invalid command was received.
      shared.Frame frame = new shared.Frame.fromMessage(message, maxFrameHeaders: maxFrameHeaders, maxHeaderLen: maxHeaderLen, maxBodyLen: maxBodyLen);
      String command = frame.command;

      // Process command (call the _on... method.)
      _on(command, frame, connection)
      .then((shared.Frame frame) {

        // Respond with RECEIPT frame if requested.
        String receipt = frame.receipt;
        if (receipt != null) {
          _log.info(() => "Responding with receipt $receipt on WebSocket connection ${connection.id} to signal successful processing of $command command.");
          shared.ReceiptFrame receiptFrame = new shared.ReceiptFrame.fromParams(receipt);
          connection._sendFrame(receiptFrame)
          .catchError((shared.StompException exception) {
            _log.severe(() => "Failed responding with receipt $receipt on WebSocket connection ${connection.id} to signal successful processing of $command command.");
          });
        }
      })
      .catchError((shared.StompException stompException) {
        _log.severe(() => "Responding with error to signal failed proccessing of $command command ${(frame.receipt == null) ? "" : "with receipt ${frame.receipt} "}received on WebSocket connection ${connection.id}: ${stompException.summary} (${stompException.details})");
        stompException.frame = message;
        stompException.receiptId = frame.receipt;
        connection._sendFrame(stompException.asErrorFrame())
        .catchError((shared.StompException exception) {
          _log.severe(() => "Failed responding with error to signal failed proccessing of $command command ${(frame.receipt == null) ? "" : "with receipt ${frame.receipt} "}received on WebSocket connection ${connection.id}: ${stompException.summary} (${stompException.details})");
        });
        connection.close();
      });
    }

    // Respond with error frame and close the connection if command processing successful?
    on shared.StompException catch (stompException) {
      _log.severe(() => "Failed parsing message received on WebSocket connection ${connection.id}: ${stompException.summary}");
      stompException.frame = message;
      connection._sendFrame(stompException.asErrorFrame())
      .catchError((shared.StompException exception) {
        _log.severe(() => "Failed responding with error to signal failed parsing of message received on WebSocket connection ${connection.id}: ${stompException.summary}");
      });
      connection.close();
    }
  }

}