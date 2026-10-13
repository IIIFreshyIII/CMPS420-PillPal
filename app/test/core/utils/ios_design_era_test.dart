import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/utils/ios_design_era.dart';

void main() {
  tearDown(() {
    debugIOSMajorVersionOverride = null;
    debugIsHomeButtonOverride = null;
  });

  group('parseIOSMajorVersion', () {
    test('parses NSProcessInfo-style version strings', () {
      expect(parseIOSMajorVersion('Version 26.4 (Build 23E244)'), 26);
      expect(parseIOSMajorVersion('Version 18.6.2 (Build 22G100)'), 18);
      expect(parseIOSMajorVersion('Version 16.7.10 (Build 20H350)'), 16);
    });

    test('parses bare version numbers', () {
      expect(parseIOSMajorVersion('15.8'), 15);
    });

    test('returns null when there is no number', () {
      expect(parseIOSMajorVersion('unknown'), isNull);
    });
  });

  group('isHomeButtonDeviceMetrics', () {
    test('identifies iPhone SE (2nd & 3rd gen) and iPhone 8 metrics as home button', () {
      // 375x667, 0 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 0.0, size: const Size(375, 667)),
        isTrue,
      );
      // Landscape 667x375
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 0.0, size: const Size(667, 375)),
        isTrue,
      );
    });

    test('identifies iPhone SE (1st gen) metrics as home button', () {
      // 320x568, 0 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 0.0, size: const Size(320, 568)),
        isTrue,
      );
    });

    test('identifies iPhone 8 Plus metrics as home button', () {
      // 414x736, 0 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 0.0, size: const Size(414, 736)),
        isTrue,
      );
    });

    test('rejects modern notch and Dynamic Island iPhones', () {
      // iPhone 17 / 16 / 15 / 14 Pro: 393x852, 34 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 34.0, size: const Size(393, 852)),
        isFalse,
      );
      // Landscape with 21 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 21.0, size: const Size(852, 393)),
        isFalse,
      );
      // iPhone mini: 375x812, 34 bottom inset
      expect(
        isHomeButtonDeviceMetrics(bottomInset: 34.0, size: const Size(375, 812)),
        isFalse,
      );
    });
  });

  group('currentIOSDesignEra', () {
    test('non-home-button device on iOS 26 and newer uses Liquid Glass', () {
      debugIsHomeButtonOverride = false;
      debugIOSMajorVersionOverride = 26;
      expect(currentIOSDesignEra(), IOSDesignEra.liquidGlass);
      debugIOSMajorVersionOverride = 27;
      expect(currentIOSDesignEra(), IOSDesignEra.liquidGlass);
    });

    test('home-button device on iOS 26+ always uses classic tab bar', () {
      debugIsHomeButtonOverride = true;
      debugIOSMajorVersionOverride = 26;
      expect(currentIOSDesignEra(), IOSDesignEra.classic);
      debugIOSMajorVersionOverride = 27;
      expect(currentIOSDesignEra(), IOSDesignEra.classic);
    });

    test('iOS 25 and older always uses classic tab bar regardless of home button', () {
      debugIsHomeButtonOverride = false;
      debugIOSMajorVersionOverride = 18;
      expect(currentIOSDesignEra(), IOSDesignEra.classic);

      debugIsHomeButtonOverride = true;
      debugIOSMajorVersionOverride = 18;
      expect(currentIOSDesignEra(), IOSDesignEra.classic);
    });

    test('defaults to Liquid Glass when version and button are unknown on desktop host', () {
      expect(currentIOSDesignEra(), IOSDesignEra.liquidGlass);
    });

    testWidgets('resolves classic era from iPhone SE MediaQuery context even on iOS 26',
        (tester) async {
      debugIOSMajorVersionOverride = 26;
      late IOSDesignEra era;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            padding: EdgeInsets.only(top: 20),
            viewPadding: EdgeInsets.only(top: 20),
          ),
          child: Builder(
            builder: (context) {
              era = currentIOSDesignEra(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(era, IOSDesignEra.classic);
    });

    testWidgets('resolves Liquid Glass from iPhone 17 MediaQuery context on iOS 26',
        (tester) async {
      debugIOSMajorVersionOverride = 26;
      late IOSDesignEra era;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(top: 54, bottom: 34),
            viewPadding: EdgeInsets.only(top: 54, bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              era = currentIOSDesignEra(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(era, IOSDesignEra.liquidGlass);
    });
  });
}
