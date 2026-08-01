import 'package:dolt/shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('doltSync middleware', () {
    test('triggers sync on POST 200', () async {
      var synced = 0;
      final handler = const Pipeline()
          .addMiddleware(doltSync(() async => synced++))
          .addHandler((req) => Response.ok('saved'));

      final res = await handler(
        Request('POST', Uri.parse('http://localhost/api')),
      );
      expect(res.statusCode, 200);
      expect(synced, 1);
    });

    test('skips sync on GET 200', () async {
      var synced = 0;
      final handler = const Pipeline()
          .addMiddleware(doltSync(() async => synced++))
          .addHandler((req) => Response.ok('fetched'));

      final res = await handler(
        Request('GET', Uri.parse('http://localhost/api')),
      );
      expect(res.statusCode, 200);
      expect(synced, 0);
    });

    test('forces sync on GET when dolt.sync is true', () async {
      var synced = 0;
      final handler = const Pipeline()
          .addMiddleware(doltSync(() async => synced++))
          .addHandler(
            (req) =>
                Response.ok('fetched').change(context: {doltSyncKey: true}),
          );

      final res = await handler(
        Request('GET', Uri.parse('http://localhost/api')),
      );
      expect(res.statusCode, 200);
      expect(synced, 1);
    });

    test('skips sync on POST when dolt.sync is false', () async {
      var synced = 0;
      final handler = const Pipeline()
          .addMiddleware(doltSync(() async => synced++))
          .addHandler(
            (req) => Response.ok('saved').change(context: {doltSyncKey: false}),
          );

      final res = await handler(
        Request('POST', Uri.parse('http://localhost/api')),
      );
      expect(res.statusCode, 200);
      expect(synced, 0);
    });

    test('skips sync on HEAD 200', () async {
      var synced = 0;
      final handler = const Pipeline()
          .addMiddleware(doltSync(() async => synced++))
          .addHandler((req) => Response.ok(''));

      final res = await handler(
        Request('HEAD', Uri.parse('http://localhost/api')),
      );
      expect(res.statusCode, 200);
      expect(synced, 0);
    });
  });
}
