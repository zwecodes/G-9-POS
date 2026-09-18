import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g9pos_admin/main.dart';

void main() {
  testWidgets('admin app boots to login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: G9posAdminApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.text('Sign in').evaluate().isNotEmpty, isTrue);
  });
}
