part of server_socks;

/**
 * Represents a server-side STOMP 1.2 WebSocket connection.
 */
class WebSocketStompConnection extends WebSocketConnection {

  static Logger _log = new Logger("WebSocketStompConnection");

  // Set to true while there is an active STOMP (i.e. not same as WebSocket-) connection between this client and the server.
  bool _isActiveStompConnection = false;

  // Relates subscription identifiers with subscriptions established via this connection
  Map<String, StompSubscription> _subscriptions = new Map<String, StompSubscription>();

  // Relates transaction identifiers with open transactions established via this connection
  Map<String, StompTransaction> _transactions = new Map<String, StompTransaction>();

  /**
   * Construct server-side WebSocket connection.
   *
   * @param id
   *      Integer identifying this connection.
   * @param webSocket
   *      WebSocket instance wrapped by ths connection class.
   */
  WebSocketStompConnection(int id, WebSocket webSocket) : super(id, webSocket);

  /**
   * Add subscription.
   *
   * @param subscription
   *      Subscription representing a connection and unique ID of the subscriber interested in receiving messages
   *      targeting its destination.
   */
  void _addSubscription(StompSubscription subscription) {
    String subscriptionId = subscription.id;
    _log.info(() => "Associating subscription $subscriptionId to destination ${subscription.destination} with WebSocket connection $id.");
    WebSocketStompConnection connection = subscription.connection;
    int connectionId = connection.id;
    StompSubscription pastSubscription = _subscriptions[subscriptionId];
    if (pastSubscription == null) {
      _subscriptions[subscriptionId] = subscription;
    }
    else {
      _log.info(() => "Failed associating subscription $subscriptionId to destination ${subscription.destination} with WebSocket connection $id as an existing subscription is using same ID.");
    }
  }

  /**
   * Remove subscriber.
   *
   * @param subscriptionId
   *      ID of STOMP subscription to un-subscribe from receiving further messages targeting its subscribed destination.
   * @return
   *      Reference to previous subscription, or null upon failing to un-subscribe.
   */
  StompSubscription _removeSubscription(String subscriptionId) {
    StompSubscription subscription = _subscriptions.remove(subscriptionId);
    if (subscription != null) {
      _log.info(() => "Disassociating subscription $subscriptionId to destination ${subscription.destination} from WebSocket connection $id.");
    }
    else {
      _log.info(() => "Failed disassociating unknown subscription $subscriptionId from WebSocket connection $id.");
    }
    return subscription;
  }

  /**
   * Determine whether this connection has a subscriber with specified ID.
   *
   * @param subscriptionId
   *      ID of STOMP subscription.
   * @return
   *      True if connection has a subscriber with specified ID.
   */
  bool _hasSubscription(String subscriptionId) {
    return _subscriptions[subscriptionId] != null;
  }

  /**
   * Add transaction.
   *
   * @param transaction
   *      STOMP transaction to be associated with this connection.
   */
  void _addTransaction(StompTransaction transaction) {
    String transactionId = transaction.id;
    _log.info(() => "Associating transaction $transactionId with WebSocket connection $id.");
    StompTransaction pastTransaction = _transactions[transactionId];
    if (pastTransaction == null) {
      _transactions[transactionId] = transaction;
    }
    else {
      _log.info(() => "Failed associating transaction $transactionId with WebSocket connection $id as an existing transaction is using same ID.");
    }
  }

  /**
   * Remove transaction.
   *
   * @param transaction
   *      STOMP transaction to be disassociated with this connection.
   * @return
   *      Reference to previous transaction, or null upon failing to disassociate.
   */
  StompTransaction _removeTransaction(String transactionId) {
    _log.info(() => "Disassociating transaction $transactionId from WebSocket connection $id.");
    StompTransaction transaction = _transactions.remove(transactionId);
    if (transaction == null) {
      _log.info(() => "Failed disassociating transaction $transactionId from WebSocket connection $id.");
    }
    return transaction;
  }

  /**
   * Determine whether this connection has a transaction with specified ID.
   *
   * @param transactionId
   *      ID of STOMP transaction.
   * @return
   *      True if connection has transaction with specified ID.
   */
  bool _hasTransaction(String transactionId) {
    return _transactions[transactionId] != null;
  }

  /**
   * Send STOMP 1.2-formatted frame on this connection.
   *
   * @param frame
   *      STOMP 1.2 frame to send.
   * @return
   *      Future completed with value referencing sent frame upon success, or with error referencing StompException
   *      upon error.
   * @throws exception
   *      Should not, but may throw exception when invoking [WebSocket.add]
   *      (e.g. https://code.google.com/p/dart/issues/detail?id=11952).
   */
  Future<shared.Frame> _sendFrame(shared.Frame frame) {
    try {
      send(frame.toString());
      return new Future.value(frame);
    }
    catch (error) {
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_WEBSOCKET_ERROR, "Failed adding WebSocket message${error == null ? "." : (": ${error.toString()}")}");
      return new Future.error(stompException);
    }
  }
}