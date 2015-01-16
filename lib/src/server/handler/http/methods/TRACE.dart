part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP TRACE requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class TRACE extends HttpMethod {
  const TRACE(final String path) : super("TRACE", path);
}