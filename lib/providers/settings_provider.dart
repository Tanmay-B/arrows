import 'package:flutter/foundation.dart';

import '../services/settings_store.dart';

class SettingsProvider extends ChangeNotifier {
  bool _hapticsEnabled = true;
  bool _isLoaded = false;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _hapticsEnabled = await SettingsStore.loadHapticsEnabled();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;

    _hapticsEnabled = enabled;
    notifyListeners();
    await SettingsStore.saveHapticsEnabled(enabled);
  }
}
