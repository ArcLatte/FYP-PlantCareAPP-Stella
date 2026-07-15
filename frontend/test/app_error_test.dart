import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_error.dart';

void main() {
  group('AppErrorMessages', () {
    test('returns safe messages from AppException', () {
      const error = AppException(
        'That plant could not be found.',
        code: 'plant_not_found',
      );

      expect(AppErrorMessages.message(error), 'That plant could not be found.');
      expect(AppErrorMessages.message(error), isNot(contains(error.code!)));
    });

    test('maps connection details to an actionable message', () {
      final message = AppErrorMessages.message(
        Exception('SocketException: Failed host lookup: api.example.test'),
      );

      expect(message, AppErrorMessages.offline);
      expect(message, isNot(contains('SocketException')));
    });

    test('hides platform diagnostics and uses the supplied fallback', () {
      final message = AppErrorMessages.message(
        Exception(
          'PlatformException(camera_error, native details, null, null)',
        ),
        fallback: 'Camera unavailable. Check camera permission and try again.',
      );

      expect(
        message,
        'Camera unavailable. Check camera permission and try again.',
      );
    });

    test(
      'removes exception prefixes and HTTP statuses from legacy strings',
      () {
        final message = AppErrorMessages.message(
          'Could not save: Exception: Request failed (status 500)',
        );

        expect(message, 'Could not save: Request failed');
      },
    );

    test('never exposes an unknown exception', () {
      final message = AppErrorMessages.message(
        StateError('internal state and implementation details'),
        fallback: 'Could not complete that action. Please try again.',
      );

      expect(message, 'Could not complete that action. Please try again.');
      expect(message, isNot(contains('StateError')));
      expect(message, isNot(contains('implementation details')));
    });
  });
}
