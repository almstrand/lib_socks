part of server_socks;

/**
 * Represents a destination to which STOMP clients can subscribe.
 */
class StompDestination {

  static Logger _log = new Logger("StompDestination");

  // Message ID sequence generator
  static int _nextMessageId = 0;

  // Destination identifier.
  String _destination;

  // Subscribers to this destination
  Map<int, StompSubscription> _subscriptions = new Map<int, StompSubscription>();

  // Subscribers awaiting acknowledgment of messages sent to subscribers to determine whether client succeeded/failed in
  // processing the message.
  Map<int, StompSubscription> _pendingMessageAck = new Map<int, StompSubscription>();

  StompDestination(String this._destination);

  /**
   * Add subscriber to this destination.
   *
   * @param subscription
   *      A subscription to this destination.
   */
  void _addSubscription(StompSubscription subscription) {
    WebSocketStompConnection connection = subscription.connection;
    int connectionId = connection.id;
    _log.info(() => "Adding subscription ${subscription.id} to notify client on WebSocket connection $connectionId of messages targeting destination $_destination.");
    StompSubscription pastSubscription = _subscriptions[connectionId];
    if (pastSubscription == null) {
      _subscriptions[connectionId] = subscription;
    }
    else {
      _log.warning(() => "Failed adding already-existing subscription ${subscription.id} to destination $_destination on WebSocket connection $connectionId.");
    }
  }

  /**
   * Remove subscriber from this destination.
   *
   * @param subscription
   *      A current subscription to this destination.
   */
  void _removeSubscription(StompSubscription subscription) {
    String subscriptionId = subscription.id;
    int connectionId = subscription.connection.id;
    _log.info(() => "Removing subscription $subscriptionId to notify client on WebSocket connection $connectionId of messages targeting destination $_destination.");
    if (_subscriptions.remove(connectionId) == null) {
      _log.warning(() => "Failed removing non-existent subscription $subscriptionId from destination $_destination on WebSocket connection $connectionId.");
    }
  }

  /**
   * Remove all subscriptions to this destination that have been established via specified [connection].
   *
   * @param connection
   *      WebSocket connection to un-subscribe from this destination.
   */
  void _removeConnection(WebSocketConnection connection) {
    int connectionId = connection.id;
    _subscriptions.forEach((int thisConnectionId, StompSubscription thisSubscription) {
      if (thisConnectionId == connectionId) {
        _log.info(() => "Un-subscribing STOMP subscription ${thisSubscription.id} from destination $_destination on WebSocket connection $connectionId .");
        thisSubscription._cancel(onNack);
        _subscriptions.remove(connection);
      }
    });
  }

  /**
   * Determine whether any subscriptions to this destination have been established via specified WebSocket [connection].
   *
   * @param connection
   *      WebSocket connection check if subscribed to this destination.
   * @return
   *      True if specified WebSocket connection has established any subscriptions to this destination.
   */
  bool _isSubscribed(WebSocketStompConnection connection) {
    return _subscriptions[connection.id] != null;
  }

  /**
   * Acknowledge client succeeding to process received message.
   *
   * @param transactionId
   *      ID of transaction if this message is part of a transaction, or null otherwise.
   * @param messageAckId
   *      The message acknowledgment ID previously sent to client in the STOMP MESSAGE frame 'ack' header.
   * @return
   *      True if a valid message acknowledgment ID was specified, which identified a message previously sent to client.
   */
  bool _onAck(String transactionId, int messageAckId) {
    StompSubscription subscriptionAwaitingAck = _pendingMessageAck[messageAckId];
    if (subscriptionAwaitingAck == null) return false;
    _pendingMessageAck.remove(messageAckId);
    return subscriptionAwaitingAck._onAck(transactionId, messageAckId, onAck);
  }

  /**
   * Acknowledge client failing to process received message.
   *
   * @param transactionId
   *      ID of transaction if this message is part of a transaction, or null otherwise.
   * @param messageAckId
   *      The message acknowledgment ID previously sent to client in the STOMP MESSAGE frame 'ack' header.
   * @return
   *      True if a valid message acknowledgment ID was specified, which identified a message previously sent to client.
   */
  bool _onNack(String transactionId, int messageAckId) {
    StompSubscription subscriptionAwaitingAck = _pendingMessageAck[messageAckId];
    if (subscriptionAwaitingAck == null) return false;
    _pendingMessageAck.remove(messageAckId);
    return subscriptionAwaitingAck._onNack(transactionId, messageAckId, onNack);
  }

  /**
   * Forward message received on this destination to subscribers.
   *
   * @param sendFrame
   *      STOMP SEND frame sent from client to this destination.
   * @return
   *      Future with no value once this handler is done forwarding the message to all subscribed clients, or an error
   *      referencing a StompException upon error.
   */
  Future _notifySubscribers(shared.StompMessage message) {
    int numSubscriptions = _subscriptions.length;
    int errorsOccurred = 0;
    Completer notifyCompleter = new Completer();
    _subscriptions.forEach((int connectionId, StompSubscription subscription) {
      String messageIdStr = (++_nextMessageId).toString();
      shared.MessageFrame messageFrame = new shared.MessageFrame.fromParams(_destination, messageIdStr, subscription.id, body: message.message, contentType: message.contentType, contentLength: message.contentLength);
      subscription._send(messageFrame)
      .then((int messageAckId) {
        if (messageAckId != null) {
          _pendingMessageAck[messageAckId] = subscription;
        }
        if (--numSubscriptions == 0) {
          if (errorsOccurred == 0) {
            notifyCompleter.complete();
          }
          else {
            shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Failed sending message", details: "Failed sending STOMP message to $errorsOccurred/$numSubscriptions clients subscribed to destination $_destination.");
            notifyCompleter.completeError(stompException);
          }
        }
      })
      .catchError((shared.StompException stompException) {
        errorsOccurred++;
        String errMsg = "Failed sending STOMP message to $errorsOccurred/$numSubscriptions clients subscribed to destination $_destination.";
        _log.severe(() => errMsg);
        if (--numSubscriptions == 0) {
          shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Failed sending message", details: errMsg);
          notifyCompleter.completeError(stompException);
        }
      });
    });
    return notifyCompleter.future;
  }

  /**
   * May be overridden by sub-classes to perform additional processing of messages successfully processed by subscribed
   * client.
   *
   * @param transactionId
   *      ID of transaction if this acknowledgment is part of a transaction, or null otherwise.
   * @param messageAckId
   *      The message acknowledgment ID previously sent to client in the MESSAGE frame 'ack' header.
   * @param messageFrame
   *      The MESSAGE frame that was successfully processed by the client.
   * @param subscription
   *      The subscription causing the MESSAGE frame to be sent to client.
   */
  void onAck(String transactionId, int messageAckId, shared.MessageFrame messageFrame, StompSubscription subscription) {
    _log.info(() => "Received acknowledgment of message $messageAckId sent ${transactionId == null ? "" : "in transaction $transactionId "}to subscription ${subscription.id} on WebSocket connection ${subscription.connection.id} targeting destination ${subscription.destination}.");
  }

  /**
   * May be overridden by sub-class to perform additional processing of messages failed to be processed
   * by subscribed client.
   *
   * @param transactionId
   *      ID of transaction if this failed acknowledgment is part of a transaction, or null otherwise.
   * @param messageAckId
   *      The message ID previously sent to client in the MESSAGE frame 'ack' header.
   * @param messageFrame
   *      The MESSAGE frame that was failed to be processed by the client.
   * @param subscription
   *      The subscription causing the MESSAGE frame to be sent to client.
   * @param confirmed
   *      Set to true if server received a NACK frame from client to confirm the client receiving but failing to process
   *      the message. Set to false if client was disconnected before receiving an ACK or NACK frame in response
   *      to sending the message.
   */
  void onNack(String transactionId, int messageAckId, shared.MessageFrame messageFrame, StompSubscription subscription, bool confirmed) {
    if (confirmed) {
      _log.info(() => "Received negative acknowledgment of message $messageAckId sent ${transactionId == null ? "" : "in transaction $transactionId "}to subscription ${subscription.id} on WebSocket connection ${subscription.connection.id} targeting destination ${subscription.destination}.");
    }
    else {
      _log.info(() => "Unable to confirm whether client successfully processed message $messageAckId sent  ${transactionId == null ? "" : "in transaction $transactionId "}to subscription ${subscription.id} on WebSocket connection ${subscription.connection.id} targeting destination ${subscription.destination}.");
    }
  }

  /**
   * Process MESSAGE frame received from client. After executing this method, the message is forwarded to all subscribed
   * WebSocket connections.
   *
   * @param transactionId
   *      ID of transaction if this message is part of a transaction, or null otherwise.
   * @param message
   *      Received message.
   * @param contentLength
   *      The octet count for the length of the message body. This is an optional field that may be null.
   * @param contentType
   *      The mime type of this message. This is an optional field that may be null.
   * @return
   *      Future (without a value) once this handler is done processing the message, or an error with a StompException value upon error.
   */
  Future onMessage(String transactionId, shared.StompMessage message) {
    _log.info(() => "Received message targeting destination $_destination ${transactionId == null ? "" : "in transaction $transactionId "}: [${shared.Logging.stripNewLinesAndLimitLength(message.message)}]");
    return new Future.value();
  }

  /**
   * Process COMMIT frame received from client.
   *
   * @param transactionId
   *      ID of transaction being committed.
   * @return
   *      Future (without a value) once this handler is done committing the transaction, or an error with a StompException value upon error.
   */
  Future onCommit(String transactionId) {
    _log.info(() => "Received request to abort any messages sent to destination $_destination in transaction $transactionId.");
    return new Future.value();
  }

  /**
   * Process ABORT frame received from client.
   *
   * @param transactionId
   *      ID of transaction being aborted.
   * @return
   *      Future (without a value) once this handler is done aborting the transaction, or an error with a StompException value upon error.
   */
  Future onAbort(String transactionId) {
    _log.info(() => "Received request to abort any messages sent to destination $_destination in transaction $transactionId.");
    return new Future.value();
  }

  /**
   * Get the unique string identifying this destination.
   */
  String get destination => _destination;
}