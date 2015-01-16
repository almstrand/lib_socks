part of shared_socks;

/**
 * STOMP 1.2 ABORT frame.
 */
class AbortFrame extends Frame {

  static const String _COMMAND = "ABORT";

  AbortFrame() : super(_COMMAND);

  /**
   * Construct new ABORT frame from parameters.
   *
   * @param transactionId
   *      The identifier of the transaction to abort.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   */
  AbortFrame.fromParams(String transactionId, {int contentLength, String receipt}) : super(_COMMAND) {

    // Store header values
    if (transactionId != null) headers[Frame.TRANSACTION_HEADER] = transactionId;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
  }

  /**
   * Construct new ABORT frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the ABORT command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  AbortFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.TRANSACTION_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.TRANSACTION_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER
  ];
}