// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// A small (micro) web server.
library mserve;

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

import 'src/content_type.dart';
import 'src/directories.dart';
import 'src/logging.dart';
import 'src/packages.dart';

const int _kDefaultPort = 8000;

/// A small (micro) web server.
class MicroServer {
  static Future<MicroServer> start({
    String path,
    int port: _kDefaultPort,
    InternetAddress address,
    Logger logger,
  }) async {
    path ??= Directory.current.path;
    address ??= InternetAddress.loopbackIPv4;

    Pipeline pipeline = const Pipeline();
    if (logger != null) {
      pipeline = pipeline.addMiddleware(logShelfRequests(logger));
    }

    Cascade cascade = new Cascade()
        .add(shelf_static.createStaticHandler(path,
            contentTypeResolver: new CustomMimeTypeResolver()))
        .add(createPackagesHandler(path))
        .add(createDirectoriesHandler('mserve', path));

    Handler pipelineHandler = pipeline.addHandler(cascade.handler);
    final HttpServer server =
        await shelf_io.serve(pipelineHandler, address, port);
    return new MicroServer(path, server, logger);
  }

  MicroServer(this.path, this.server, this.logger);

  final String path;
  final HttpServer server;
  final Logger logger;

  String get host => server.address.host;

  int get port => server.port;

  String get urlBase => 'http://${host}:${port}/';

  Future destroy() => server.close();
}
