// Copyright (c) 2015, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library mserve.bin;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mserve/mserve.dart';

Future main(List<String> args) async {
  ArgParser parser = new ArgParser();

  parser.addOption('port',
      defaultsTo: '8000', abbr: 'p', help: 'the port to serve on');
  parser.addFlag('help', abbr: 'h', negatable: false, help: "show help");
  parser.addFlag('log', negatable: false, help: "log requests");

  ArgResults results = parser.parse(args);

  if (results['help']) {
    print('usage: mserve <options> <directory>');
    print('');
    print('options:');
    print(parser.usage.replaceAll('\n\n', '\n'));

    exit(0);
  }

  String dir = null;

  if (results.rest.isNotEmpty) {
    dir = results.rest.first;
  }

  int port = int.tryParse(results['port']);
  if (port == null) {
    print('Unable to parse port parameter: ${results['port']}.');
    exit(1);
  }

  try {
    MicroServer server = await MicroServer.start(
      path: dir,
      port: port,
      log: results['log'],
    );

    print('Serving ${server.path} on ${server.urlBase}');

    server.onError.listen((e) {
      stderr.writeln('$e');
    });
  } catch (e) {
    print('Unable to start server.\n  (${e})');
    exit(1);
  }
}
