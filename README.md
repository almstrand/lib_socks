# socks

One-stop-shop client and server libraries for static file hosting and building/consuming robust
[HTTP/1.1](http://www.w3.org/Protocols/rfc2616/rfc2616.html) web services including
[REST](http://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)ful services,
[WebSocket](https://tools.ietf.org/html/rfc6455) services, and
[STOMP 1.2](https://stomp.github.io/stomp-specification-1.2.html) WebSocket services.

The server-side library includes an HTTP/HTTPS server for hosting static files, and provides metadata annotations to
simplify developing REST, WebSocket, and STOMP WebSocket services.

The client-side library simplifies connecting with HTTP/HTTPS servers, making REST requests, parsing REST responses,
performing WebSocket upgrades, sending STOMP-formatted frames, and parsing received STOMP frames.

# Sample code

The following sample code is intended to show common usages in their simplest form. Please consult the source code
documentation of the referenced functions to support more complex requirements.

## HTTP static file server

    import "package:socks/server_socks.dart" as server;

    // Construct simple server hosting static files in directory '../web'.
    server.Router router = new server.Router();
    router.addRequestHandler(new server.StaticHttpRequestHandler("../web"));
    new server.Server().bind()
    .then((server.Server server) {
        server.listen((HttpRequest httpRequest) {
            router.handleRequest(httpRequest);
        });
    });

## HTTP server responding to GET requests

    import "package:socks/server_socks.dart" as server;

    // Define REST request handler.
    @server.UriPath("/kitchen/{category}")
    class RestHandler extends server.HttpRequestHandler {
      @server.GET("/{dish}/{ingredient}")
      void getFood(int requestId, HttpRequest httpRequest, Map<String, String> pathParams) {
        print("Category=${pathParams["category"]}\nDish=${pathParams["dish"]}\nIngredient= \
            ${pathParams["ingredient"]}");
      }
    }

    // Construct simple server forwarding requests to REST request handler.
    server.Router router = new server.Router();
    router.addRequestHandler(new RestHandler());
    new server.Server().bind()
    .then((server.Server server) {
        server.listen((HttpRequest httpRequest) {
            router.handleRequest(httpRequest);
        });
    });

An HTTP GET request to ```http://localhost/kitchen/food/pizza/tomato``` produces console output:

    Category=food
    Dish=pizza
    Ingredient=tomato

## WebSocket STOMP server

    import "package:socks/server_socks.dart" as server;
    import "package:socks/shared_socks.dart" as shared;

    // Create STOMP "kitchen" destination.
    class MyKitchen extends server.StompDestination {
      MyKitchen() : super("kitchen");
      Future onMessage(String transaction, shared.StompMessage stompMessage) {
        print("Received ingredient: ${stompMessage.message}");
        return new Future.value();
      }
    }

    // Create WebSocket STOMP request handler.
    @server.UriPath("/stomp")
    class MyWebSocketStompHandler extends server.StompRequestHandler {
      MyWebSocketStompHandler() {
        addDestination(new MyKitchen());
      }
    }

    // Construct simple server forwarding requests to WebSocket STOMP request handler.
    server.Router router = new server.Router();
    router.addRequestHandler(new MyWebSocketStompHandler());
    new server.Server().bind()
    .then((server.Server server) {
        server.listen((HttpRequest httpRequest) {
            router.handleRequest(httpRequest);
        });
    });

## WebSocket STOMP client

    import "package:socks/client_socks.dart" as client;

    // Construct simple client.
    client.WebSocketStompConnection.connect("ws://localhost/stomp", "localhost")
    .then((client.WebSocketStompConnection connection) {

      // Subscribe to the "kitchen" destination
      client.StompSubscription subscription = connection.subscribe("kitchen")
        ..onSubscribed.listen((_) {

          // Send message to the "kitchen" destination.
          print("Sending cheese!);
          connection.send("kitchen", "cheese");
        })
        ..onMessage.listen((shared.StompMessage stompMessage) {
          print("Got my ${stompMessage.message} back!");
        });
    });

This produces server-side console output:

    Received ingredient: cheese

and client-side console output:

    Sending cheese!
    Got my cheese back!

## Notes
Server instances can support any combination of static file hosting and RESTful, WebSocket, and STOMP WebSocket services
by adding corresponding request handlers to the Router instance as shown in the above examples.
