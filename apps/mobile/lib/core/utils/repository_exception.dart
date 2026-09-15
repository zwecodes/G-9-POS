class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

void requireOwnerRole(String role) {
  if (role != 'owner') {
    throw const RepositoryException(
      'Only the owner can do that.',
      code: 'ROLE_NOT_PERMITTED',
    );
  }
}
