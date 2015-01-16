part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP PATCH requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class PATCH extends HttpMethod {
  const PATCH(final String path) : super("PATCH", path);
}