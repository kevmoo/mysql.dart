import 'package:shelf/shelf.dart';

/// Well-known Shelf context key ('dolt.sync') taking a boolean value.
/// Set to true to explicitly force a sync, or false to explicitly skip sync.
const String doltSyncKey = 'dolt.sync';

/// Shelf middleware that triggers [onMutate] on mutations with status < 300,
/// or whenever [doltSyncKey] is set to true in request/response context.
Middleware doltSync(Future<void> Function() onMutate) {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      final explicitSync =
          response.context[doltSyncKey] as bool? ??
          request.context[doltSyncKey] as bool?;
      if (explicitSync == false) {
        return response;
      }
      final isMutation =
          request.method != 'GET' &&
          request.method != 'HEAD' &&
          request.method != 'OPTIONS';
      if (explicitSync == true || (isMutation && response.statusCode < 300)) {
        await onMutate();
      }
      return response;
    };
  };
}
