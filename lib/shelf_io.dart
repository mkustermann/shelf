// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A Shelf adapter for handling [HttpRequest] objects from `dart:io`.
///
/// One can provide an instance of [HttpServer] as the `requests` parameter in
/// [serveRequests].
///
/// This adapter supports request hijacking; see [Request.hijack]. It also
/// supports the `"shelf.io.buffer_output"` `Response.context` property. If this
/// property is `true` (the default), streamed responses will be buffered to
/// improve performance; if it's `false`, all chunks will be pushed over the
/// wire as they're received. See [`HttpResponse.bufferOutput`][bufferOutput]
/// for more information.
///
/// [bufferOutput]: https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:io.HttpResponse#id_bufferOutput
library shelf.io;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';
import 'package:http2/transport.dart';
import 'package:http2/multiprotocol_server.dart';

import 'shelf.dart';
import 'src/util.dart';

export 'src/io_server.dart';

/// Starts an [HttpServer] that listens on the specified [address] and
/// [port] and sends requests to [handler].
///
/// See the documentation for [HttpServer.bind] for more details on [address],
/// [port], and [backlog].
Future<HttpServer> serve(Handler handler, address, int port, {int backlog}) {
  if (backlog == null) backlog = 0;
  return HttpServer.bind(address, port, backlog: backlog).then((server) {
    serveRequests(server, handler);
    return server;
  });
}

/// Starts an [MultiProtocolHttpServer] that listens on the specified [address]
/// and [port] and sends requests to [handler].
///
/// See the documentation for [HttpServer.bind] for more details on [address],
/// [port].
///
/// The [context] must be a valid [SecurityContext] populated with a server
/// certificate.
Future<MultiProtocolHttpServer> serveSecure(
    Handler handler,
    address, int port, SecurityContext context) async {
  var server = await MultiProtocolHttpServer.bind(address, port, context);
  catchTopLevelErrors(() {
    server.startServing(
        (HttpRequest request) => handleRequest(request, handler),
        (ServerTransportStream stream) => handleHttp2Stream(stream, handler));
  }, (error, stackTrace) {
    print('Asynchronous error\n$error' + stackTrace.toString());
  });
  return server;
}


/// Serve a [Stream] of [HttpRequest]s.
///
/// [HttpServer] implements [Stream<HttpRequest>] so it can be passed directly
/// to [serveRequests].
///
/// Errors thrown by [handler] while serving a request will be printed to the
/// console and cause a 500 response with no body. Errors thrown asynchronously
/// by [handler] will be printed to the console or, if there's an active error
/// zone, passed to that zone.
void serveRequests(Stream<HttpRequest> requests, Handler handler) {
  catchTopLevelErrors(() {
    requests.listen((request) => handleRequest(request, handler));
  }, (error, stackTrace) {
    _logTopLevelError('Asynchronous error\n$error', stackTrace);
  });
}

/// Uses [handler] to handle [request].
///
/// Returns a [Future] which completes when the request has been handled.
Future handleRequest(HttpRequest request, Handler handler) async {
  var shelfRequest;
  try {
    shelfRequest = _fromHttpRequest(request);
  } catch (error, stackTrace) {
    var response = _logTopLevelError(
        'Error parsing request.\n$error', stackTrace);
    await _writeResponse(response, request.response);
    return;
  }

  // TODO(nweiz): abstract out hijack handling to make it easier to implement an
  // adapter.
  var response;
  try {
    response = await handler(shelfRequest);
  } on HijackException catch (error, stackTrace) {
    // A HijackException should bypass the response-writing logic entirely.
    if (!shelfRequest.canHijack) return;

    // If the request wasn't hijacked, we shouldn't be seeing this exception.
    response = _logError(
        shelfRequest,
        "Caught HijackException, but the request wasn't hijacked.",
        stackTrace);
  } catch (error, stackTrace) {
    response = _logError(
        shelfRequest, 'Error thrown by handler.\n$error', stackTrace);
  }

  if (response == null) {
    await _writeResponse(
        _logError(shelfRequest, 'null response from handler.'),
        request.response);
    return;
  } else if (shelfRequest.canHijack) {
    await _writeResponse(response, request.response);
    return;
  }

  var message = new StringBuffer()
    ..writeln("Got a response for hijacked request "
        "${shelfRequest.method} ${shelfRequest.requestedUri}:")
    ..writeln(response.statusCode);
  response.headers
      .forEach((key, value) => message.writeln("${key}: ${value}"));
  throw new Exception(message.toString().trim());
}

/// Uses [handler] to handle [stream].
///
/// Returns a [Future] which completes when the request has been handled.
Future handleHttp2Stream(ServerTransportStream stream, Handler handler) async {
  Future<Request> getRequest() async {
    // Incoming messages
    var messages = new StreamIterator(stream.incomingMessages);
    bool hasHeaderMessage = await messages.moveNext();
    assert(hasHeaderMessage);
    HeadersStreamMessage message = messages.current;

    Map<String, String> readHeaders() {
      // For duplicated headers, we'll just take the first one.
      var headers = {};
      for (var header in message.headers) {
        headers.putIfAbsent(
            ASCII.decode(header.name), () => ASCII.decode(header.value));
      }
      return headers;
    }

    Stream<List<int>> readBody() async* {
      while (await messages.moveNext()) {
        var message = messages.current;
        if (message is DataStreamMessage) {
          yield message.bytes;
        } else { /* ignored (e.g. trailing headers message) */ }
      }
    }

    // TODO(kustermann): Make sure we get this stuff.
    var headers = readHeaders();
    var method = headers[':method'];
    var scheme = headers[':scheme'];
    var authority = headers[':authority'];
    var path = headers[':path'];

    var requestedUri = Uri.parse('$scheme://$authority$path');

    return new Request(method, requestedUri,
        protocolVersion: '2',
        headers: headers,
        body: readBody(),
        onHijack: (callback) => throw new Exception("Hijacking not allowed."));
  }

  Future handleResponse(Response response) async {
    List<Header> headers = [];
    addHeader(String name, String value) {
      headers.add(new Header(ASCII.encode(name), UTF8.encode(value)));
    }
    addHeader(':status', '${response.statusCode}');
    response.headers.forEach(addHeader);

    // TODO: We need to make sure Cookie headers / etc. have the don't index bit.
    stream.outgoingMessages.add(new HeadersStreamMessage(headers));

    var dataMessages = response
        .read().map((List<int> data) => new DataStreamMessage(data));

    await dataMessages.pipe(stream.outgoingMessages);
  }

  Request request = await getRequest();
  Response response;
  try {
    response = await handler(request);
  } catch (error, stackTrace) {
    response = _logError(
        request, 'Error thrown by handler.\n$error', stackTrace);
  }
  await handleResponse(response);
}

/// Creates a new [Request] from the provided [HttpRequest].
Request _fromHttpRequest(HttpRequest request) {
  var headers = {};
  request.headers.forEach((k, v) {
    // Multiple header values are joined with commas.
    // See http://tools.ietf.org/html/draft-ietf-httpbis-p1-messaging-21#page-22
    headers[k] = v.join(',');
  });

  onHijack(callback) {
    return request.response
        .detachSocket(writeHeaders: false)
        .then((socket) => callback(socket, socket));
  }

  return new Request(request.method, request.requestedUri,
      protocolVersion: request.protocolVersion,
      headers: headers,
      body: request,
      onHijack: onHijack);
}

Future _writeResponse(Response response, HttpResponse httpResponse) {
  if (response.context.containsKey("shelf.io.buffer_output")) {
    httpResponse.bufferOutput = response.context["shelf.io.buffer_output"];
  }

  httpResponse.statusCode = response.statusCode;

  response.headers.forEach((header, value) {
    if (value == null) return;
    httpResponse.headers.set(header, value);
  });

  if (!response.headers.containsKey(HttpHeaders.SERVER)) {
    httpResponse.headers.set(HttpHeaders.SERVER, 'dart:io with Shelf');
  }

  if (!response.headers.containsKey(HttpHeaders.DATE)) {
    httpResponse.headers.date = new DateTime.now().toUtc();
  }

  return httpResponse
      .addStream(response.read())
      .then((_) => httpResponse.close());
}

// TODO(kevmoo) A developer mode is needed to include error info in response
// TODO(kevmoo) Make error output plugable. stderr, logging, etc
Response _logError(Request request, String message, [StackTrace stackTrace]) {
  // Add information about the request itself.
  var buffer = new StringBuffer();
  buffer.write("${request.method} ${request.requestedUri.path}");
  if (request.requestedUri.query.isNotEmpty) {
    buffer.write("?${request.requestedUri.query}");
  }
  buffer.writeln();
  buffer.write(message);

  return _logTopLevelError(buffer.toString(), stackTrace);
}

Response _logTopLevelError(String message, [StackTrace stackTrace]) {
  var chain = new Chain.current();
  if (stackTrace != null) {
    chain = new Chain.forTrace(stackTrace);
  }
  chain = chain
      .foldFrames((frame) => frame.isCore || frame.package == 'shelf').terse;

  stderr.writeln('ERROR - ${new DateTime.now()}');
  stderr.writeln(message);
  stderr.writeln(chain);
  return new Response.internalServerError();
}
