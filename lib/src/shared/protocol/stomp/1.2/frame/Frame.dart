part of shared_socks;

/**
 * STOMP 1.2 frame.
 */
abstract class Frame {

  // 'content-length' header name.
  static const String CONTENT_LENGTH_HEADER = "content-length";

  // 'content-type' header name.
  static const String CONTENT_TYPE_HEADER = "content-type";

  // 'receipt' header name.
  static const String RECEIPT_HEADER = "receipt";

  // 'accept-version' header name.
  static const String ACCEPT_VERSION_HEADER = "accept-version";

  // 'host' header name.
  static const String HOST_HEADER = "host";

  // 'login' header name.
  static const String LOGIN_HEADER = "login";

  // 'passcode' header name.
  static const String PASSCODE_HEADER = "passcode";

  // 'heart-beat' header name.
  static const String HEART_BEAT_HEADER = "heart-beat";

  // 'version' header name.
  static const String VERSION_HEADER = "version";

  // 'session' header name.
  static const String SESSION_HEADER = "session";

  // 'server' header name.
  static const String SERVER_HEADER = "server";

  // 'destination' header name.
  static const String DESTINATION_HEADER = "destination";

  // 'transaction' header name.
  static const String TRANSACTION_HEADER = "transaction";

  // 'id' header name.
  static const String ID_HEADER = "id";

  // 'ack' header name.
  static const String ACK_HEADER = "ack";

  // 'message-id' header name.
  static const String MESSAGE_ID_HEADER = "message-id";

  // 'subscription' header name.
  static const String SUBSCRIPTION_HEADER = "subscription";

  // 'receipt-id' header name.
  static const String RECEIPT_ID_HEADER = "receipt-id";

  // 'message' header name.
  static const String MESSAGE_HEADER = "message";

  // 'error-code' header name.
  static const String ERROR_CODE_HEADER = "error-code";

  // Command name.
  String command;

  // Command frame.
  String frame;

  // Command headers.
  Map<String, String> headers = new Map<String, String>();

  // Command body.
  String body;

  Frame(String this.command);

  /**
   * Construct frame from message after extracting the headers and body.
   *
   * @param command
   *      Command name.
   * @param frame
   *      Command frame.
   * @param headers
   *      Command headers.
   * @param body
   *      Command body.
   */
  Frame._fromParsedMessage(String this.command, String this.frame, Map<String, String> this.headers, String this.body);

  /**
   * Factory constructing an STOMP 1.2 frame from a received WebSocket message.
   *
   * @param message
   *      Text message received via WebSocket connection.
   * @param maxFrameHeaders
   *      Maximum limit on the number of frame headers allowed in a single frame. An error frame will be
   *      sent to clients or servers which send messages that exceed this limit, followed by closing the client
   *      connection. Set to null to impose no limit.
   * @param maxHeaderLen
   *      Maximum length of header lines, expressed in number of characters. An error frame will be sent to
   *      clients or servers which send messages that exceed this limit, followed by closing the client connection.
   *      Set to null to impose no limit.
   * @param maxBodyLen
   *      Maximum size of a frame body, expressed in number of characters. An error frame will be sent to
   *      clients or servers which send messages that exceed this limit, followed by closing the client connection. Set
   *      to null to impose no limit.
   * @throws StompException
   *      when failing to parse received message.
   */
  factory Frame.fromMessage(String message, {int maxFrameHeaders, int maxHeaderLen, int maxBodyLen}) {

    // Variable to hold any error message.
    String errorMessage = "";

    // Variable to hold the headers
    Map<String, String> headers = new Map<String, String>();

    // Frame body.
    String body = "";

    // Get the command.
    String command;
    int pos = message.indexOf("\x0A");
    if (pos < 0) {
      errorMessage += "Expecting STOMP command at position 0.\n";
    }
    else {
      if (pos > 0 && message[pos - 1] == "\x0D") {
        command = message.substring(0, pos - 1);
      }
      else {
        command = message.substring(0, pos);
      }
    }
    pos++;

    // Parse headers.
    int nextLineFeed;
    int headerCount = 0;
    while ((nextLineFeed = message.indexOf("\x0A", pos)) > pos) {
      String header = message.substring(pos, nextLineFeed);
      int colonPos = header.indexOf(":");
      if (colonPos >= 0) {

        // Increment header counter.
        headerCount++;

        // Report error if header too big per configured server limitations.
        int headerLen = header.length;
        if (maxHeaderLen != null && headerLen > maxHeaderLen) {
          errorMessage += "Server limits on allowed header size exceeded at position $pos.\n";
        }

        // Extract and validate the header name/value.
        String headerName = _unescape(header.substring(0, colonPos));
        String headerValue = _unescape(header.substring(colonPos + 1, header.endsWith("\x0D") ? headerLen - 1 : headerLen));
        if (headerName.length == 0) {
          errorMessage += "Header starting at position $pos has a 0-length name.\n";
        }
        if (headerName.contains("\x0A") || headerName.contains("\x0D") || headerName.contains("\\")) {
          errorMessage += "Name of header at position $pos contains an invalid character.\n";
        }
        if (headerValue.contains("\x0A") || headerValue.contains("\x0D") || headerValue.contains(":") || headerValue.contains("\\")) {
          errorMessage += "Value of header at position $pos contains an invalid character.\n";
        }

        // Is this the first occurrence of this header name?
        if (headers[headerName] == null) {

          // Yes, per the specification we should honor the first occurrence of a repeated header, so use this one.
          headers[headerName] = headerValue;
        }
      }
      else if (pos != 0) {
        String headerName;
        errorMessage += "Header at position $pos is missing the ':' delimiter.\n";
      }
      if (nextLineFeed < (message.length - 1) && message[nextLineFeed + 1] == "\x0D") {
        pos = nextLineFeed + 2;
      }
      else {
        pos = nextLineFeed + 1;
      }
    }

    // Report error and close connection if too many headers.
    if (maxFrameHeaders != null && headerCount > maxFrameHeaders) {
      errorMessage += "Server limits on allowed header count exceeded.\n";
    }

    // Process the body.
    if (pos < message.length && message[pos] == "\x0D") {
      pos++;
    }
    if (pos >= message.length || message[pos] != "\x0A") {
      errorMessage += "Expecting newline character at position $pos to mark end of headers.\n";
    }
    else {
      pos++;

      // Is a content-length header set?
      String contentLength = headers[Frame.CONTENT_LENGTH_HEADER];
      if (contentLength != null) {

        // Yes parse out the numerical byte-count value (NOTE: in WebSocket communication we don't completely validate nor use this value because: 1) WebSocket messages will always contain the entire frame, 2) frames must still be null-terminated even in the presence of a content-length header (so we find the body end by simply looking in reverse for null), and 3) validating that there is a null characters following the body at the position specified by the content-length bytes in an UTF-8 world is quite expensive and would involve converting the entire string to a byte array.
        int contentLengthByteCount = int.parse(contentLength, onError: ((String str) => null));
        if (contentLengthByteCount == null) {
          errorMessage += "Invalid '${Frame.CONTENT_LENGTH_HEADER}' header value.\n";
        }
      }

      // Determine expected null-terminator position.
      int nullTerminatorPos = message.lastIndexOf("\x00");
      if (nullTerminatorPos < pos) {
        errorMessage += "Frame must be NULL-terminated.\n";
      }

      // If no errors occurred, extract body.
      if (errorMessage.length == 0) {
        body = message.substring(pos, nullTerminatorPos);

        // Report error and close connection if body is too large.
        if (maxBodyLen != null && body.length > maxBodyLen) {
          errorMessage += "Server limits on allowed frame body size exceeded.\n";
        }
      }
    }

    // Did any errors occur?
    if (errorMessage.length == 0) {

      // No, instantiate frame
      Frame frameInstance;
      switch (command) {
        case "SEND" :
          frameInstance = new SendFrame._fromMessage(message, headers, body);
          break;
        case "SUBSCRIBE" :
          frameInstance = new SubscribeFrame._fromMessage(message, headers, body);
          break;
        case "UNSUBSCRIBE":
          frameInstance = new UnsubscribeFrame._fromMessage(message, headers, body);
          break;
        case "BEGIN":
          frameInstance = new BeginFrame._fromMessage(message, headers, body);
          break;
        case "COMMIT":
          frameInstance = new CommitFrame._fromMessage(message, headers, body);
          break;
        case "ABORT":
          frameInstance = new AbortFrame._fromMessage(message, headers, body);
          break;
        case "ACK":
          frameInstance = new AckFrame._fromMessage(message, headers, body);
          break;
        case "NACK":
          frameInstance = new NackFrame._fromMessage(message, headers, body);
          break;
        case "DISCONNECT":
          frameInstance = new DisconnectFrame._fromMessage(message, headers, body);
          break;
        case "CONNECT":
          frameInstance = new ConnectFrame._fromMessage(message, headers, body);
          break;
        case "STOMP":
          frameInstance = new StompFrame._fromMessage(message, headers, body);
          break;
        case "CONNECTED":
          frameInstance = new ConnectedFrame._fromMessage(message, headers, body);
          break;
        case "MESSAGE":
          frameInstance = new MessageFrame._fromMessage(message, headers, body);
          break;
        case "RECEIPT":
          frameInstance = new ReceiptFrame._fromMessage(message, headers, body);
          break;
        case "ERROR":
          frameInstance = new ErrorFrame._fromMessage(message, headers, body);
          break;
        default:
          throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Invalid STOMP command", details: "$command is not a valid STOMP ${Version.VERSION_1_2} command", receiptId: headers[Frame.RECEIPT_HEADER], frame: message);
          break;
      }

      // Validate the frame (throwing StompException if validation fails.)
      frameInstance.validate();

      // Return frame
      return frameInstance;
    }

    // Otherwise, respond with error and close connection if no command was present.
    else {

      // Throw exception detailing parse error.
      throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame received", details: errorMessage, receiptId: headers[Frame.RECEIPT_HEADER], frame: message);
    }
  }

  String get _serializedHeaders {
    String serializedHeaders = "";
    headers.forEach((String name, value) {
      serializedHeaders += "$name:$value\n";
    });
    return serializedHeaders;
  }

  /**
   * Un-escape value.
   */
  static String _unescape(String value) {
    String unescapedValue = value.contains("\\r") ? value.replaceAll("\\r", "\x0D") : value;
    unescapedValue = unescapedValue.contains("\\n") ? unescapedValue.replaceAll("\\n", "\x0A") : unescapedValue;
    unescapedValue = unescapedValue.contains("\\c") ? unescapedValue.replaceAll("\\c", "\x3A") : unescapedValue;
    unescapedValue = unescapedValue.contains("\\\\") ? unescapedValue.replaceAll("\\\\", "\x5C") : unescapedValue;
    return unescapedValue;
  }

  /**
   * Implemented by concrete class to specify allowed STOMP 1.2 headers.
   */
  List<String> get _requiredHeaders;

  /**
   * Implemented by concrete class to specify required STOMP 1.2 headers.
   */
  List<String> get _allowedHeaders;

  /**
   * Implemented by concrete class to specify whether the STOMP 1.2 frame may have a body.
   */
  bool get _isBodyAllowed;

  /**
   * Determine whether this frame is formatted according to the 1.2 STOMP specification.
   *
   * @throws
   *      StompException if this is an invalid STOMP frame.
   */
  void validate() {

    // Ensure no body is present unless allowed.
    if (body.length > 0 && !_isBodyAllowed) {

      // Throw exception describing cause for validation failing.
      throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame received", details: "$command frames must not include a body.", receiptId: receipt, frame: frame);
    }

    // Ensure all required headers are present.
    for (String requiredHeader in _requiredHeaders) {
      if (headers[requiredHeader] == null) {

        // Throw exception describing cause for validation failing.
        throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame received", details: "$command frames must include '$requiredHeader' header.", receiptId: receipt, frame: frame);
      }
    }

    // Ensure all headers are allowed.
    for (String header in headers.keys) {
      if (!_allowedHeaders.contains(header)) {

        // Throw exception describing cause for validation failing.
        throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame received", details: "$command frames must not include '$header' header.", receiptId: receipt, frame: frame);
      }
    }

    // Perform any additional command-specific validation.
    _validate();
  }

  /**
   * Overridden by sub-class to perform additional validation specific to concrete frame. Basic validation, including
   * checking for required/allowed headers and the presence of a body, is handled in this class.
   *
   * @throws
   *      StompException if this is an invalid STOMP frame.
   */
  void _validate() {
  }

  /**
   * Get the octet count for the length of the message body. If non-null, the STOMP 1.2 specification states that
   * this number of octets must be read, regardless of whether or not there are NULL octets in the body. However,
   * this server implementation performs limited validation of this header value and does not consult
   * this value in determining the octet position marking the end of a frame. This is justified as WebSocket messages
   * are not chunked. As such, a reliable and efficient method (not requiring e.g. UTF-8-to-byte conversion) of
   * determining the end position is employed involving simply finding the last NULL character in the frame body.
   */
  int get contentLength {
    String contentLength = headers[Frame.CONTENT_LENGTH_HEADER];
    if (contentLength == null) return null;
    return int.parse(contentLength);
  }

  /**
   * Get the MIME type which describes the format of the frame body (i.e. the 'content-type' header value),
   * or null if undefined.
   */
  String get contentType => headers[Frame.CONTENT_TYPE_HEADER];

  void set contentType(String contentType) {
    headers[Frame.CONTENT_TYPE_HEADER] = contentType;
  }

  /**
   * Get the arbitrary receipt value (i.e. the 'receipt' header value) which, when assigned a non-null value,
   * causes the server to acknowledge the processing of the client frame with a RECEIPT frame.
   */
  String get receipt => headers[Frame.RECEIPT_HEADER];

  void set receipt(String receipt) {
    headers[Frame.RECEIPT_HEADER] = receipt;
  }

  /**
   * Get the value of the receipt ID header in the frame which this is a receipt for.
   */
  String get receiptId => headers[Frame.RECEIPT_ID_HEADER];

  void set receiptId(String receiptId) {
    headers[Frame.RECEIPT_ID_HEADER] = receiptId;
  }

  /**
   * Get the short description of an error (i.e. the 'error' header value), or null if undefined.
   */
  String get message => headers[Frame.MESSAGE_HEADER];

  void set message(String message) {
    headers[Frame.MESSAGE_HEADER] = message;
  }

  /**
   * Get the comma-separated list of increasing STOMP protocol version numbers supported by the server (i.e.
   * the 'version' header value.) This header is set by the server to indicate supported protocol versions
   * when protocol negotiation fails.
   */
  String get version => headers[Frame.VERSION_HEADER];

  void set version(String version) {
    headers[Frame.VERSION_HEADER] = version;
  }

  /**
   * Get the version of the STOMP protocol the client supports (i.e. the 'accept-version' header value) sent
   * a client connects by issuing a CONNECT or STOMP command.
   */
  String get acceptVersion => headers[Frame.ACCEPT_VERSION_HEADER];

  void set acceptVersion(String acceptVersion) {
    headers[Frame.ACCEPT_VERSION_HEADER] = acceptVersion;
  }

  /**
   * Get the name of a virtual host that the client wishes to connect to (i.e. the 'host' header value.) It
   * is recommended clients set this to the host name that the socket was established against, or to any name
   * of their choosing. If this header does not match a known virtual host, servers supporting virtual hosting
   * may select a default virtual host or reject the connection.
   */
  String get host => headers[Frame.HOST_HEADER];

  void set host(String host) {
    headers[Frame.HOST_HEADER] = host;
  }

  /**
   * Get the user identifier used to authenticate against a secured STOMP server.
   */
  String get login => headers[Frame.LOGIN_HEADER];

  void set login(String login) {
    headers[Frame.LOGIN_HEADER] = login;
  }

  /**
   * Get the password used to authenticate against a secured STOMP server.
   */
  String get passcode => headers[Frame.PASSCODE_HEADER];

  void set passcode(String passcode) {
    headers[Frame.PASSCODE_HEADER] = passcode;
  }

  /**
   * Get the heart-beat setting specified by two comma-separated numbers. Also see [guaranteedHeartBeat] and
   * [desiredHeartBeat] for convenience methods that may be used to parse heart-beat header values.
   */
  String get heartBeat => headers[Frame.HEART_BEAT_HEADER];

  void set heartBeat(String heartBeat) {
    headers[Frame.HEART_BEAT_HEADER] = heartBeat;
  }

  /**
   * Get the session identifier.
   */
  String get session => headers[Frame.SESSION_HEADER];

  void set session(String session) {
    headers[Frame.SESSION_HEADER] = session;
  }

  /**
   * Get the smallest guaranteed number of milliseconds between frames sent, or 0  if this implementation cannot
   * guarantee such minimum heart-beat interval.
   */
  int get guaranteedHeartBeat {
    String heartBeat = headers[Frame.HEART_BEAT_HEADER];
    if (heartBeat == null) return 0;
    int commaPos = heartBeat.indexOf(",");
    String guaranteedHeartBeat = heartBeat.substring(0, commaPos);
    return int.parse(guaranteedHeartBeat);
  }

  /**
   * Get the desired number of milliseconds between frames received, or 0 if this implementation does not want
   * to receive frames at such minimum heart-beat interval.
   */
  int get desiredHeartBeat {
    String heartBeat = headers[Frame.HEART_BEAT_HEADER];
    if (heartBeat == null) return 0;
    int commaPos = heartBeat.indexOf(",");
    String desiredHeartBeat = heartBeat.substring(commaPos + 1);
    return int.parse(desiredHeartBeat);
  }

  /**
   * Get the identifier either specifying the transaction to commit or abort, or specifying the transaction
   * an ACK, NACK, or SEND command should be part of.
   */
  String get transactionId => headers[Frame.TRANSACTION_HEADER];

  void set transactionId(String transactionId) {
    headers[Frame.TRANSACTION_HEADER] = transactionId;
  }

  /**
   * Get the opaque string identifying the destination where to send the message.
   */
  String get destination => headers[Frame.DESTINATION_HEADER];

  void set destination(String destination) {
    headers[Frame.DESTINATION_HEADER] = destination;
  }

  /**
   * Get the ID. The ID takes different meaning depending on the command. In thew case of a SUBSCRIBE and UNSUBSCRIBE
   * command the id header must be included to identify the subscription. The id header allows the client and server to
   * relate subsequent MESSAGE or UNSUBSCRIBE frames to the original Within the same connection, different subscriptions
   * must use different subscription identifiers. In the case of an ACK or NACK command, the id header is used to
   * reference the matching the ack header of the MESSAGE being acknowledged or not acknowledged.
   */
  String get id => headers[Frame.ID_HEADER];

  void set id(String id) {
    headers[Frame.ID_HEADER] = id;
  }

  /**
   * Get the ack header value. This value takes different meaning depending on the command. Refer to the STOMP 1.2
   * specification for details of this parameter.
   */
  String get ack => headers[Frame.ACK_HEADER];

  void set ack(String ack) {
    headers[Frame.ACK_HEADER] = ack;
  }

  /**
   * Get the unique message identifier assigned to each message sent from a STOMP server to a connected/subscribed
   * client.
   */
  String get messageId => headers[Frame.MESSAGE_ID_HEADER];

  void set messageId(String messageId) {
    headers[Frame.MESSAGE_ID_HEADER] = messageId;
  }

  /**
   * Get the STOMP subscription identifier.
   */
  String get subscription => headers[Frame.SUBSCRIPTION_HEADER];

  void set subscription(String subscription) {
    headers[Frame.SUBSCRIPTION_HEADER] = subscription;
  }

  /**
   * Get the numerical value specifying an error code, or null if no error code header is present. This value is sent
   * in an "error-code" header that is not a standard header defined in the STOMP 1.2 protocol. If specified, this
   * library properly marshals/de-marshals the value such that the error code of a received ERROR frame is automatically
   * referenced in any StompException thrown on the client.
   */
  int get errorCode {
    String errorCode = headers[Frame.ERROR_CODE_HEADER];
    if (errorCode == null) return null;
    return int.parse(errorCode);
  }

  void set errorCode(int errorCode) {
    headers[Frame.ERROR_CODE_HEADER] = errorCode.toString();
  }

  /**
   * Return string representation of this frame.
   *
   * @return
   *      String representation of this frame per the STOMP 1.2 sub-protocol.
   */
  String toString() {

    // Return or generate frame
    return (frame != null) ? frame : (
        "$command\n" +
        _serializedHeaders +
        "\n" +
        (body == null ? "" : "$body") +
        "\x00"
    );
  }
}