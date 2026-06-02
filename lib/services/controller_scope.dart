import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class ControllerScope extends InheritedNotifier<AppController> {
  const ControllerScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ControllerScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('ControllerScope was not found');
    }
    return scope.notifier!;
  }
}
