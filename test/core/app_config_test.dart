import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/config/app_config.dart';

void main() {
  group('AppFlavor.fromName', () {
    test('parses each known flavour', () {
      expect(AppFlavor.fromName('development'), AppFlavor.development);
      expect(AppFlavor.fromName('staging'), AppFlavor.staging);
      expect(AppFlavor.fromName('production'), AppFlavor.production);
    });

    test('is case and whitespace tolerant', () {
      expect(AppFlavor.fromName(' PRODUCTION '), AppFlavor.production);
    });

    test('falls back to development for unknown or empty input', () {
      expect(AppFlavor.fromName('qa'), AppFlavor.development);
      expect(AppFlavor.fromName(''), AppFlavor.development);
    });
  });

  group('AppConfig', () {
    test('reflects the product brief search policy', () {
      const AppConfig config = AppConfig(flavor: AppFlavor.production);

      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);
      expect(config.emergencyDefaultRadiusKm, 10);
      expect(config.allowedSearchRadiiKm, <int>[5, 10, 15, 20]);
    });
  });
}
