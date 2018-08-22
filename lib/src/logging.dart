import 'dart:async';

import 'package:cli_util/cli_logging.dart';
import 'package:shelf/shelf.dart';

class MyVerboseLogger extends VerboseLogger {
  Ansi ansi;
  Stopwatch _timer;

  MyVerboseLogger({this.ansi}) {
    ansi ??= new Ansi(Ansi.terminalSupportsAnsi);
    _timer = new Stopwatch()..start();
  }

  bool get isVerbose => true;

  void stderr(String message) {
    print('${_createTag()} ${ansi.red}$message${ansi.none}');
  }

  void stdout(String message) {
    print('${_createTag()} ${ansi.bold}$message${ansi.none}');
  }

  void trace(String message) {
    print('${_createTag()} $message');
  }

  String _createTag() {
    double seconds = (_timer.elapsedMilliseconds ~/ 10) / 100.0;
    return '${ansi.gray}[${seconds.toStringAsFixed(2).padLeft(6)}s]${ansi.none}';
  }
}

Middleware logShelfRequests(Logger logger) {
  return (Handler innerHandler) {
    return (Request request) {
      return new Future.sync(() => innerHandler(request)).then(
          (Response response) {
        String msg = _getMessage(
          logger,
          request.requestedUri,
          request.method,
          response.statusCode,
        );

        logger.stdout(msg);

        return response;
      }, onError: (error, stackTrace) {
        if (error is HijackException) throw error;

        String msg = _getErrorMessage(
          request.requestedUri,
          request.method,
          error,
          stackTrace,
        );

        logger.stderr(msg);

        throw error;
      });
    };
  };
}

String _getMessage(
    Logger logger, Uri requestedUri, String method, int statusCode) {
  String code = statusCode >= 400
      ? logger.ansi.error(statusCode.toString())
      : statusCode.toString();
  return '$code $method ${logger.ansi.emphasized(requestedUri.path)}'
      '${_formatQuery(requestedUri.query)}';
}

String _getErrorMessage(
  Uri requestedUri,
  String method,
  Object error, [
  StackTrace stack,
]) {
  String msg = '$method\t${requestedUri.path}'
      '${_formatQuery(requestedUri.query)}\n$error';
  if (stack == null) return msg;

  return '$msg\n$stack';
}

String _formatQuery(String query) {
  return query == '' ? '' : '?$query';
}
