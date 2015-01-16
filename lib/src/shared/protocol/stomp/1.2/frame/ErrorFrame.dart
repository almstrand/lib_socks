part of shared_socks;

/**
 * STOMP 1.2 ERROR frame.
 */
class ErrorFrame extends Frame {

  static const String _COMMAND = "ERROR";

  ErrorFrame() : super(_COMMAND);

  /**
   * Construct new ERROR frame from parameters.
   *
   * @param body
   *      Body containing more detailed information of the error cause.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param contentType
   *      MIME type which describes the format of the body.
   * @param message
   *      Short description of the error.
   * @param version
   *      Comma-separated list of increasing STOMP protocol version numbers supported by the server.
   *      This header is set by the server to indicate supported protocol versions when protocol negotiation fails.
   * @param receiptId
   *      Value of the receipt ID header in the frame which this is a receipt for.
   * @param errorCode
   *      Numerical value specifying an error code. This value is sent in an "error-code" header that is not
   *      a standard header defined in the STOMP 1.2 protocol. If specified, this library properly marshalls/de-marshalls
   *      the value such that the error code of a received ERROR frame is automatically referenced in any StompException
   *      thrown on the client.
   */
  ErrorFrame.fromParams({String body, int contentLength, String contentType, String message, String version, String receiptId, int errorCode}) : super(_COMMAND) {

    // Store body
    this.body = body;

    // Store header values
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (contentType != null) headers[Frame.CONTENT_TYPE_HEADER] = contentType;
    if (message != null) headers[Frame.MESSAGE_HEADER] = message;
    if (version != null) headers[Frame.VERSION_HEADER] = version;
    if (receiptId != null) headers[Frame.RECEIPT_ID_HEADER] = receiptId;
    if (errorCode != null) headers[Frame.ERROR_CODE_HEADER] = errorCode.toString();
  }

  /**
   * Construct new ERROR frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the ERROR command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  ErrorFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => true;

  List<String> get _requiredHeaders => [
  ];

  List<String> get _allowedHeaders => [
      Frame.RECEIPT_ID_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.CONTENT_TYPE_HEADER,
      Frame.MESSAGE_HEADER,
      Frame.ERROR_CODE_HEADER
  ];
}