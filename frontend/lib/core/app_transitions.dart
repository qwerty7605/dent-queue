import 'package:flutter/material.dart';

const Duration kAppPageTransitionDuration = Duration(milliseconds: 360);
const Duration kAppDialogTransitionDuration = Duration(milliseconds: 280);

Route<T> buildAppPageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: kAppPageTransitionDuration,
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final Animation<Offset> slide =
          Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class AppPageTransitionsTheme extends PageTransitionsTheme {
  const AppPageTransitionsTheme()
    : super(
        builders: const <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _AppPageTransitionsBuilder(),
          TargetPlatform.iOS: _AppPageTransitionsBuilder(),
          TargetPlatform.macOS: _AppPageTransitionsBuilder(),
          TargetPlatform.windows: _AppPageTransitionsBuilder(),
          TargetPlatform.linux: _AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _AppPageTransitionsBuilder(),
        },
      );
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = const Color(0x660A101C),
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset beginOffset = const Offset(0, 0.04),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: kAppDialogTransitionDuration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final Animation<double> scale = Tween<double>(begin: 0.96, end: 1)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            ),
          );
      final Animation<Offset> slide =
          Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Builder(builder: builder);
    },
  );
}
