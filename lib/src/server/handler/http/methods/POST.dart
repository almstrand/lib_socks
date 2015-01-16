part of server_socks;

/**
 * Metadata annotation used to decorate class methods that should respond to HTTP POST requests, and specify the URI
 * path pattern that must be matched for the decorated class method to be invoked.
 */
class POST extends HttpMethod {
  const POST(final String path) : super("POST", path);
}