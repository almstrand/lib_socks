part of shared_socks;

/**
 * STOMP 1.2 CONNECTED frame.
 */
class ConnectedFrame extends Frame {

  static const String _COMMAND = "CONNECTED";

  ConnectedFrame() : super(_COMMAND);

  /**
   * Construct new CONNECTED frame from parameters.
   *
   * @param version
   *      Version of the STOMP protocol the session will be using.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param session
   *      Session identifier.
   * @param server
   *      Field containing information about the STOMP server. The field must contain a server-name
   *      field and may be followed by optional comment fields delimited by a space character. Refer to the STOMP 1.2
   *      specification for the correct syntax of the server and server-name components.
   * @param guaranteedHeartBeat
   *      Smallest guaranteed number of milliseconds between frames sent to each connected client, or
   *      null (default) if this implementation cannot guarantee such minimum heart-beat interval.
   * @param desiredHeartBeat
   *      Desired number of milliseconds between frames received from each connected client, or null
   *      (default) if this implementation does not want to receive frames at such minimum heart-beat interval.
   */
  ConnectedFrame.fromParams(String version, {int contentLength, String session, String server, int guaranteedHeartBeat, int desiredHeartBeat}) : super(_COMMAND) {

    // Store header values
    if (version != null) headers[Frame.VERSION_HEADER] = version;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (session != null) headers[Frame.SESSION_HEADER] = session;
    if (server != null) headers[Frame.SERVER_HEADER] = server;
    if (guaranteedHeartBeat == null) guaranteedHeartBeat = 0;
    if (desiredHeartBeat == null) desiredHeartBeat = 0;
    if (guaranteedHeartBeat != 0 || desiredHeartBeat != 0) headers[Frame.HEART_BEAT_HEADER] = "$guaranteedHeartBeat,$desiredHeartBeat";
  }

  /**
   * Construct new CONNECTED frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the CONNECTED command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  ConnectedFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  /**
   * Perform additional validation specific to this message. Basic validation, including checking for required/allowed
   * headers and the presence of a body, is handled in the super class.
   *
   * @throws
   *      StompException if this is an invalid STOMP frame.
   */
  void _validate() {

    // Ensure negotiated protocol version is supported
    if (version == null || !version.contains(Version.VERSION_1_2)) {

      // Throw exception containing details on why validation failed
      throw new StompException(StompException.ERROR_CODE_PROTOCOL_NEGOTIATION_FAILED, "Protocol negotiation failed", details: "Supported protocol versions are ${Version.VERSION_1_2}.", receiptId: receipt);
    }

    // Validate heart-beat header format
    try {
      guaranteedHeartBeat;
      desiredHeartBeat;
    }
    catch (e) {

      // Throw exception containing details on why validation failed
      throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame", details: "Invalid heart-heat format.", receiptId: receipt, frame: frame);
    }

    // Ensure no heart-beat is specified (currently not supported)
    if (heartBeat != null) {

      // Throw exception containing details on why validation failed
      throw new StompException(StompException.ERROR_CODE_NOT_IMPLEMENTED, "Not implemented", details: "Library does not yet support client or server heart-beats.", receiptId: receipt, frame: frame);
    }
  }

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.VERSION_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.CONTENT_LENGTH_HEADER,
      Frame.VERSION_HEADER,
      Frame.SESSION_HEADER,
      Frame.SERVER_HEADER,
      Frame.HEART_BEAT_HEADER
  ];
}