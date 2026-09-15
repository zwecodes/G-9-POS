import 'package:uuid/uuid.dart';

class UuidGenerator {
  UuidGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  String v4() => _uuid.v4();
}
