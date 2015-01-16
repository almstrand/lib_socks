part of shared_socks;

/**
 * STOMP 1.2 SEND frame.
 */
class SendFrame extends Frame {

  static const String _COMMAND = "SEND";

  SendFrame() : super(_COMMAND);

  /**
   * Construct new SEND frame from parameters.
   *
   * @param destination
   *      Opaque string identifying the destination where to send the message.
   * @param body
   *      The body to send.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param contentType
   *      MIME type which describes the format of the body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   * @param transactionId
   *      Name identifying transaction this message should be part of.
   */
  SendFrame.fromParams(String destination, {String body, int contentLength, String receipt, String contentType, String transactionId}) : super(_COMMAND) {

    // Store body.
    this.body = body;

    // Store header values.
    if (destination != null) headers[Frame.DESTINATION_HEADER] = destination;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
    if (contentType != null) headers[Frame.CONTENT_TYPE_HEADER] = contentType;
    if (transactionId != null) headers[Frame.TRANSACTION_HEADER] = transactionId;
  }

  /**
   * Construct new SEND frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the SEND command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  SendFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => true;

  List<String> get _requiredHeaders => [
      Frame.DESTINATION_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.CONTENT_LENGTH_HEADER,
      Frame.CONTENT_TYPE_HEADER,
      Frame.RECEIPT_HEADER,
      Frame.DESTINATION_HEADER,
      Frame.TRANSACTION_HEADER
  ];
}