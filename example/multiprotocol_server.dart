// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

var server;

main() async {
  String localFile(path) => Platform.script.resolve(path).toFilePath();

  SecurityContext context = new SecurityContext()
    ..useCertificateChain(localFile('certificates/server_chain.pem'))
    ..usePrivateKey(localFile('certificates/server_key.pem'),
                    password: 'dartdart');

  server = await serveSecure(handler, 'localhost', 9999, context);
  print('Running server on https://localhost:9999');
  print('Special URLS:');
  print('    https://localhost:9999/crash');
  print('    https://localhost:9999/stop');
}

Future<Response> handler(Request request) async {
  var path = request.requestedUri.path;

  print('Got request for $path (http version: ${request.protocolVersion}).');

  if (path == '/stop') {
    Timer.run(() async => await server.close());
    return new Response.ok('Stopping server.');
  } else if (path == '/crash') {
    throw 'got crash request => throwing exception';
  }
  return new Response.ok('Hello world.');
}

