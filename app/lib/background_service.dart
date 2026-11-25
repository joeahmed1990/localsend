import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point of the foreground service isolate.
/// The service itself only keeps the app process alive,
/// the LocalSend server keeps running in the main isolate.
@pragma('vm:entry-point')
void backgroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Keeps LocalSend alive in the background on Android.
/// Does nothing on Windows / Linux.
class BackgroundService {
  static bool get _supported => Platform.isAndroid;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_supported || _initialized) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'localsend_background',
        channelName: 'YouSend background service',
        channelDescription: 'Keeps YouSend running so you can receive files.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  static Future<void> start() async {
    if (!_supported) return;
    await init();

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 7331,
      notificationTitle: 'YouSend',
      notificationText: 'Running in the background and ready to receive files',
      callback: backgroundServiceCallback,
    );
  }

  static Future<void> stop() async {
    if (!_supported) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
