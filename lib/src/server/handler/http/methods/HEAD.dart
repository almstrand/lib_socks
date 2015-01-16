part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP HEAD requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class HEAD extends HttpMethod {
  const HEAD(final String path) : super("HEAD", path);
}