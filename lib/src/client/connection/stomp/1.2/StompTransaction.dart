part of client_socks;

/**
 * Server-side representation of a STOMP transaction.
 */
class StompTransaction extends shared.StompTransaction {

  static Logger _log = new Logger("StompTransaction");

  // Connection this transaction belongs to.
  WebSocketStompConnection _connection;

  /**
   * Construct new transaction.
   *
   * @param id
   *      Transaction ID unique to the STOMP connection.
   * @param _connection
   *      The connection over which the transaction is performed.
   */
  StompTransaction(String id, WebSocketStompConnection this._connection) : super(id);

  /**
   * Send transactional message to specified server destination.
   *
   * @param destination
   *      Identifies the destination where to send the message.
   * @param message
   *      Message to send to server.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param contentType
   *      MIME type which describes  the format of the message.
   * @param withReceipt
   *      Set to true if the server must respond with a receipt or error to confirm a successful or failed
   *      processing of this message prior to completing the future returned by this method. If set to false, the method
   *      completes the future immediately with a value, where after any resulting errors are communicated via the
   *      onStompError stream.
   * @return
   *      If [withReceipt] is false, this method returns a future that is immediately completed with a reference to the
   *      sent frame. In that case, any server-side errors in processing the frame are communicated via the onStompError
   *      stream. If [withReceipt] is true, this method returns a future to be completed with a reference to the
   *      resulting RECEIPT frame sent back by the server upon successfully processing the message on
   *      the server, or completed with an error referencing a StompException instance upon error.
   */
  Future<shared.Frame> send(String destination, String message, {int contentLength, String contentType, bool withReceipt: true}) {
    String transactionId = id;
    _log.info(() => ("Sending STOMP message via transaction '$transactionId' to destination '$destination' at ${_connection._uri}: ${message == null ? "" : shared.Logging.stripNewLinesAndLimitLength(message, maxChars: 64)}"));
    shared.SendFrame sendFrame = new shared.SendFrame.fromParams(destination, body: message, contentLength: contentLength, contentType: contentType, transaction: transactionId);
    return _connection._sendFrame(sendFrame, withReceipt: withReceipt);
  }

  /**
   * Commit transaction.
   *
   * @param withReceipt
   *      Set to true if the server must respond with a receipt or error to confirm a successful or failed
   *      processing of this message prior to completing the future returned by this method. If set to false, the method
   *      completes the future immediately with a value, where after any resulting errors are communicated via the
   *      onStompError stream.
   * @return
   *      If [withReceipt] is false, this method returns a future that is immediately completed with a reference to the
   *      WebSocket connection. In that case, any server-side errors in processing the frame are communicated via the
   *      onStompError stream. If [withReceipt] is true, this method returns a future to be completed with a reference
   *      to the WebSocket connection upon successfully processing the message on the server, or completed with an error
   *      referencing a StompException instance upon error.
   */
  Future<WebSocketStompConnection> commit({bool withReceipt: true}) {
    String transactionId = id;
    _log.info(() => "Committing transaction '$transactionId' at ${_connection._uri}.");
    shared.CommitFrame commitFrame = new shared.CommitFrame.fromParams(transactionId);
    Completer<WebSocketStompConnection> completer = new Completer<WebSocketStompConnection>();
    _connection._sendFrame(commitFrame, withReceipt: withReceipt)
    .then((shared.Frame frame) {
      completer.complete(_connection);
    })
    .catchError((stompException) {
      completer.completeError(stompException);
    });
    return completer.future;
  }

  /**
   * Abort transaction.
   *
   * @param withReceipt
   *      Set to true if the server must respond with a receipt or error to confirm a successful or failed
   *      processing of this message prior to completing the future returned by this method. If set to false, the method
   *      completes the future immediately with a value, where after any resulting errors are communicated via the
   *      onStompError stream.
   * @return
   *      If [withReceipt] is false, this method returns a future that is immediately completed with a reference to the
   *      WebSocket connection. In that case, any server-side errors in processing the frame are communicated via the
   *      onStompError stream. If [withReceipt] is true, this method returns a future to be completed with a reference
   *      to the WebSocket connection upon successfully processing the message on the server, or completed with an error
   *      referencing a StompException instance upon error.
   */
  Future<WebSocketStompConnection> abort({bool withReceipt: true}) {
    String transactionId = id;
    _log.info(() => "Aborting transaction '$transactionId' at ${_connection._uri}.");
    shared.AbortFrame abortFrame = new shared.AbortFrame.fromParams(transactionId);
    Completer<WebSocketStompConnection> completer = new Completer<WebSocketStompConnection>();
    _connection._sendFrame(abortFrame, withReceipt: withReceipt)
    .then((shared.Frame frame) {
      completer.complete(_connection);
    })
    .catchError((stompException) {
      completer.completeError(stompException);
    });
    return completer.future;
  }
}