import 'package:flutter_test/flutter_test.dart';
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

void main() {
  group('UTMParams', () {
    group('Constructor', () {
      test('creates empty UTMParams with all null values', () {
        const utm = UTMParams.empty();
        expect(utm.source, isNull);
        expect(utm.medium, isNull);
        expect(utm.campaign, isNull);
        expect(utm.content, isNull);
        expect(utm.term, isNull);
        expect(utm.isEmpty, isTrue);
        expect(utm.isNotEmpty, isFalse);
      });

      test('creates UTMParams with provided values', () {
        const utm = UTMParams(
          source: 'facebook',
          medium: 'cpc',
          campaign: 'summer-sale',
          content: 'ad-1',
          term: 'shoes',
        );

        expect(utm.source, equals('facebook'));
        expect(utm.medium, equals('cpc'));
        expect(utm.campaign, equals('summer-sale'));
        expect(utm.content, equals('ad-1'));
        expect(utm.term, equals('shoes'));
        expect(utm.isEmpty, isFalse);
        expect(utm.isNotEmpty, isTrue);
      });

      test('creates UTMParams with partial values', () {
        const utm = UTMParams(
          source: 'google',
          campaign: 'winter-promo',
        );

        expect(utm.source, equals('google'));
        expect(utm.campaign, equals('winter-promo'));
        expect(utm.medium, isNull);
        expect(utm.content, isNull);
        expect(utm.term, isNull);
        expect(utm.isNotEmpty, isTrue);
      });
    });

    group('fromUri', () {
      test('extracts all UTM parameters from URI', () {
        final uri = Uri.parse(
          'https://example.com/page?utm_source=facebook&utm_medium=cpc&utm_campaign=summer&utm_content=ad1&utm_term=shoes',
        );
        final utm = UTMParams.fromUri(uri);

        expect(utm, isNotNull);
        expect(utm!.source, equals('facebook'));
        expect(utm.medium, equals('cpc'));
        expect(utm.campaign, equals('summer'));
        expect(utm.content, equals('ad1'));
        expect(utm.term, equals('shoes'));
      });

      test('extracts partial UTM parameters from URI', () {
        final uri = Uri.parse('https://example.com?utm_source=google&utm_campaign=test');
        final utm = UTMParams.fromUri(uri);

        expect(utm, isNotNull);
        expect(utm!.source, equals('google'));
        expect(utm.campaign, equals('test'));
        expect(utm.medium, isNull);
      });

      test('returns null if no UTM parameters in URI', () {
        final uri = Uri.parse('https://example.com?foo=bar');
        final utm = UTMParams.fromUri(uri);

        expect(utm, isNull);
      });

      test('handles URL-encoded UTM values', () {
        final uri = Uri.parse('https://example.com?utm_campaign=summer%20sale&utm_source=facebook%20ads');
        final utm = UTMParams.fromUri(uri);

        expect(utm, isNotNull);
        expect(utm!.campaign, equals('summer sale'));
        expect(utm.source, equals('facebook ads'));
      });
    });

    group('fromUrl', () {
      test('extracts UTM from URL string', () {
        const url = 'https://example.com?utm_source=twitter&utm_campaign=promo';
        final utm = UTMParams.fromUrl(url);

        expect(utm, isNotNull);
        expect(utm!.source, equals('twitter'));
        expect(utm.campaign, equals('promo'));
      });

      test('returns null for invalid URL', () {
        const url = 'not-a-valid-url';
        final utm = UTMParams.fromUrl(url);

        expect(utm, isNull);
      });

      test('returns null for URL without UTM', () {
        const url = 'https://example.com';
        final utm = UTMParams.fromUrl(url);

        expect(utm, isNull);
      });
    });

    group('fromQueryString', () {
      test('extracts UTM from query string', () {
        const query = 'utm_source=google&utm_medium=cpc&utm_campaign=winter';
        final utm = UTMParams.fromQueryString(query);

        expect(utm, isNotNull);
        expect(utm!.source, equals('google'));
        expect(utm.medium, equals('cpc'));
        expect(utm.campaign, equals('winter'));
      });

      test('extracts UTM with other parameters present', () {
        const query = 'foo=bar&utm_source=email&baz=qux&utm_campaign=newsletter';
        final utm = UTMParams.fromQueryString(query);

        expect(utm, isNotNull);
        expect(utm!.source, equals('email'));
        expect(utm.campaign, equals('newsletter'));
      });

      test('returns null for empty query string', () {
        final utm = UTMParams.fromQueryString('');
        expect(utm, isNull);
      });

      test('returns null for query string without UTM', () {
        const query = 'foo=bar&baz=qux';
        final utm = UTMParams.fromQueryString(query);
        expect(utm, isNull);
      });

      test('handles URL-encoded values in query string', () {
        const query = 'utm_campaign=summer%20sale&utm_source=facebook';
        final utm = UTMParams.fromQueryString(query);

        expect(utm, isNotNull);
        expect(utm!.campaign, equals('summer sale'));
      });
    });

    group('toJson / fromJson', () {
      test('converts to and from JSON', () {
        const original = UTMParams(
          source: 'facebook',
          medium: 'social',
          campaign: 'holiday-2024',
          content: 'video-ad',
          term: 'winter-jacket',
        );

        final json = original.toJson();
        final restored = UTMParams.fromJson(json);

        expect(restored.source, equals(original.source));
        expect(restored.medium, equals(original.medium));
        expect(restored.campaign, equals(original.campaign));
        expect(restored.content, equals(original.content));
        expect(restored.term, equals(original.term));
      });

      test('handles partial values in JSON', () {
        final json = {
          'source': 'google',
          'campaign': 'test',
        };

        final utm = UTMParams.fromJson(json);
        expect(utm.source, equals('google'));
        expect(utm.campaign, equals('test'));
        expect(utm.medium, isNull);
        expect(utm.content, isNull);
        expect(utm.term, isNull);
      });

      test('toJson only includes non-null values', () {
        const utm = UTMParams(
          source: 'twitter',
          campaign: 'promo',
        );

        final json = utm.toJson();
        expect(json.containsKey('source'), isTrue);
        expect(json.containsKey('campaign'), isTrue);
        expect(json.containsKey('medium'), isFalse);
        expect(json.containsKey('content'), isFalse);
        expect(json.containsKey('term'), isFalse);
      });
    });

    group('toQueryParams', () {
      test('converts to query parameters map', () {
        const utm = UTMParams(
          source: 'facebook',
          medium: 'cpc',
          campaign: 'summer',
        );

        final params = utm.toQueryParams();
        expect(params['utm_source'], equals('facebook'));
        expect(params['utm_medium'], equals('cpc'));
        expect(params['utm_campaign'], equals('summer'));
        expect(params.containsKey('utm_content'), isFalse);
        expect(params.containsKey('utm_term'), isFalse);
      });

      test('returns empty map for empty UTM', () {
        const utm = UTMParams.empty();
        final params = utm.toQueryParams();
        expect(params.isEmpty, isTrue);
      });
    });

    group('toMap', () {
      test('converts to map with all fields', () {
        const utm = UTMParams(
          source: 'google',
          campaign: 'test',
        );

        final map = utm.toMap();
        expect(map['source'], equals('google'));
        expect(map['campaign'], equals('test'));
        expect(map['medium'], isNull);
        expect(map['content'], isNull);
        expect(map['term'], isNull);
        expect(map.length, equals(5));
      });
    });

    group('copyWith', () {
      test('creates copy with updated values', () {
        const original = UTMParams(
          source: 'facebook',
          campaign: 'summer',
        );

        final updated = original.copyWith(
          medium: 'cpc',
          campaign: 'winter',
        );

        expect(updated.source, equals('facebook')); // Unchanged
        expect(updated.medium, equals('cpc')); // Added
        expect(updated.campaign, equals('winter')); // Updated
      });

      test('creates identical copy when no values provided', () {
        const original = UTMParams(
          source: 'twitter',
          campaign: 'promo',
        );

        final copy = original.copyWith();
        expect(copy.source, equals(original.source));
        expect(copy.campaign, equals(original.campaign));
      });
    });

    group('merge', () {
      test('merges two UTMParams with other taking precedence', () {
        const base = UTMParams(
          source: 'facebook',
          medium: 'social',
          campaign: 'summer',
        );

        const other = UTMParams(
          source: 'google', // Override
          campaign: 'winter', // Override
          content: 'ad-1', // New
        );

        final merged = base.merge(other);
        expect(merged.source, equals('google')); // From other
        expect(merged.medium, equals('social')); // From base
        expect(merged.campaign, equals('winter')); // From other
        expect(merged.content, equals('ad-1')); // From other
      });

      test('handles merging with empty UTM', () {
        const base = UTMParams(source: 'facebook', campaign: 'test');
        const empty = UTMParams.empty();

        final merged = base.merge(empty);
        expect(merged.source, equals('facebook'));
        expect(merged.campaign, equals('test'));
      });
    });

    group('isEmpty / isNotEmpty', () {
      test('isEmpty returns true for all null values', () {
        const utm = UTMParams.empty();
        expect(utm.isEmpty, isTrue);
        expect(utm.isNotEmpty, isFalse);
      });

      test('isNotEmpty returns true if any value is set', () {
        const utm1 = UTMParams(source: 'facebook');
        const utm2 = UTMParams(campaign: 'test');
        const utm3 = UTMParams(medium: 'cpc');

        expect(utm1.isNotEmpty, isTrue);
        expect(utm2.isNotEmpty, isTrue);
        expect(utm3.isNotEmpty, isTrue);
      });
    });

    group('Equality', () {
      test('equal UTMParams are equal', () {
        const utm1 = UTMParams(
          source: 'facebook',
          campaign: 'summer',
        );
        const utm2 = UTMParams(
          source: 'facebook',
          campaign: 'summer',
        );

        expect(utm1, equals(utm2));
        expect(utm1.hashCode, equals(utm2.hashCode));
      });

      test('different UTMParams are not equal', () {
        const utm1 = UTMParams(source: 'facebook');
        const utm2 = UTMParams(source: 'google');

        expect(utm1, isNot(equals(utm2)));
      });
    });

    group('toString', () {
      test('provides readable string representation', () {
        const utm = UTMParams(
          source: 'facebook',
          campaign: 'summer-sale',
        );

        final str = utm.toString();
        expect(str, contains('facebook'));
        expect(str, contains('summer-sale'));
      });
    });
  });
}
