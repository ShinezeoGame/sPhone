import 'package:flutter/widgets.dart';

import 'phone_controller.dart';

/// Rend le [PhoneController] accessible dans tout l'arbre de widgets.
class PhoneScope extends InheritedNotifier<PhoneController> {
  const PhoneScope({super.key, required PhoneController controller, required super.child})
    : super(notifier: controller);

  /// Récupère le contrôleur et reconstruit le widget à chaque changement d'état.
  static PhoneController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhoneScope>()!.notifier!;

  /// Récupère le contrôleur sans s'abonner aux changements (pour les actions).
  static PhoneController read(BuildContext context) => context.getInheritedWidgetOfExactType<PhoneScope>()!.notifier!;
}
