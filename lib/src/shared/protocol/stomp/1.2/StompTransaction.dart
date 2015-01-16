part of shared_socks;

/**
 * Functionality and parameters in common among client/server STOMP transaction implementations.
 */
class StompTransaction {

  String _id;

  /**
   * Construct new transaction.
   *
   * @param id
   *      Transaction ID, unique to the STOMP connection.
   */
  StompTransaction(String this._id);

  /**
   * Get the transaction ID, unique within a given STOMP connection.
   */
  String get id => _id;
}