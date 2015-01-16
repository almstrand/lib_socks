part of shared_socks;

/**
 * STOMP 1.2 UNSUBSCRIBE frame.
 */
class UnsubscribeFrame extends Frame {

  static const String _COMMAND = "UNSUBSCRIBE";

  UnsubscribeFrame() : super(_COMMAND);

  /**
   * Construct new UNSUBSCRIBE frame from parameters.
   *
   * @param id
   *      Identifies the subscription to remove.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   */
  UnsubscribeFrame.fromParams(String id, {int contentLength, String receipt}) : super(_COMMAND) {

    // Store body
    this.body = body;

    // Store header values
    if (id != null) headers[Frame.ID_HEADER] = id;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
  }

  /**
   * Construct new UNSUBSCRIBE frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the UNSUBSCRIBE command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  UnsubscribeFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.ID_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.ID_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER
  ];
}