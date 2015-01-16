part of server_socks;

/**
 * Metadata annotation used to decorate classes and class methods to specify the URI path pattern that must be matched
 * for decorated class methods to be invoked. If a class is decorated with this metadata annotation, the specified
 * [path] will serve as a prefix in determining the URI path pattern for any constituent class methods.
 */
class UriPath {

  // URI path that must be matched for the decorated class method to be invoked. This path expression may include
  // parameter names surrounded by moustaches to cause the corresponding string value to be extracted from the URI path.
  // For example, specifying a path expression "/world/{continent}/{country}" would cause key/value pairs
  // continent=Europe and country=France to be passes in as parameters to the decorated method when matched with a URI
  // referencing path "/world/Europe/Sweden".
  final String path;

  const UriPath(final String this.path);
}