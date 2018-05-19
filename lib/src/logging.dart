import 'package:cli_util/cli_logging.dart';

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
