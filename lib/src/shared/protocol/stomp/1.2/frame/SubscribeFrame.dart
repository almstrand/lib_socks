part of shared_socks;

/**
 * STOMP 1.2 SUBSCRIBE frame.
 */
class SubscribeFrame extends Frame {

  static const String _COMMAND = "SUBSCRIBE";

  SubscribeFrame() : super(_COMMAND);

  /**
   * Construct new SUBSCRIBE frame from parameters.
   *
   * @param id
   *      Since a single connection can have multiple open subscriptions with a server, an id header must be included in
   *      the frame to identify the subscription. The id header allows the client and server to relate subsequent
   *      MESSAGE or UNSUBSCRIBE frames to the original subscription. Within the same connection, different
   *      subscriptions must use different subscription identifiers.
   * @param destination
   *      Opaque string identifying the destination to which the client wants to subscribe.
   * @param contentLength
   *      Octet count for the length of the message body.
   * @param receipt
   *      Arbitrary value causing the server to acknowledge the processing of the client frame with a RECEIPT frame.
   * @param ack
   *      Subscription's ack setting. The valid values for the ack header are "auto", "client", or "client-individual".
   *      If the header is not set, it defaults to "auto". Refer to
   *      https://stomp.github.io/stomp-specification-1.2.html#SUBSCRIBE_ack_Header for details.
   */
  SubscribeFrame.fromParams(String id, String destination, {int contentLength, String receipt, String ack}) : super(_COMMAND) {

    // Store body.
    this.body = body;

    // Store header values.
    if (id != null) headers[Frame.ID_HEADER] = id;
    if (destination != null) headers[Frame.DESTINATION_HEADER] = destination;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
    if (receipt != null) headers[Frame.RECEIPT_HEADER] = receipt;
    if (ack != null) headers[Frame.ACK_HEADER] = ack;
  }

  /**
   * Construct new SUBSCRIBE frame from STOMP message [headers] and [body].
   *
   * @param frame
   *      The raw frame message consisting of the SUBSCRIBE command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  SubscribeFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  /**
   * Perform additional validation specific to this message. Basic validation, including checking for required/allowed
   * headers and the presence of a body, is handled in the super class.
   *
   * @throws
   *      StompException if this is an invalid STOMP frame.
   */
  void _validate() {

    // Ensure valid ack header value.
    String ack = this.ack;
    if (ack != null) {
      switch (ack) {
        case "auto":
        case "client":
        case "client-individual":
          break;
        default:

          // Throw exception containing details on why validation failed.
          throw new StompException(StompException.ERROR_CODE_MALFORMED_FRAME, "Malformed frame", details: "ACK header value must be one of {null, \"auto\", \"client\", \"client-individual\".", receiptId: receipt, frame: frame);
      }
    }
  }

  bool get _isBodyAllowed => false;

  List<String> get _requiredHeaders => [
      Frame.DESTINATION_HEADER,
      Frame.ID_HEADER
  ];

  List<String> get _allowedHeaders => [
      Frame.DESTINATION_HEADER,
      Frame.ID_HEADER,
      Frame.CONTENT_LENGTH_HEADER,
      Frame.RECEIPT_HEADER,
      Frame.ACK_HEADER
  ];
}