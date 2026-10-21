import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/data/models/profile.dart';

void main() {
  group('CareRecipient / Profile model tests', () {
    test('initials generates 2 letters for full names', () {
      const p1 = CareRecipient(
        id: '1',
        name: 'John Doe',
        color: Colors.blue,
      );
      expect(p1.initials, 'JD');

      const p2 = CareRecipient(
        id: '2',
        name: 'Mary Jane Watson',
        color: Colors.purple,
      );
      expect(p2.initials, 'MJ');
    });

    test('initials generates uppercase letters for single word names', () {
      const p1 = CareRecipient(
        id: '1',
        name: 'Alice',
        color: Colors.teal,
      );
      expect(p1.initials, 'AL');

      const p2 = CareRecipient(
        id: '2',
        name: 'M',
        color: Colors.pink,
      );
      expect(p2.initials, 'M');
    });

    test('initials falls back to U for empty or whitespace name', () {
      const p = CareRecipient(
        id: '1',
        name: '   ',
        color: Colors.grey,
      );
      expect(p.initials, 'U');
    });

    test('badgeColor and isPrimaryUser mirror underlying properties', () {
      const p = CareRecipient(
        id: 'primary',
        name: 'Cade',
        color: Color(0xFF168B87),
        isPrimary: true,
      );
      expect(p.badgeColor, const Color(0xFF168B87));
      expect(p.isPrimaryUser, isTrue);
    });
  });
}
