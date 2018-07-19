import 'dart:async';
import 'dart:io';

import 'package:http_parser/http_parser.dart' show formatHttpDate;
import 'package:mime/mime.dart';
import 'package:package_config/packages_file.dart' as packages_file;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

Handler createPackagesHandler(String rootPath) {
  Directory rootDir = new Directory(rootPath);
  if (!rootDir.existsSync()) {
    throw new ArgumentError('A directory corresponding to rootPath '
        '"$rootPath" could not be found');
  }

  String resolvedRootPath = rootDir.resolveSymbolicLinksSync();

  return (Request request) {
    var uri = request.requestedUri;
    if (uri.path.endsWith('/')) {
      return new Response.notFound('Not Found');
    }

    List<String> segments = uri.pathSegments;
    if (!segments.contains('packages')) {
      return new Response.notFound('Not Found');
    }

    int index = segments.lastIndexOf('packages');
    if (index == 0 || index + 2 >= segments.length) {
      return new Response.notFound('Not Found');
    }

    List<String> baseSegments = segments.sublist(0, index - 1);
    String packageName = segments[index + 1];
    List<String> relativeSegments = segments.sublist(index + 2);
    if (relativeSegments.contains('..')) {
      return new Response.notFound('Not Found');
    }

    String basePath = path.joinAll([resolvedRootPath]..addAll(baseSegments));
    FileSystemEntityType entityType =
        FileSystemEntity.typeSync(basePath, followLinks: true);

    if (entityType != FileSystemEntityType.directory) {
      return new Response.notFound('Not Found');
    }

    Directory dir = new Directory(basePath);
    if (!dir.existsSync()) {
      return new Response.notFound('Not Found');
    }

    // Do not serve a file outside of the original resolvedRootPath.
    String resolvedPath = dir.resolveSymbolicLinksSync();
    if (!isWithin(resolvedRootPath, resolvedPath)) {
      return new Response.notFound('Not Found');
    }

    File packagesFile = findPackagesfile(dir, resolvedRootPath);
    if (packagesFile == null) {
      return new Response.notFound('Not Found');
    }

    Map<String, Uri> packageMap;

    try {
      packageMap = packages_file.parse(
          packagesFile.readAsBytesSync(), packagesFile.parent.uri);
    } on FormatException catch (_) {
      // The .packages file was malformed
      return new Response.notFound('Not Found');
    } on FileSystemException catch (_) {
      // Unable to read the .packages file.
      return new Response.notFound('Not Found');
    }

    if (!packageMap.containsKey(packageName)) {
      return new Response.notFound('Not Found');
    }

    Uri packageUri = packageMap[packageName];
    if (packageUri.scheme != 'file') {
      return new Response.notFound('Not Found');
    }

    Uri resolvedUri = packageUri.resolve(relativeSegments.join('/'));
    return _handleFile(request, new File.fromUri(resolvedUri));
  };
}

final MimeTypeResolver _mimeTypeResolver = new MimeTypeResolver();

Future<Response> _handleFile(Request request, File file) async {
  var stat = file.statSync();
  var ifModifiedSince = request.ifModifiedSince;

  if (ifModifiedSince != null) {
    var fileChangeAtSecResolution = _toSecondResolution(stat.changed);
    if (!fileChangeAtSecResolution.isAfter(ifModifiedSince)) {
      return new Response.notModified();
    }
  }

  var headers = {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
    HttpHeaders.lastModifiedHeader: formatHttpDate(stat.changed)
  };

  String contentType = _mimeTypeResolver.lookup(file.path);
  if (contentType != null) {
    headers[HttpHeaders.contentTypeHeader] = contentType;
  }

  return new Response.ok(file.openRead(), headers: headers);
}

DateTime _toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(new Duration(milliseconds: dt.millisecond));
}

File findPackagesfile(Directory dir, String resolvedRootPath) {
  while (dir != null) {
    String fullPath = path.join(dir.path, '.packages');
    if (FileSystemEntity.isFileSync(fullPath)) {
      return new File(fullPath);
    }
    dir = dir.parent;
    if (!isWithin(resolvedRootPath, dir.path)) {
      return null;
    }
  }

  return null;
}

bool isWithin(String base, String subPath) {
  if (base == subPath) {
    return true;
  }
  return path.isWithin(base, subPath);
}
