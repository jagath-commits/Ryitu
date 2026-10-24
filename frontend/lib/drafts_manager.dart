import 'package:flutter/foundation.dart';

/// Central reactive manager for drafts across WritePage and ProfilePage.
/// Ensures that when a draft is saved, updated, or deleted, all listeners
/// (especially ProfilePage) immediately refresh their drafts in real-time.
class DraftsManager extends ChangeNotifier {
  static final DraftsManager instance = DraftsManager._internal();
  DraftsManager._internal();

  int _version = 0;
  int get version => _version;

  /// Notify all active listeners that drafts have changed
  void notifyDraftsChanged() {
    _version++;
    notifyListeners();
  }
}
