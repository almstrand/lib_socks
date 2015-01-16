part of server_socks;

/**
 * Metadata annotation used to decorate class methods to specify the HTTP method and URI path pattern that must be
 * matched for the decorated class method to be invoked. This class is intended to be sub-classed; use a concrete
 * sub-class of this class when decorating class methods.
 */
abstract class HttpMethod extends UriPath {

  // The HTTP method that must be matched for the decorated class method to be invoked, e.g. "GET".
  final String method;

  const HttpMethod(final String this.method, final String path) : super(path);
}