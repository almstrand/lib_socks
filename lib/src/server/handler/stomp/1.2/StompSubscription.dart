part of server_socks;

/**
 * Server-side representation of a STOMP subscription.
 */
class StompSubscription extends shared.StompSubscription {

  // Acknowledgement ID sequence generator.
  static int _nextAckId = 0;

  // Connection used to establish this subscription.
  WebSocketStompConnection _connection;

  // Map of messages sent to subscriber awaiting ACK or NACK frames from client to determine whether client succeeded/failed in processing the message.
  Map<int, shared.MessageFrame> _pendingMessageAck = new Map<int, shared.MessageFrame>();

  /**
   * Create new subscription to [destination].
   *
   * @param id
   *      Unique ID allowing the client and server to relate subsequent MESSAGE or UNSUBSCRIBE frames to the original
   *      subscription.
   * @param destination
   *      Destination to which this class represents a subscription.
   * @param ack
   *      Subscription's ack setting. The valid values for the ack header are "auto", "client", or "client-individual".
   *      If the header is not set, it defaults to "auto". Refer to
   *      https://stomp.github.io/stomp-specification-1.2.html#SUBSCRIBE_ack_Header for details.
   * @param connection
   *      The WebSocket connection used to establish this subscription.
   */
  StompSubscription(String id, String destination, String ack, WebSocketStompConnection this._connection) : super(id, destination, ack);

  /**
   * Acknowledge client's successful processing of received message.
   *
   * @param transactionId
   *      ID of transaction if this message is part of a transaction, or null otherwise.
   * @param messageId
   *      The message ID previously sent to client in the STOMP MESSAGE frame's 'ack' header.
   * @param onNack
   *      Function to invoke to notify STOMP destination of successfully processing message.
   * @return
   *      True if a valid message ID was specified, identifying a message previously sent to client.
   */
  bool _onAck(String transactionId, int messageId, void onAck(String transaction, int messageId, shared.MessageFrame messageFrame, StompSubscription subscription)) {
    if (usesClientAck) {
      bool found = false;
      _pendingMessageAck.forEach((int thisMessageId, shared.MessageFrame messageFrame) {
        if (messageId <= thisMessageId) {
          found = true;
          onAck(transactionId, thisMessageId, messageFrame, this);
        }
      });
      return found;
    }
    else if (usesClientIndividualAck) {
      shared.MessageFrame messageFrame = _pendingMessageAck[messageId];
      if (messageFrame == null) return false;
      onAck(transactionId, messageId, messageFrame, this);
    }
    return true;
  }

  /**
   * Acknowledge client's failed processing of received message.
   *
   * @param transactionId
   *      ID of transaction if this message is part of a transaction, or null otherwise.
   * @param messageId
   *      The message ID previously sent to client in the STOMP MESSAGE frame's 'ack' header.
   * @param onNack
   *      Function to invoke to notify STOMP destination of failed message processing.
   * @return
   *      True if a valid message ID was specified, identifying a message previously sent to client.
   */
  bool _onNack(String transactionId, int messageId, void onNack(String transaction, int messageId, shared.MessageFrame messageFrame, StompSubscription subscription, bool confirmed)) {
    if (usesClientAck) {
      bool found = false;
      _pendingMessageAck.forEach((int thisMessageId, shared.MessageFrame messageFrame) {
        if (messageId <= thisMessageId) {
          found = true;
          onNack(transactionId, thisMessageId, messageFrame, this, true);
        }
      });
      return found;
    }
    else if (usesClientIndividualAck) {
      shared.MessageFrame messageFrame = _pendingMessageAck[messageId];
      if (messageFrame == null) return false;
      onNack(transactionId, messageId, messageFrame, this, true);
    }
    return true;
  }

  /**
   * Destroy subscription and call onNack for any message sent to client for which the server has not yet received a
   * positive or negative acknowledgment from the connected client.
   *
   * @param onNack
   *      Function to invoke to notify STOMP destination of client failure to process message.
   */
  void _cancel(void onNack(String transactionId, int messageId, shared.MessageFrame messageFrame, StompSubscription subscription, bool confirmed)) {
    _pendingMessageAck.forEach((int thisMessageId, shared.MessageFrame messageFrame) {
      onNack(null, thisMessageId, messageFrame, this, false);
    });
    _pendingMessageAck.clear();
  }

  /**
   * Send message to subscriber.
   *
   * @param messageFrame
   *      Message to send.
   * @return
   *      Future referencing acknowledgment ID of sent STOMP MESSAGE frame, or a StompException upon error.
   */
  Future<int> _send(shared.MessageFrame messageFrame) {
    Completer<int> sendCompleter = new Completer<int>();
    messageFrame.subscription = id;
    int messageAckId;
    if (usesAck) {
      messageAckId = ++_nextAckId;
      messageFrame.ack = messageAckId.toString();
      _pendingMessageAck[messageAckId] = messageFrame;
    }
    _connection._sendFrame(messageFrame)
    .then((shared.Frame sentMessageFrame) {
      sendCompleter.complete(messageAckId);
    })
    .catchError((shared.StompException stompException) {
      if (usesAck) {
        _pendingMessageAck.remove(messageAckId);
      }
      return new Future.error(stompException);
    });
    return sendCompleter.future;
  }

  /**
   * Get connection used to establish this subscription.
   */
  WebSocketStompConnection get connection => _connection;
}