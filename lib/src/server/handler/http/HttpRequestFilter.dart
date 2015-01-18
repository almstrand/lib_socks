part of server_socks;

/**
 * Defines methods to parse the URI path of an HTTP request, determine whether it matches a given regular expression,
 * and if so--extract any sub-strings matching pre-defined wildcards.
 */
class HttpRequestFilter {
  RegExp _regExp;
  List<String> _variableNames = new List<String>();

  /**
   * Create a new instance representing a URI path pattern (including optional wildcard expressions) that defines the
   * pattern used to match a URI path and extract any constituent sub-strings matching any wildcard expressions.
   *
   * @param pathExpression
   *      String expression specifying the pattern that a given URI path must match. The expression may contain wildcard
   *      expressions designating the name of parameters whose corresponding matched strings in a given URI path value
   *      will be extracted and returned from the [match] method. Such expressions encapsulate the parameter name with
   *      moustaches, for example "{country}". For example, specifying an expression "/world/{continent}/{country}"
   *      and later invoking the [match] method specifying a URI path "/world/Europe/Sweden" returns a map
   *      {"continent": "Europe", "country": "Sweden"}.
   */
  HttpRequestFilter(String pathExpression) {
    if (pathExpression == null || pathExpression.length == 0) {
      return;
    }
    RegExp wildcardExp = new RegExp(r"{([^}]*)}");
    Iterable<Match> d = wildcardExp.allMatches(pathExpression);
    for (Match m in d) {
      int numGroups = m.groupCount;
      for (int i = 1; i <= numGroups; i++) {
        String variableName = m.group(i);
        _variableNames.add(variableName);
      }
    }
    String extractorPattern = pathExpression.replaceAllMapped(wildcardExp, (Match match) => "([^/]*)");
    _regExp = new RegExp("^$extractorPattern\$");
  }

  /**
   * Check whether specified URI path [uriPath] matches this class' URI path pattern. If [uriPath] matches the
   * pattern, any URI path sub-strings that match any corresponding wildcard expressions in the URI path pattern, are
   * extracted and returned as a [Map].
   *
   * @param uriPath
   *      The URI path.
   * @return
   *      If [uriPath] matches the URI path pattern specified in the constructor, this method returns a map whose keys
   *      match the wildcard names of the URI path pattern, and whose values are the corresponding sub-strings
   *      extracted from [uriPath]. If [uriPath] does not match the pattern, this method returns null.
   */
  Map<String, String> match(String uriPath) {
    Map<String, String> keyValuePairs = new Map<String, String>();
    if (_regExp == null) {
      if (uriPath == null || uriPath.length == 0 || uriPath == "/") {
        return keyValuePairs;
      }
      else {
        return null;
      }
    }
    Iterable<Match> matches = _regExp.allMatches(uriPath);
    if (matches == null || matches.length == 0) return null;
    Match match = matches.first;
    int numGroups = match.groupCount;
    for (int i = 0; i < numGroups; i++) {
      String value = match.group(i + 1);
      keyValuePairs[_variableNames[i]] = value;
    }
    return keyValuePairs;
  }
}