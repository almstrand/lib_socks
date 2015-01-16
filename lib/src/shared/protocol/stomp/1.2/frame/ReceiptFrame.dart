part of shared_socks;

/**
 * STOMP 1.2 RECEIPT frame.
 */
class ReceiptFrame extends Frame {
  
  static const String _COMMAND = "RECEIPT";

  ReceiptFrame() : super(_COMMAND);

  /**
   * Construct new RECEIPT frame from parameters.
   * 
   * @param receiptId
   *      Value of the receipt ID header in the frame which this is a receipt for.
   * @param contentLength
   *      Octet count for the length of the message body.
   */
  ReceiptFrame.fromParams(String receiptId, {int contentLength}) : super(_COMMAND) {

    // Store header values.
    if (receiptId != null) headers[Frame.RECEIPT_ID_HEADER] = receiptId;
    if (contentLength != null) headers[Frame.CONTENT_LENGTH_HEADER] = contentLength.toString();
  }

  /**
   * Construct new RECEIPT frame from STOMP message [headers] and [body].
   * 
   * @param frame
   *      The raw frame message consisting of the RECEIPT command, specified [headers], and [body].
   * @param headers
   *      The set of headers parsed from the [frame] data.
   * @param body
   *      The body parsed from the [frame] data.
   */
  ReceiptFrame._fromMessage(String frame, Map<String, String> headers, String body) : super._fromParsedMessage(_COMMAND, frame, headers, body);

  bool get _isBodyAllowed => false;
  
  List<String> get _requiredHeaders => [
    Frame.RECEIPT_ID_HEADER
  ];

  List<String> get _allowedHeaders => [
    Frame.RECEIPT_ID_HEADER, 
    Frame.CONTENT_LENGTH_HEADER
  ];
}