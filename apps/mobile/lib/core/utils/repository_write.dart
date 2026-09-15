import 'package:logger/logger.dart';

import '../../core/utils/repository_exception.dart';

Future<T> runRepositoryWrite<T>(
  Logger log,
  String logMessage,
  String userMessage,
  Future<T> Function() body,
) async {
  try {
    return await body();
  } on RepositoryException {
    rethrow;
  } on StateError catch (error) {
    throw RepositoryException(error.message);
  } catch (error, stack) {
    log.e(logMessage, error: error, stackTrace: stack);
    throw RepositoryException(userMessage);
  }
}
