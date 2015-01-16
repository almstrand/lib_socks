part of server_socks;

/**
 * Server-side representation of a STOMP transaction.
 */
class StompTransaction extends shared.StompTransaction {

  /**
   * Construct new transaction.
   *
   * @param
   *      id Transaction ID unique to the STOMP connection.
   */
  StompTransaction(String id) : super(id);
}