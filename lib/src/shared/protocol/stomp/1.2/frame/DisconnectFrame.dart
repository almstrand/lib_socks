part of shared_socks;

/**
 * STOMP 1.2 DISCONNECT frame.
 */
class DisconnectFrame extends Frame {

  static const String _COMMAND = "DISCONNECT";

  DisconnectFrame() : super(_COMMAND);

  /**
   * Construct new DISCONNECT frame from parameters.
   *
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   */
  DisconnectFrame.fromParams({int contentLength, String receipt}) : super(_COMMAND) {

    // Store header values
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
  }

  /**
   * Construct new DISCONNECT frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the DISCONNECT command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  DisconnectFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
  ];

  List<String> get _allowedHeaders => [
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER
  ];
}