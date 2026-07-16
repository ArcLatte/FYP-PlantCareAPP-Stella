import 'package:flutter/foundation.dart';

/// Lightweight in-process invalidation for data shared by the persistent
/// bottom-navigation tabs. The indexed shell keeps tab states alive, so a
/// mutation on Home would otherwise leave Tasks stale until a manual refresh.
class AppRefreshBus {
  AppRefreshBus._();

  static final ValueNotifier<int> plants = ValueNotifier<int>(0);

  static void plantsChanged() => plants.value++;
}
