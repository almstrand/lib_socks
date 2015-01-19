part of server_socks;

class HttpRequestHandler {

  static Logger _log = new Logger("HttpRequestHandler");
  InstanceMirror _instanceMirror;

  // Relates HTTP request mappings/methods to enable quickly looking up applicable mappings upon receiving a request.
  Map<String, List<HttpRequestMapping>> _httpRequestMethodMappings = new Map<String, List<HttpRequestMapping>>();

  /**
   * Construct request handler by reflecting on instance and deriving HTTP request mappings from metadata annotations.
   */
  HttpRequestHandler() {

    // Reflect on class to identify any root URI path to serve as a prefix when generating the HTTP request filters.
    String uriPath;
    String expectedClassAnnotation = MirrorSystem.getName(reflectClass(UriPath).qualifiedName);
    _instanceMirror = reflect(this);
    ClassMirror classMirror = _instanceMirror.type;
    List<InstanceMirror> annotations = classMirror.metadata;
    for (InstanceMirror annotation in annotations) {
      if (annotation.reflectee is UriPath) {
        String path = (annotation.reflectee as UriPath).path;
        if (uriPath != null && path != uriPath) {
          _log.severe("Request handler ${runtimeType} may not have multiple @$expectedClassAnnotation annotations; ignoring ${path == null ? "additional empty URI path" : ("URI path $path")}.");
        }
        else {
          uriPath = path == null ? null : path.trim();
        }
      }
    }
    _log.info("Request handler ${runtimeType} responds to HTTP requests targeting path ${uriPath == null ? "/ (hint: annotate handler class with @$expectedClassAnnotation)" : uriPath}.");

    // Reflect on class methods and create filters to determine when to invoke each respective method upon receiving an HTTP request.
    String expectedMethodAnnotation = MirrorSystem.getName(reflectClass(HttpMethod).qualifiedName);
    classMirror.declarations.forEach((name, declaration) {
      MethodMirror method;
      if (declaration is MethodMirror) {
        method = declaration;
        if (method != null && !method.isConstructor) {
          List<InstanceMirror> annotations = method.metadata;
          String filterPath;
          for (InstanceMirror annotation in annotations) {
            if (annotation.reflectee is HttpMethod) {

              // Ensure correct method signature.
              String methodName = MirrorSystem.getName(method.simpleName);
              List<ParameterMirror> params = method.parameters;
              if (params.length != 3 || params[0].type.reflectedType != int || params[1].type.reflectedType != HttpRequest || params[2].type.simpleName != #Map || params[2].type.typeArguments.length != 2 || params[2].type.typeArguments[0].simpleName != #String || params[2].type.typeArguments[1].simpleName != #String) {
                _log.severe("Method $methodName in request handler ${runtimeType} has an invalid signature. The method signature must be $methodName(int requestId, HttpRequest request, Map <String, String> pathParams).");
                return null;
              }

              // Extract HTTP method and URI path filters.
              HttpMethod httpMethodAnnotation = (annotation.reflectee as HttpMethod);
              String path = httpMethodAnnotation.path == null ? null : httpMethodAnnotation.path.trim();
              if (filterPath != null && path != filterPath) {
                _log.warning("Method $methodName in request handler ${runtimeType} has multiple annotations (possibly sub-classing) @${MirrorSystem.getName(reflectType(HttpMethod).simpleName)}; ignoring annotation referencing ${path == null ? "additional empty URI path" : ("URI path ${(uriPath == null ? "" : uriPath) + path}")}.");
              }
              else {

                // Is either a class or method path annotation defined?
                if (uriPath != null || path != null) {

                  // Yes, combine class path and method path.
                  filterPath = "/" + (uriPath == null ? "" : uriPath) + (path == null ? "" : ("/" + path));

                  // Ensure combined path has single leading path separator, no duplicate separators, and no trailing separator.
                  int filterPathLen;
                  do {
                    filterPathLen = filterPath.length;
                    filterPath = filterPath.replaceAll("//", "/");
                  } while (filterPath.length != filterPathLen);
                  while (filterPath.endsWith("/")) {
                    filterPath = filterPath.substring(0, filterPath.length - 1);
                  }
                }

                // Add filter to determine when to route requests to this method.
                HttpRequestFilter httpRequestFilter = new HttpRequestFilter(filterPath);
                HttpRequestMapping httpRequestMapping = new HttpRequestMapping(httpRequestFilter, method.simpleName);
                List<HttpRequestMapping> methodFilters = _httpRequestMethodMappings[httpMethodAnnotation.method];
                if (methodFilters == null) {
                  methodFilters = new List<HttpRequestMapping>();
                  _httpRequestMethodMappings[httpMethodAnnotation.method] = methodFilters;
                }
                methodFilters.add(httpRequestMapping);
                _log.info("Method $methodName in request handler ${runtimeType} responds to HTTP ${httpMethodAnnotation.method.toUpperCase()} requests targeting path ${filterPath == null ? "/ (hint: annotate handler class with @$expectedClassAnnotation or methods with @$expectedMethodAnnotation sub-class)" : filterPath}.");
              }
            }
          }
        }
      }
    });
  }

  /**
   * Invoked when receiving a request on the HTTP connection. Parses request and invokes any methods registered to
   * process HTTP request matching the HTTP method and URI path.
   *
   * @param requestId
   *      Integer identifying this HTTP request.
   * @param request
   *      The received HTTP request.
   * @param pathParams
   *      Parameter values extracted from wildcard expressions matching sub-strings of the received HTTP request URI
   *      path.
   * @return
   *      True if this handler responded to the request.
   */
  bool _onRequest(int requestId, HttpRequest request) {
    String httpMethod = request.method;
    String httpPath = request.uri.path;
    List<HttpRequestMapping> httpRequestMappings = _httpRequestMethodMappings[httpMethod];
    if (httpRequestMappings != null) {
      for (HttpRequestMapping requestMapping in httpRequestMappings) {
        HttpRequestFilter requestFilter = requestMapping.httpRequestFilter;
        Map<String, String> pathParams = requestFilter.match(httpPath);
        if (pathParams != null) {
          Symbol methodSymbol = requestMapping.methodSymbol;
          _instanceMirror.invoke(methodSymbol, [requestId, request, pathParams]);
          return true;
        }
      }
    }
    return false;
  }

  void _send(HttpResponse response, int statusCode, String reasonPhrase, String body) {
    response.statusCode = statusCode;
    response.reasonPhrase = reasonPhrase;
    if (body != null) {
      response.write(body);
    }
    response.close();
  }

  void sendOK(HttpResponse response, {String reasonPhrase: "OK", String body}) {
    _send(response, HttpStatus.OK, reasonPhrase, body);
  }

  void sendNotFound(HttpResponse response, {String reasonPhrase: "Not found", String body}) {
    _send(response, HttpStatus.NOT_FOUND, reasonPhrase, body);
  }

  void sendInternalError(HttpResponse response, {String reasonPhrase: "Internal Server Error", String body}) {
    _send(response, HttpStatus.INTERNAL_SERVER_ERROR, reasonPhrase, body);
  }
}