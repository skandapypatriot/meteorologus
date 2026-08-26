import 'package:flutter_test/flutter_test.dart';
import 'package:meteorologus_app/services/claim_service.dart';

void main() {
  group('ClaimService MAC Tests', () {
    test('Normalizes MAC formatting', () {
      expect(ClaimService.normalizeMac('7c:df:8b:62:ac:88'), '7CDF8B62AC88');
      expect(ClaimService.normalizeMac('7c-df-8b-62-ac-88'), '7CDF8B62AC88');
      expect(ClaimService.normalizeMac('7cdf8b62ac88'), '7CDF8B62AC88');
    });

    test('Validates 12-digit hex MAC', () {
      expect(ClaimService.isValidMac('7CDF8B62AC88'), isTrue);
      expect(ClaimService.isValidMac('7c:df:8b:62:ac:88'), isTrue);
      expect(ClaimService.isValidMac('1234567890AB'), isTrue);

      expect(ClaimService.isValidMac('12345'), isFalse);
      expect(ClaimService.isValidMac('7CDF8B62AC88ZZ'), isFalse);
      expect(ClaimService.isValidMac(''), isFalse);
    });
  });
}
