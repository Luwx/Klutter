import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'src/linux_app_menu_delegate.dart';
export 'src/menu_items.dart';

/// Installs KDE Wayland support for Flutter's standard [PlatformMenuBar].
abstract final class LinuxAppMenu {
  /// Installs the menu delegate used by [PlatformMenuBar].
  ///
  /// Call this after [WidgetsFlutterBinding.ensureInitialized] and before
  /// creating a [PlatformMenuBar].
  static void initialize() {
    WidgetsBinding.instance.platformMenuDelegate = LinuxAppMenuDelegate();
  }

  /// Whether this package can run on the current target platform.
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.linux;
}

/// Installs [LinuxAppMenu] and hosts a standard Flutter [PlatformMenuBar].
class LinuxAppMenuBar extends StatefulWidget {
  const LinuxAppMenuBar({super.key, required this.menus, this.child});

  final List<PlatformMenuItem> menus;
  final Widget? child;

  @override
  State<LinuxAppMenuBar> createState() => _LinuxAppMenuBarState();
}

class _LinuxAppMenuBarState extends State<LinuxAppMenuBar> {
  @override
  void initState() {
    super.initState();
    LinuxAppMenu.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(menus: widget.menus, child: widget.child);
  }
}
