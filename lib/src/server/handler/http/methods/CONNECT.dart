part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP CONNECT requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class CONNECT extends HttpMethod {
  const CONNECT({final String path}) : super("CONNECT", path: path);
}