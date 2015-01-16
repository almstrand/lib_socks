part of shared_socks;

/**
 * Functionality and parameters in common among client/server STOMP subscription implementations.
 */
class StompSubscription {

  String _id;
  String _destination;
  String _ack;
  bool _usesClientAck;
  bool _usesClientIndividualAck;
  bool _usesAutoAck;
  bool _usesAck;

  /**
   * Create new subscription.
   *
   * @param _id
   *      Subscription identifier unique to the STOMP connection. This identifier allows the client and server to relate
   *      subsequent MESSAGE or UNSUBSCRIBE frames to the original subscription.
   * @param _destination
   *      Identifies the destination to which this class represents a subscription.
   * @param _ack
   *      Subscription's ack setting. The valid values for the ack header are "auto", "client", or "client-individual".
   *      If the header is not set, it defaults to "auto". Refer to
   *      https://stomp.github.io/stomp-specification-1.2.html#SUBSCRIBE_ack_Header for details.
   */
  StompSubscription(String this._id, String this._destination, String this._ack) {
    _updateAckMode();
  }

  /**
   * Update booleans specifying the acknowledgement mode.
   */
  void _updateAckMode() {
    _usesClientAck = _ack == "client";
    _usesClientIndividualAck = _ack == "client-individual";
    _usesAutoAck = _ack == null || _ack == "auto";
    _usesAck = _usesClientAck || _usesClientIndividualAck;
  }

  /**
   * Get the subscription identifier unique to the STOMP connection. This identifier allows the client and server to
   * relate subsequent MESSAGE or UNSUBSCRIBE frames to the original subscription.
   */
  String get id => _id;

  /**
   * Get the subscription's ack setting. The valid values for the ack header are "auto", "client", or
   * "client-individual". If the header is not set, it defaults to auto.
   */
  String get ack => _ack;

  /**
   * Returns true if this subscription uses any form of STOMP acknowledgment mode requiring ACK and NACK frames
   * to be sent from client in response to STOMP MESSAGE frames.
   */
  bool get usesAck => _usesAck;

  /**
   * Returns true if this subscription uses the STOMP "auto" acknowledgment mode.
   */
  bool get usesAutoAck => _usesAutoAck;

  /**
   * Returns true if this subscription uses the STOMP "client" acknowledgment mode.
   */
  bool get usesClientAck => _usesClientAck;

  /**
   * Returns true if this subscription uses the STOMP "client" acknowledgment mode.
   */
  bool get usesClientIndividualAck => _usesClientIndividualAck;

  /**
   * Get the identifier of the destination to which this class represents a subscription.
   */
  String get destination => _destination;
}