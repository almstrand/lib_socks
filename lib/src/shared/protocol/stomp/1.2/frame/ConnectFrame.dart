part of shared_socks;

/**
 * STOMP 1.2 CONNECT frame.
 */
class ConnectFrame extends Frame {

  static const String _COMMAND = "CONNECT";

  ConnectFrame() : super(_COMMAND);

  /**
   * Construct new CONNECT frame from parameters.
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
   * @param login
   *      User identifier used to authenticate against a secured STOMP server.
   * @param passcode
   *      Password used to authenticate against a secured STOMP server.
   * @param guaranteedHeartBeat
   *      Smallest guaranteed number of milliseconds between frames sent to server, or null (default) if this
   *      implementation cannot guarantee such minimum heart-beat interval.
   * @param desiredHeartBeat
   *      Desired number of milliseconds between frames received from server, or null (default) if this
   *      implementation does not want to receive frames at such minimum heart-beat interval.
   */
  ConnectFrame.fromParams(String acceptVersion, String host, {int contentLength, String login, String passcode, int guaranteedHeartBeat, int desiredHeartBeat}) : super(_COMMAND) {

    // Store header values
    if (acceptVersion != null) headers[Frame.ACCEPT_VERSION_HEADER] = acceptVersion;
    if (host != null) headers[Frame.HOST_HEADER] = host;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (login != null) headers[Frame.LOGIN_HEADER] = login;
    if (passcode != null) headers[Frame.PASSCODE_HEADER] = passcode;
    if (guaranteedHeartBeat == null) guaranteedHeartBeat = 0;
    if (desiredHeartBeat == null) desiredHeartBeat = 0;
    if (guaranteedHeartBeat != 0 || desiredHeartBeat != 0) headers[Frame.HEART_BEAT_HEADER] = "$guaranteedHeartBeat,$desiredHeartBeat";
  }

  /**
   * Construct new CONNECT frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the CONNECT command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  ConnectFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  /**
   * Perform additional validation specific to this message. Basic validation, including checking for required/allowed
   * headers and the presence of a body, is handled in the super class.
   *
   * @throws
   *      StompException if this is an invalid STOMP frame.
   */
  void _validate() {

    // Ensure required accept-version is set and client can accept STOMP version 1.2.
    if (acceptVersion == null || !acceptVersion.contains(Version.VERSION_1_2)) {

      // Throw exception containing details on why validation failed.
      throw new StompException(StompException.ERROR_CODE_PROTOCOL_NEGOTIATION_FAILED, "Protocol negotiation failed", details: "Supported protocol versions are ${Version.VERSION_1_2}.", receiptId: receipt, frame: frame);
    }

    // Validate heart-beat header format.
    try {
      guaranteedHeartBeat;
      desiredHeartBeat;
    }
    catch (e) {

      // Throw exception containing details on why validation failed.
      throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame", details: "Invalid heart-heat format", receiptId: receipt, frame: frame);
    }

    // Ensure no heart-beat is specified (currently not supported.)
    if (heartBeat != null) {

      // Throw exception containing details on why validation failed.
      throw new StompException(StompException.ERROR_CODE_NOT_IMPLEMENTED, "Not implemented", details: "Library does not yet support client or server heart-beats.", receiptId: receipt, frame: frame);
    }
  }

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.ACCEPT_VERSION_HEADER,
      Frame.HOST_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.CONTENT_LENGTH_HEADER,
      Frame.ACCEPT_VERSION_HEADER,
      Frame.HOST_HEADER,
      Frame.LOGIN_HEADER,
      Frame.PASSCODE_HEADER,
      Frame.HEART_BEAT_HEADER
  ];
}