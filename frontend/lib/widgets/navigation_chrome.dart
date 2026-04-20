import 'package:flutter/material.dart';

class AppNavigationTheme {
  static const Color primary = Color(0xFF1A2F64);
  static const Color accent = Color(0xFF9CB5E8);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color muted = Color(0xFF64748B);
  static const Color activeSurface = Color(0xFFEBF0FF);
  static const Color activeText = Color(0xFF12224A);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color chipBackground = Color(0x26000000);
}

class AppBrandLockup extends StatelessWidget {
  const AppBrandLockup({
    super.key,
    this.logoSize = 40,
    this.smartFontSize = 14,
    this.dentQueueFontSize = 14,
    this.spacing = 6,
  });

  final double logoSize;
  final double smartFontSize;
  final double dentQueueFontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo_blue.png',
          width: logoSize,
          height: logoSize,
        ),
        SizedBox(width: spacing),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMART',
              style: TextStyle(
                color: AppNavigationTheme.accent,
                fontWeight: FontWeight.w900,
                fontSize: smartFontSize,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
            Text(
              'DentQueue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: dentQueueFontSize,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const <Widget>[],
    this.automaticallyImplyLeading = true,
    this.titleSpacing,
    this.centerTitle = false,
    this.showBottomAccent = true,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final double? titleSpacing;
  final bool centerTitle;
  final bool showBottomAccent;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showBottomAccent ? 4 : 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppNavigationTheme.primary,
      elevation: 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
      title:
          titleWidget ??
          Text(
            title!,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.25,
            ),
          ),
      actions: actions,
      bottom: showBottomAccent
          ? const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: ColoredBox(
                color: AppNavigationTheme.accent,
                child: SizedBox(height: 4),
              ),
            )
          : null,
    );
  }
}

class AppUserChip extends StatelessWidget {
  const AppUserChip({
    super.key,
    required this.name,
    required this.roleLabel,
    this.profileImage,
    this.onTap,
    this.width = 160,
  });

  final String name;
  final String roleLabel;
  final ImageProvider<Object>? profileImage;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppNavigationTheme.chipBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppNavigationTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white,
            backgroundImage: profileImage,
            child: profileImage == null
                ? const Icon(Icons.person, color: Colors.grey, size: 19)
                : null,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class AppNavigationDrawerHeader extends StatelessWidget {
  const AppNavigationDrawerHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    this.profileImage,
    this.fallbackInitial = 'U',
  });

  final String name;
  final String roleLabel;
  final ImageProvider<Object>? profileImage;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppNavigationTheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: profileImage,
            child: profileImage == null
                ? Text(
                    fallbackInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppNavigationTheme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppNavigationDrawerItem extends StatelessWidget {
  const AppNavigationDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? AppNavigationTheme.activeText
        : AppNavigationTheme.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: selected ? AppNavigationTheme.activeSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppNavigationTheme.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 14),
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomNavItem extends StatelessWidget {
  const AppBottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? AppNavigationTheme.primary
        : const Color(0xFF94A3B8);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppNavigationTheme.activeSurface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
