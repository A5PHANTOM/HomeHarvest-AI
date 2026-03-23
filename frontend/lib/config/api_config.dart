import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _backendUrlOverride = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_backendUrlOverride.isNotEmpty) return _backendUrlOverride;

    if (kIsWeb) return 'http://127.0.0.1:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator maps host machine localhost to 10.0.2.2
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000';
    }
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
