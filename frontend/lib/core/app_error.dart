/// A failure that is safe to present to a Stella user.
///
/// [code] is for logging, analytics, and future API mappings. It is not shown
/// in the UI because transport details such as HTTP 500 do not help users.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// The single place where errors are converted into user-facing copy.
class AppErrorMessages {
  AppErrorMessages._();

  static const unexpected = 'Something went wrong. Please try again.';
  static const offline = 'Check your internet connection and try again.';
  static const timedOut =
      'The request took too long. Check your connection and try again.';

  static String message(Object error, {String? fallback}) {
    if (error is AppException) return error.message;

    var raw = error.toString().trim();
    final lower = raw.toLowerCase();

    if (_containsAny(lower, const [
      'socketexception',
      'clientexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'xmlhttprequest error',
    ])) {
      return offline;
    }

    if (_containsAny(lower, const [
      'timeoutexception',
      'timed out',
      'timeout',
    ])) {
      return timedOut;
    }

    // Plugin and platform exceptions often contain native class names, file
    // paths, and internal error codes. Keep those in logs, not in the UI.
    if (_containsAny(lower, const [
      'platformexception',
      'missingpluginexception',
      'formatexception',
      'typeerror',
      'stack trace',
    ])) {
      return fallback ?? unexpected;
    }

    raw = raw.replaceAll(RegExp(r'\bException:\s*'), '');
    raw = raw.replaceAll(
      RegExp(r'\s*\(status\s+\d{3}\)', caseSensitive: false),
      '',
    );
    raw = raw.trim();

    if (raw.isEmpty) return fallback ?? unexpected;
    if (error is! String) return fallback ?? unexpected;
    return raw;
  }

  static bool _containsAny(String value, List<String> needles) =>
      needles.any(value.contains);
}
