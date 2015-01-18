part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP DELETE requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class DELETE extends HttpMethod {
  const DELETE({final String path}) : super("DELETE", path: path);
}