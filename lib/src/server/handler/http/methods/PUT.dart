part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP PUT requests, and specify the URI path
 * pattern that must be matched for the decorated class method to be invoked.
 */
class PUT extends HttpMethod {
  const PUT({final String path}) : super("PUT", path: path);
}