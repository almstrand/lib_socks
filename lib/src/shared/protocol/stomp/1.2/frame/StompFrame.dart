part of shared_socks;

/**
 * STOMP 1.2 STOMP frame.
 */
class StompFrame extends Frame {

  static const String _COMMAND = "STOMP";

  StompFrame() : super(_COMMAND);

  /**
   * Construct new STOMP frame from parameters.
   *
   * @param acceptVersion
   *      Version of the STOMP protocol the client supports (i.e. the 'accept-version' header value).
   * @param host
   *      Name of a virtual host that the client wishes to connect to (i.e. the 'host' header value.)
   *      It is recommended clients set this to the host name that the socket was established against, or to any name
   *      of their choosing. If this header does not match a known virtual host, servers supporting virtual hosting
   *      may select a default virtual host or reject the connection.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   * @param login
   *      User identifier used to authenticate against a secured STOMP server.
   * @param passcode
   *      Password used to authenticate against a secured STOMP server.
   * @param heartBeat
   *      Heart-beat setting specified by two comma-separated numbers. Refer to the STOMP 1.2 specification for details.
   */
  StompFrame.fromParams(String acceptVersion, String host, {int contentLength, String receipt, String login, String passcode, String heartBeat}) : super(_COMMAND) {

    // Store header values.
    if (acceptVersion != null) headers[Frame.ACCEPT_VERSION_HEADER] = acceptVersion;
    if (host != null) headers[Frame.HOST_HEADER] = host;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
    if (login != null) headers[Frame.LOGIN_HEADER] = login;
    if (passcode != null) headers[Frame.PASSCODE_HEADER] = passcode;
    if (heartBeat != null) headers[Frame.HEART_BEAT_HEADER] = heartBeat;
  }

  /**
   * Construct new STOMP frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the STOMP command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  StompFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  /**
   * Perform additional validation specific to this message. Basic validation, including checking for required/allowed
   * headers and the presence of a body, is handled in the super class.
   *
   * @return
   *      Null if command passes validation, or an ErrorCommand instance to be sent to client if validation fails.
   */
  void _validate() {

    // Ensure required accept-version is set and client can accept version 1.2 (only version currently supported by this library.)
    if (acceptVersion == null || !acceptVersion.contains(Version.VERSION_1_2)) {

      // Throw exception containing details on why validation failed.
      throw new StompException(StompException.ERROR_CODE_PROTOCOL_NEGOTIATION_FAILED, "Protocol negotiation failed", details: "Supported protocol versions are {${Version.VERSION_1_2}}.", receiptId: receipt, frame: frame);
    }
  }

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.ACCEPT_VERSION_HEADER,
      Frame.HOST_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER,
      Frame.ACCEPT_VERSION_HEADER,
      Frame.HOST_HEADER,
      Frame.LOGIN_HEADER,
      Frame.PASSCODE_HEADER,
      Frame.HEART_BEAT_HEADER
  ];
}