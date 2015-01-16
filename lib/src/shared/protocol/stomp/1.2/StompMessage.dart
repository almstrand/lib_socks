part of shared_socks;

/**
 * Represents a STOMP message.
 */
class StompMessage {

  // Message text.
  String message;

  // The octet count for the length of the message body. This is an optional field that may be null.
  int contentLength;

  // The mime type of this message. This is an optional field that may be null.
  String contentType;

  StompMessage(String this.message, int this.contentLength, String this.contentType);
}