// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// A small (micro) web server.
library mserve;

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:http_server/http_server.dart';

/// A small (micro) web server.
class MicroServer {
  static Future<MicroServer> start(
      {String path, int port: 8000, Logger logger}) async {
    if (path == null) {
      path = '.';
    }

    logger ??= new Logger.standard();

    HttpServer server = await HttpServer.bind('0.0.0.0', port);
    return new MicroServer._(path, server, logger);
  }

  final String _path;
  final HttpServer _server;
  final Logger _logger;
  final StreamController _errorController = new StreamController.broadcast();

  MicroServer._(this._path, this._server, this._logger) {
    VirtualDirectory vDir = new VirtualDirectory(path);
    vDir.allowDirectoryListing = true;
    vDir.jailRoot = true;

    runZoned(() {
      _server.listen((HttpRequest r) {
        InternetAddress address = r.connectionInfo.remoteAddress;
        _logger.trace('${address.host} • ${r.method} ${r.requestedUri}');
        vDir.serveRequest(r);
      }, onError: (e) => _errorController.add(e));
    }, onError: (e) => _errorController.add(e));
  }

  String get host => _server.address.host;

  String get path => _path;

  int get port => _server.port;

  String get urlBase => 'http://${host}:${port}/';

  Stream get onError => _errorController.stream;

  Future destroy() => _server.close();
}
