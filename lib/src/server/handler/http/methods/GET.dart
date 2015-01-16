part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP GET requests, and specify the URI path
 * pattern that must be matched for the decorated class method to be invoked.
 */
class GET extends HttpMethod {
  const GET(final String path) : super("GET", path);
}