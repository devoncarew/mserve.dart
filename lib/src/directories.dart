import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

Handler createDirectoriesHandler(String appName, String fileSystemPath,
    {bool serveFilesOutsidePath: false}) {
  Directory rootDir = new Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw new ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  return (Request request) {
    var segs = [fileSystemPath]..addAll(request.url.pathSegments);
    var fsPath = path.joinAll(segs);
    var entityType = FileSystemEntity.typeSync(fsPath, followLinks: true);

    if (entityType == FileSystemEntityType.directory) {
      var uri = request.requestedUri;
      if (!uri.path.endsWith('/')) {
        return _redirectToAddTrailingSlash(uri);
      }
      return listDirectory(appName, fileSystemPath, fsPath);
    }

    return new Response.notFound('Not Found');
  };
}

Response _redirectToAddTrailingSlash(Uri uri) {
  var location = new Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path + '/',
      query: uri.query);

  return new Response.movedPermanently(location.toString());
}

String _getHeader(String appName, String sanitizedHeading) {
  return '''<!DOCTYPE html>
<html>
<head>
  <title>$appName $sanitizedHeading</title>
  <style>
  html, body {
    margin: 0;
    padding: 0;
  }
  body {
    font-family: sans-serif;
  }
  h1 {
    background-color: #607D8B;
    color: white;
    font-weight: normal;
    margin: 0 0 10px 0;
    padding: 16px 32px;
    white-space: nowrap;
  }
  ul {
    margin: 0;
  }
  li {
    padding: 0;
  }
  a {
    line-height: 1.4em;
  }
  </style>
</head>
<body>
  <h1>$appName $sanitizedHeading</h1>
  <ul>
''';
}

const String _trailer = '</ul></body></html>';

Response listDirectory(String appName, String fileSystemPath, String dirPath) {
  StreamController<List<int>> controller = new StreamController<List<int>>();
  Encoding encoding = new Utf8Codec();
  HtmlEscape sanitizer = const HtmlEscape();

  void add(String string) {
    controller.add(encoding.encode(string));
  }

  var heading = path.relative(dirPath, from: fileSystemPath);
  if (heading == '.') {
    heading = '/';
  } else {
    heading = '/$heading/';
  }

  add(_getHeader(appName, sanitizer.convert(heading)));

  // Return a sorted listing of the directory contents asynchronously.
  Directory dir = new Directory(dirPath);
  dir.list().toList().then((List<FileSystemEntity> entities) {
    entities.sort((e1, e2) {
      if (e1 is Directory && e2 is! Directory) {
        return -1;
      }
      if (e1 is! Directory && e2 is Directory) {
        return 1;
      }
      return e1.path.compareTo(e2.path);
    });

    for (FileSystemEntity entity in entities) {
      String name = path.relative(entity.path, from: dirPath);
      if (entity is Directory) {
        name += '/';
      }
      String sanitizedName = sanitizer.convert(name);
      add('<li><a href="$sanitizedName">$sanitizedName</a></li>\n');
    }

    add(_trailer);
    controller.close();
  });

  return new Response.ok(controller.stream,
      encoding: encoding, headers: {HttpHeaders.CONTENT_TYPE: 'text/html'});
}
