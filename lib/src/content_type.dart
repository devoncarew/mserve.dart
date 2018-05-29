import 'package:mime/mime.dart';

// TODO: remove application/dart from the default mime map
class CustomMimeTypeResolver extends MimeTypeResolver {
  CustomMimeTypeResolver() {
    addExtension('dart', 'text/x-dart');
  }
}
