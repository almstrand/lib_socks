part of client_socks;

class StompSubscription extends shared.StompSubscription {

  // Stream controller receiving events when a STOMP subscription is successfully established.
  StreamController<WebSocketStompConnection> subscribedStreamController = new StreamController<WebSocketStompConnection>.broadcast();

  // Stream controller receiving events when an error occurred in establishing a STOMP subscription.
  StreamController<shared.StompException> errorStreamController = new StreamController<shared.StompException>.broadcast();

  // Stream controller receiving events when a STOMP subscription is closed due to client calling un-subscribe method or the underlying STOMP connection being closed.
  StreamController<bool> cancelledStreamController = new StreamController<bool>.broadcast();

  // Stream controller receiving events when a STOMP message is received via this subscription.
  StreamController<shared.StompMessage> messageStreamController = new StreamController<shared.StompMessage>.broadcast();

  /**
   * Create new subscription.
   *
   * @param id
   *      Subscription ID unique to the STOMP connection.
   * @param destination
   *      Identifies the destination to which this class represents a subscription.
   * @param ack
   *      The valid values for the ack header are "auto", "client", or "client-individual". If the header is
   *      not set, it defaults to "auto".
   */
  StompSubscription(String id, String destination, {String ack}) : super(id, destination, ack);

  /**
   * Process message sent from server. After executing this method, the message is forwarded to all subscribed
   * connections.
   *
   * @param connection
   *      The WebSocket connection from which we received this message.
   * @param message
   *      Received message.
   * @return
   *      Future (without a value) once this handler is done processing the message, or an error with a StompException value upon error\.
   */
  Future _onMessage(WebSocketStompConnection connection, shared.StompMessage message) {

    // Are there any registered listener?
    if (messageStreamController.hasListener) {

      // Yes, add event to stream to notify listeners, and return future to signal that the STOMP frame was successfully processed.
      messageStreamController.add(message);
      return new Future.value();
    }
    else {

      // No, return future referencing an error to signal that the STOMP frame was not successfully processed.
      shared.StompException stompException = new shared.StompException(shared.StompException.ERROR_CODE_SUBSCRIBER_FAILED_PROCESSING, "Subscriber did not process message", details: "Subscriber did not process STOMP message received from server at ${connection._uri} via subscription '$id'.");
      return new Future.error(stompException);
    }
  }

  /**
   * Invoked when subscription is cancelled, either by calling the un-subscribe method, or by the underlying WebSocket
   * connection closing.
   *
   * @param connection
   *      The WebSocket connection on which the client is now un-subscribed from the destination.
   * @param implicit
   *      Set to true if the subscription was cancelled due to the underlying WebSocket connection closing.
   */
  void _onCancelled(bool implicit) {

    // Add event to stream to notify listeners, and return future to signal that the subscription was cancelled.
    cancelledStreamController.add(implicit);
  }

  /**
   * Invoked when subscription is successful.
   *
   * @param connection
   *      The WebSocket connection via which the client is now subscribed to the destination.
   */
  void _onSubscribed(WebSocketStompConnection connection) {

    // Add event to stream to notify listeners.
    subscribedStreamController.add(connection);
  }

  /**
   * Invoked when subscription attempt fails.
   *
   * @param exception
   *      StompException instance containing details on what caused the error.
   */
  void _onError(shared.StompException exception) {

    // Add event to stream to notify listeners.
    errorStreamController.add(exception);
  }

  Stream<WebSocketStompConnection> get onSubscribed => subscribedStreamController.stream;
  Stream<shared.StompMessage> get onMessage => messageStreamController.stream;
  Stream<shared.StompException> get onError => errorStreamController.stream;
  Stream<bool> get onCancelled => cancelledStreamController.stream;
}