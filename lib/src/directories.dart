import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
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
  <title>[$appName] $sanitizedHeading</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/Primer/6.0.0/build.css">
  <style>
.masthead {
  padding-top: 1rem;
  padding-bottom: 1rem;
  margin-bottom: 1.5rem;
  background-color: #4078c0;
  color: #fff;
}
.footer {
  padding-top: 1rem;
  padding-bottom: 1rem;
  margin-top: 2rem;
  line-height: 1.75;
  color: #7a7a7a;
  border-top: 1px solid #eee;
}
li {
  display: block;
}
.wide {
  min-width: 300px;
  display: inline-block;
}
.medium {
  min-width: 220px;
  display: inline-block;
}
.narrow {
  min-width: 120px;
  display: inline-block;
}
.right {
  text-align: right;
}
.fixed {
  font-family: monospace;
  padding-left: 10px;
}
  </style>
</head>
<body>
<header class="masthead">
  <div class="container">
    <h2>$sanitizedHeading</h2>
  </div>
</header>
  <div class="container">
    <ul>
''';
}

String getTrailer(int fileCount) {
  return '''
</ul>
</div>
<div class="container">
<footer class="footer right">
  $fileCount ${fileCount == 1 ? 'file' : 'files'}
</footer>
</div>
</body>
</html>
''';
}

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

    NumberFormat nf = new NumberFormat.decimalPattern();

    for (FileSystemEntity entity in entities) {
      String name = path.relative(entity.path, from: dirPath);
      if (entity is Directory) {
        name += '/';
      }
      String sanitizedName = sanitizer.convert(name);
      String fileSize = entity is File ? nf.format(entity.lengthSync()) : '';
      String date = entity.statSync().modified.toString();

      add('<li>');
      add('<span class="wide"><a href="$sanitizedName">$sanitizedName</a></span>');
      add('<span class="narrow right fixed">$fileSize</span>');
      add('<span class="medium right fixed">$date</span>');
      add('</li>\n');
    }

    add(getTrailer(entities.length));
    controller.close();
  });

  return new Response.ok(controller.stream,
      encoding: encoding, headers: {HttpHeaders.contentTypeHeader: 'text/html'});
}
