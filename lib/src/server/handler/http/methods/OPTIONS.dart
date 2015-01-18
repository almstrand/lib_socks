part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP OPTIONS requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class OPTIONS extends HttpMethod {
  const OPTIONS({final String path}) : super("OPTIONS", path: path);
}