part of shared_socks;

/**
 * STOMP 1.2 ACK frame.
 */
class AckFrame extends Frame {

  static const String _COMMAND = "ACK";

  AckFrame() : super(_COMMAND);

  /**
   * Construct new ACK frame from parameters.
   *
   * @param id
   *      ID matching the ACK header of the message being acknowledged.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   * @param transactionId
   *      Name identifying transaction this message should be part of.
   */
  AckFrame.fromParams(String id, {int contentLength, String receipt, String transactionId}) : super(_COMMAND) {

    // Store header values
    if (id != null) headers[Frame.ID_HEADER] = id;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
    if (transactionId != null) headers[Frame.TRANSACTION_HEADER] = transactionId;
  }

  /**
   * Construct new ACK frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the ACK command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  AckFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.ID_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.ID_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER,
      Frame.TRANSACTION_HEADER
  ];
}