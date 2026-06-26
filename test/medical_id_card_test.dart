import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/views/main/medical_id/widgets/medical_id_card.dart';

UserModel _full() => UserModel(
      name: 'Ayesha Khan',
      bloodType: 'O-',
      height: '165',
      weight: '60',
      profileImage: '',
      disease: 'Asthma',
      allergy: 'Penicillin',
      age: '28',
      emergencyText: 'Inhaler in left bag pocket',
    );

UserModel _empty() => UserModel(
      name: 'N/A',
      bloodType: 'N/A',
      height: 'N/A',
      weight: 'N/A',
      profileImage: '',
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('renders all populated fields', (tester) async {
    await _pump(
      tester,
      MedicalIdCard(
        user: _full(),
        primaryContactName: 'Bilal',
        primaryContactPhone: '03001234567',
      ),
    );

    expect(find.text('MEDICAL ID'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('O-'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text('Inhaler in left bag pocket'), findsOneWidget);
    expect(find.text('Bilal'), findsOneWidget);
    expect(find.text('03001234567'), findsOneWidget);
    // call action available when a contact phone is present
    expect(find.byIcon(Icons.call), findsOneWidget);
  });

  testWidgets('handles missing data gracefully', (tester) async {
    await _pump(tester, MedicalIdCard(user: _empty()));

    // No crash; placeholders shown, blood type collapses to a dash.
    expect(find.text('MEDICAL ID'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Not set'), findsWidgets);
    // No call action without a contact.
    expect(find.byIcon(Icons.call), findsNothing);
  });
}
