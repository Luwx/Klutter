import 'package:flutter/widgets.dart';

/// A titled separator rendered as a menu section heading when supported.
///
/// KDE's menu style renders the label as a non-interactive heading above the
/// separator. Other DBusMenu hosts may render this as a plain separator.
class LinuxMenuSection extends PlatformMenuItem {
  const LinuxMenuSection({required super.label, this.iconName});

  /// Freedesktop icon-theme name shown beside the section when supported.
  final String? iconName;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final representation = PlatformMenuItem.serialize(this, delegate, getId);
    representation['isDivider'] = true;
    representation['enabled'] = false;
    if (iconName != null) {
      representation['iconName'] = iconName;
    }
    return <Map<String, Object?>>[representation];
  }
}

/// A leaf menu item with an explicit enabled state.
class LinuxMenuItem extends PlatformMenuItem {
  const LinuxMenuItem({
    required super.label,
    super.tooltip,
    super.shortcut,
    super.onSelected,
    super.onSelectedIntent,
    this.enabled = true,
    this.iconName,
  });

  /// Whether the desktop shell allows this item to be activated.
  final bool enabled;

  /// Freedesktop icon-theme name shown by desktop shells that support it.
  final String? iconName;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final representation = PlatformMenuItem.serialize(this, delegate, getId);
    representation['enabled'] =
        enabled && (onSelected != null || onSelectedIntent != null);
    if (iconName != null) {
      representation['iconName'] = iconName;
    }
    return <Map<String, Object?>>[representation];
  }
}

/// A menu item rendered with a checkbox.
class LinuxCheckMenuItem extends LinuxMenuItem {
  const LinuxCheckMenuItem({
    required super.label,
    required this.checked,
    super.tooltip,
    super.shortcut,
    super.onSelected,
    super.onSelectedIntent,
    super.enabled,
    super.iconName,
  });

  /// Whether the checkbox is checked.
  final bool checked;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final representation = super
        .toChannelRepresentation(delegate, getId: getId)
        .single;
    representation['toggleType'] = 'checkmark';
    representation['toggleState'] = checked ? 1 : 0;
    return <Map<String, Object?>>[representation];
  }
}

/// A menu item rendered with a radio button.
///
/// Radio grouping is controlled by application state: rebuild the menu with
/// exactly one item in a logical group having [selected] set to true.
class LinuxRadioMenuItem extends LinuxMenuItem {
  const LinuxRadioMenuItem({
    required super.label,
    required this.selected,
    super.tooltip,
    super.shortcut,
    super.onSelected,
    super.onSelectedIntent,
    super.enabled,
    super.iconName,
  });

  /// Whether this radio item is selected.
  final bool selected;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final representation = super
        .toChannelRepresentation(delegate, getId: getId)
        .single;
    representation['toggleType'] = 'radio';
    representation['toggleState'] = selected ? 1 : 0;
    return <Map<String, Object?>>[representation];
  }
}

/// A submenu with an explicit enabled state.
class LinuxSubmenu extends PlatformMenu {
  const LinuxSubmenu({
    required super.label,
    required super.menus,
    super.tooltip,
    super.onOpen,
    super.onClose,
    this.enabled = true,
    this.iconName,
  });

  /// Whether the desktop shell allows this submenu to be opened.
  final bool enabled;

  /// Freedesktop icon-theme name shown beside this submenu.
  final String? iconName;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final representation = PlatformMenu.serialize(this, delegate, getId);
    representation['enabled'] = enabled && menus.isNotEmpty;
    if (iconName != null) {
      representation['iconName'] = iconName;
    }
    return <Map<String, Object?>>[representation];
  }
}
