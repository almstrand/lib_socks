part of client_socks;

/**
 * Exception used as value when (currently only use) completing future returned from [WebSocketConnection._open] method
 * with an error.
 */
class WebSocketException implements Exception {

  // Message detailing error cause.
  String cause;

  /**
   * Construct new exception.
   *
   * @param cause
   *      Error cause.
   */
  WebSocketException(String this.cause);

  String toString() {
    return cause;
  }
}