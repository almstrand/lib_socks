part of server_socks;

/**
 * Wrapper around [HttpServer] and related classes to include boiler-plate code for binding to an optionally secure HTTP
 * server and listening for requests. Provides added functionality including white-listing of origins, CORS support, and
 * consistent error handling.
 */
class Server {

  static Logger _log = new Logger("Server");
  dynamic _address;
  int _port;
  List<String> _allowedOrigins;
  HttpServer _httpServer;

  /**
   * Bind non-secure server.
   *
   * @param address
   *      The [address] can either be a [String] or an [InternetAddress]. If [address] is a [String], [bind] will
   *      perform an [InternetAddress.lookup] and use the first value in the list. To listen on the loopback adapter,
   *      which will allow only incoming connections from the local host, use the value [InternetAddress.LOOPBACK_IP_V4]
   *      or [InternetAddress.LOOPBACK_IP_V6]. To allow for incoming connection from the network use either one of the
   *      values [InternetAddress.ANY_IP_V4] or [InternetAddress.ANY_IP_V6] to bind to all interfaces or the IP address
   *      of a specific interface. If an IP version 6 (IPv6) address is used, both IP version 6 (IPv6) and version 4
   *      (IPv4) connections will be accepted. To restrict this to version 6 (IPv6) only, use [HttpServer.listenOn]
   *      with a [ServerSocket] configured for IP version 6 connections only. Default: [InternetAddress.ANY_IP_V4].
   * @param port
   *      Specifies the port that this server will listen on. Default: 80.
   * @param allowedOrigins
   *      List of origins that are allowed to make requests to this server. Set to null to allow all origins to make
   *      requests to this server.
   * @param autoCompress
   *      Specifies whether the HTTP server should gzip-compress served content, if possible. Served content can only be
   *      compressed when the response is using chunked Transfer-Encoding and the incoming request has gzip as an
   *      accepted encoding in the Accept-Encoding header.
   * @return
   *      Future referencing server upon success, or referencing SocketException instance upon error.
   */
  Future<Server> bind({dynamic address, int port: 80, List<String> allowedOrigins, bool autoCompress: true}) {

    // Bind to all interfaces if none specified
    if (address == null) {
      address = InternetAddress.ANY_IP_V4;
    }

    // Stash address, port, allowed origins
    _address = address;
    _port = port;
    _allowedOrigins = allowedOrigins;

    // Bind server to specified address, port.
    Completer<Server> serverCompleter = new Completer<Server>();
    _log.info(() => "Binding insecure server to $address port $port.${allowedOrigins == null ? "" : (" Allowed origins: ${allowedOrigins.join(", ")}.")}");
    HttpServer.bind(address, port)
    .then((HttpServer httpServer) {
      _httpServer = httpServer;
      _httpServer.autoCompress = autoCompress;
      serverCompleter.complete(this);
    })
    .catchError((SocketException socketException) {
      _httpServer = null;
      _onBindError(socketException);
      serverCompleter.completeError(socketException);
    });
    return serverCompleter.future;
  }

  /**
   * Bind secure server.
   *
   * @param address
   *      The [address] can either be a [String] or an [InternetAddress]. If [address] is a [String], [bind] will
   *      perform an [InternetAddress.lookup] and use the first value in the list. To listen on the loopback adapter,
   *      which will allow only incoming connections from the local host, use the value [InternetAddress.LOOPBACK_IP_V4]
   *      or [InternetAddress.LOOPBACK_IP_V6]. To allow for incoming connection from the network use either one of the
   *      values [InternetAddress.ANY_IP_V4] or [InternetAddress.ANY_IP_V6] to bind to all interfaces or the IP address
   *      of a specific interface. If an IP version 6 (IPv6) address is used, both IP version 6 (IPv6) and version 4
   *      (IPv4) connections will be accepted. To restrict this to version 6 (IPv6) only, use [HttpServer.listenOn]
   *      with a [ServerSocket] configured for IP version 6 connections only. Default: [InternetAddress.ANY_IP_V4].
   * @param port
   *      Specifies the port that this server will listen on. Default: 443.
   * @param allowedOrigins
   *      List of origins that are allowed to make requests to this server. Set to null to allow all origins to make
   *      requests to this server.
   * @param autoCompress
   *      Specifies whether the HTTP server should gzip-compress served content, if possible. Served content can only be
   *      compressed when the response is using chunked Transfer-Encoding and the incoming request has gzip as an
   *      accepted encoding in the Accept-Encoding header.
   * @param database
   *      Specifies the path to a certificate database directory containing root certificates for verifying certificate
   *      paths on client connections, and server certificates to provide on server connections.
   * @param password
   *      Password to use when creating secure server sockets, to allow the private key of the server certificate to be
   *      fetched.
   * @param certificateName
   *      Certificate with nickname or distinguished name (DN) to look up in the certificate database and use as the
   *      server certificate.
   * @return
   *      Future referencing server upon success, or referencing SocketException instance upon error.
   */
  Future<Server> bindSecure({dynamic address: null, int port: 443, List<String> allowedOrigins, bool autoCompress: true, String database, String password, String certificateName}) {

    // Bind to all interfaces if none specified
    if (address == null) {
      address = InternetAddress.ANY_IP_V4;
    }

    // Stash address, port, allowed origins
    _address = address;
    _port = port;
    _allowedOrigins = allowedOrigins;

    // Initialize the NSS library
    if (database == null) {
      _log.warning(() => "NSS library not configured to use any certificate database.");
    }
    else {
      _log.info(() => "Initializing NSS library to use database '$database'.");
      SecureSocket.initialize(database: database, password: password);
    }

    // Bind server to specified address, port. Optionally use specified certificate.
    Completer<Server> serverCompleter = new Completer<Server>();
    _log.info(() => "Binding secure server to $address port $port. Allowed origins: ${allowedOrigins.join(", ")}.");
    HttpServer.bindSecure(address, port, certificateName: certificateName)
    .then((HttpServer httpServer) {
      _httpServer = httpServer;
      _httpServer.autoCompress = autoCompress;
      serverCompleter.complete(this);
    })
    .catchError((SocketException socketException) {
      _httpServer = null;
      _onBindError(socketException);
      serverCompleter.completeError(socketException);
    });
    return serverCompleter.future;
  }

  void _onBindError(SocketException socketException) {
    switch (socketException.osError.errorCode) {
      case 13:
        _log.severe(() => "Failed starting server on $_address:$_port. If running as non-root user, consider running `sudo setcap 'cap_net_bind_service=+ep' /path/to/dart/executable`");
        break;
      case 98:
        _log.severe(() => "Failed starting server on $_address:$_port. Server already running?");
        break;
      default:
        _log.severe(() => "Failed starting server on $_address:$_port: ${socketException.message}");
        break;
    }
  }

  /**
   * Determine whether specified origin is allow to make a request to this server.
   */
  bool _isOriginAllowed(String origin) {

    // Return true if all origins should be allowed, or if no origin header is specified
    if (_allowedOrigins == null || origin == null) return true;

    // Return true/false depending on whether the origin is white-listed
    if (origin != null && origin.length > 0) {
      return _allowedOrigins.contains(origin.toLowerCase());
    }
    return false;
  }

  /**
   * Listen for incoming requests.
   *
   * @param onData
   *      Method called with [HttpRequest] parameter representing incoming HTTP request.
   * @param onError
   *      On errors from this stream, the [onError] handler is given a object describing the error. The [onError]
   *      callback must be of type `void onError(error)` or `void onError(error, StackTrace stackTrace)`. If [onError]
   *      accepts two arguments it is called with the stack trace (which could be `null` if the stream itself received
   *      an error without stack trace). Otherwise it is called with just the error object.
   * @param onDone
   *      If this stream closes, the [onDone] handler is called.
   * @param cancelOnError
   *      Set to true to end the subscription is ended when the first error is reported. The default is false.
   * @return Subscription to stream referencing received HTTP requests, or null upon error.
   */
  StreamSubscription<HttpRequest> listen(void onData(HttpRequest httpRequest), { Function onError, void onDone(), bool cancelOnError}) {

    // Ensure bind is called
    if (_httpServer == null) {
      _log.severe(() => "Failed listening on '$_address:$_port': call method 'bind' or 'bindSecure' first");
      return null;
    }

    // Listen for incoming requests
    _log.info(() => "Listening for HTTP requests targeting $_address port $_port.");

    return _httpServer.listen((HttpRequest httpRequest) {

      // Ensure we only accept requests from an allowed origin
      String origin = httpRequest.headers.value("origin");
      if (!_isOriginAllowed(origin)) {
        _log.warning(() => "Rejected HTTP requestfrom un-authorized origin $origin.");
        httpRequest.response.statusCode = HttpStatus.UNAUTHORIZED;
        httpRequest.response.reasonPhrase = "Unauthorized origin $origin";
        httpRequest.response.close();
        return;
      }

      // Add CORS header if request contains an origin header
      if (origin != null) {
        httpRequest.response.headers.add("Access-Control-Allow-Origin", origin);
      }

      // Re-dispatch HTTP request
      onData(httpRequest);
    },
    onDone: () {
      if (onDone != null) {
        onDone();
      }
    },
    onError: ((error, StackTrace stackTrace) {
      _log.severe(() => "Failed listening on '$_address:$_port'${error == null ? "." : (": " + error.toString())}}");
      if (onError != null) {
        onError(error, stackTrace);
      }
    }),
    cancelOnError: cancelOnError
    );
  }
}
