part of shared_socks;

/**
 * Represents an error related to establishing/maintaining a connection or exchanging data via the STOMP 1.2 protocol.
 */
class StompException implements Exception {

  // Body prefix introduced when generating STOMP ERROR frame from this exception
  static const String ERROR_FRAME_PREFIX = "-----START OF FRAME-----\n";

  // Body suffix introduced when generating STOMP ERROR frame from this exception
  static const String ERROR_FRAME_SUFFIX = "\n-----END OF FRAME-----";

  // Error code specifying function not implemented.
  static const int ERROR_CODE_NOT_IMPLEMENTED = 1;

  // Error code specifying failed protocol negotiation.
  static const int ERROR_CODE_PROTOCOL_NEGOTIATION_FAILED = 2;

  // Error code specifying malformed frame received.
  static const int ERROR_CODE_MALFORMED_FRAME = 3;

  // Error code specifying having received an unexpected frame.
  static const int ERROR_CODE_UNEXPECTED_FRAME = 4;

  // Error code specifying client connection with server already having been established.
  static const int ERROR_CODE_ALREADY_CONNECTED = 5;

  // Error code specifying lack of active connection with server.
  static const int ERROR_CODE_NOT_CONNECTED = 6;

  // Error code specifying WebSocket error
  static const int ERROR_CODE_WEBSOCKET_ERROR = 7;

  // Error code specifying a non-unique receipt ID was specified
  static const int ERROR_CODE_NON_UNIQUE_RECEIPT = 8;

  // Error code specifying a redundant/duplicate CONNECT frame was sent to the server.
  static const int ERROR_CODE_DUPLICATE_CONNECT = 9;

  // Error code specifying client receiving a receipt ID that does not reference any pending command.
  static const int ERROR_CODE_BAD_RECEIPT_ID = 10;

  // Error code specifying client failing to receive confirmation that STOMP frame was delivered and processed by the server.
  static const int ERROR_CODE_WEBSOCKET_CLOSED = 11;

  // Error code specifying an invalid STOMP destination.
  static const int ERROR_CODE_INVALID_DESTINATION = 12;

  // Error code specifying an invalid STOMP subscriber (connection).
  static const int ERROR_CODE_INVALID_SUBSCRIBER = 13;

  // Error code specifying an error resulting from client not being subscribed to received message.
  static const int ERROR_CODE_NOT_SUBSCRIBED = 14;

  // Error code specifying an invalid message ID was received by the server in a ACK or NACK frame.
  static const int ERROR_CODE_BAD_MESSAGE_ID = 15;

  // Error code specifying error caused by pending messages having been sent to subscription not yet acknowledged by client.
  static const int ERROR_CODE_SUBSCRIPTION_NOT_DRAINED = 16;

  // Error code specifying error caused by specifying an invalid transaction.
  static const int ERROR_CODE_BAD_TRANSACTION = 17;

  // Error code specifying error caused by a client failing to process a message received via a STOMP subscription.
  static const int ERROR_CODE_SUBSCRIBER_FAILED_PROCESSING = 18;

  // Error code specifying error caused by a client failing to connect to server.
  static const int ERROR_CODE_WEBSOCKET_CONNECTION_FAILED = 19;

  // Error code.
  int code;

  // Brief error description.
  String summary;

  // Detailed error description.
  String details;

  // Receipt ID of the STOMP frame this exception relates to.
  String receiptId;

  // Raw STOMP frame data, if available.
  String frame;

  /**
   * Construct new exception.
   *
   * @param code
   *      Error code.
   * @param summary
   *      Brief error description.
   * @param details
   *      Detailed error description.
   * @param frame
   *      Raw STOMP frame data, if available.
   * @param receiptId
   *      Receipt ID of the STOMP frame this exception relates to.
   */
  StompException(int this.code, String this.summary, {String this.details, String this.frame, String this.receiptId});

  /**
   * Constructs an ERROR frame from this exception.
   *
   * @param frame
   *      Raw frame data to be included in the ERROR frame body.
   * @return
   *      Error frame referencing the data specified in this exception.
   */
  ErrorFrame asErrorFrame() {

    // Error details specified?
    String errorBody;
    if (details != null) {

      // Yes, remove any trailing \n
      details = details.trimRight();

      // Add frame data including error details
      if (frame == null) {
        errorBody =
        "$details${details.endsWith(".") ? "" : "."}";
      }
      else {
        errorBody =
        "$details${details.endsWith(".") ? "" : "."}\n" +
        "$ERROR_FRAME_PREFIX$frame$ERROR_FRAME_SUFFIX";
      }
    }
    else {

      // No, add frame data excluding error details
      if (frame != null) {
        errorBody =
        "$ERROR_FRAME_PREFIX$frame$ERROR_FRAME_SUFFIX";
      }
    }

    // Return ERROR frame
    ErrorFrame errorFrame = new ErrorFrame.fromParams(body: errorBody, contentType: "text/plain", message: summary, errorCode: code, receiptId: receiptId);
    return errorFrame;
  }

  String toString() {
    return "Error code: $code\nReceipt ID: $receiptId\nSummary: $summary\nDetails: $details\nFrame: $frame";
  }
}