part of shared_socks;

/**
 * STOMP 1.2 MESSAGE frame.
 */
class MessageFrame extends Frame {

  static const String _COMMAND = "MESSAGE";

  MessageFrame() : super(_COMMAND);

  /**
   * Construct new MESSAGE frame from parameters.
   *
   * @param destination
   *      String identifying the destination the message was sent to. This destination header should
   *      be identical to the one used in the corresponding SEND frame.
   * @param messageId
   *      Unique message identifier.
   * @param subscription
   *      Identifier matching the identifier of the subscription that is receiving the message.
   * @param body
   *      Body to send.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param contentType
   *      MIME type which describes the format of the body.
   * @param ack
   *      Arbitrary value used to relate the message to a subsequent ACK or NACK frame.
   */
  MessageFrame.fromParams(String destination, String messageId, String subscription, {String body, int contentLength, String contentType, String ack}) : super(_COMMAND) {

    // Store body.
    this.body = body;

    // Store header values.
    if (destination != null) headers[Frame.DESTINATION_HEADER] = destination;
    if (messageId != null) headers[Frame.MESSAGE_ID_HEADER] = messageId;
    if (subscription != null) headers[Frame.SUBSCRIPTION_HEADER] = subscription;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (contentType != null) headers[Frame.CONTENT_TYPE_HEADER] = contentType;
    if (ack != null) headers[Frame.ACK_HEADER] = ack;
  }

  /**
   * Construct new MESSAGE frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the MESSAGE command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  MessageFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => true;

  List<String> get _requiredHeaders => [
      Frame.DESTINATION_HEADER,
      Frame.MESSAGE_ID_HEADER,
      Frame.SUBSCRIPTION_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.DESTINATION_HEADER,
      Frame.MESSAGE_ID_HEADER,
      Frame.SUBSCRIPTION_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.CONTENT_TYPE_HEADER,
      Frame.ACK_HEADER
  ];
}