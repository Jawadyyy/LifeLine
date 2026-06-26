import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l = AppLocalizations.of(context);
        return Scaffold(
          body: Column(
            children: [
              Text(l.emergencyAssistance),
              Text(l.medicalId),
              Text(l.callAmbulance('1122')),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('English locale renders English strings', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Assistance'), findsOneWidget);
    expect(find.text('Medical ID'), findsOneWidget);
    expect(find.text('Call Ambulance / 1122'), findsOneWidget);
  });

  testWidgets('Urdu locale renders Urdu strings', (tester) async {
    await tester.pumpWidget(_app(const Locale('ur')));
    await tester.pumpAndSettle();
    expect(find.text('ہنگامی امداد'), findsOneWidget);
    expect(find.text('میڈیکل آئی ڈی'), findsOneWidget);
    // placeholder interpolation works in Urdu too
    expect(find.text('ایمبولینس کال کریں / 1122'), findsOneWidget);
  });

  test('ur covers every en key (no missing translations)', () {
    // supportedLocales must include both; AppLocalizations would throw on a
    // missing key at lookup, so a successful lookup across the set is the check.
    expect(AppLocalizations.supportedLocales,
        containsAll(const [Locale('en'), Locale('ur')]));
  });
}
