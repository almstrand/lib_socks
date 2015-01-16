part of server_socks;

/**
 * Relates a method symbol and request filter such that received HTTP requests matching the filter will cause
 * the method referred to by the symbol to be invoked.
 */
class HttpRequestMapping {

  // Defines a regular expression to match the URI path of a received HTTP request with in determining whether the
  // method referred to by specified [methodSymbol] should be invoked.
  HttpRequestFilter httpRequestFilter;

  // Symbol referring to a class instance method to be invoked upon matching the URI path of a received HTTP request
  // with the filter defined by [httpRequestFilter].
  Symbol methodSymbol;

  HttpRequestMapping(HttpRequestFilter this.httpRequestFilter, Symbol this.methodSymbol);
}