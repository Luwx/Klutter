import 'package:flutter/material.dart';
import 'package:background_blur_linux/background_blur_linux.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DemoShell(),
    );
  }
}

class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  // Master on/off for any blur.
  bool _blurEnabled = true;

  // Whole-window blur mode: the entire window is blurred and the content
  // background becomes 80% opaque so the blur shows through everywhere.
  bool _wholeWindow = false;

  // Per-card "punch" blur is active only when blur is on and we are not in
  // whole-window mode.
  bool get _cardPunch => _blurEnabled && !_wholeWindow;
  bool get _wholeActive => _blurEnabled && _wholeWindow;

  @override
  Widget build(BuildContext context) {
    // The Scaffold is transparent (the window surface is too, see
    // linux/runner/my_application.cc). The content area paints its own opaque
    // background *inside* the scrollable, in the same layer as the cards, so
    // Blurred(color:)'s BlendMode.src punch can clear it locally and reach the
    // window surface in one composite. With an opaque Scaffold the background
    // would sit in a separate layer below the scroll view and show through the
    // punched holes while scrolling.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Whole-window blur region. Inactive (disabled) unless that mode is
          // selected; it registers the full window as a single blur region.
          Positioned.fill(
            child: Blurred(
              disabled: !_wholeActive,
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BlurredSidebar(
                blurEnabled: _blurEnabled,
                wholeWindow: _wholeWindow,
                onBlurEnabledChanged: (v) => setState(() => _blurEnabled = v),
                onWholeWindowChanged: (v) => setState(() => _wholeWindow = v),
              ),
              Expanded(
                child: _ContentArea(
                  // 80% opaque in whole-window mode so the blur frosts through;
                  // fully opaque otherwise.
                  backgroundColor: _wholeActive
                      ? const Color(0xCC0D1117)
                      : const Color(0xFF0D1117),
                  cardsEnabled: _cardPunch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlurredSidebar extends StatelessWidget {
  const _BlurredSidebar({
    required this.blurEnabled,
    required this.wholeWindow,
    required this.onBlurEnabledChanged,
    required this.onWholeWindowChanged,
  });

  final bool blurEnabled;
  final bool wholeWindow;
  final ValueChanged<bool> onBlurEnabledChanged;
  final ValueChanged<bool> onWholeWindowChanged;

  @override
  Widget build(BuildContext context) {
    return Blurred(
      // Punch a transparent hole + apply a subtle tint so the sidebar reads as
      // a frosted panel. Disabled with the master toggle.
      disabled: !blurEnabled,
      color: const Color(0x14FFFFFF),
      child: Container(
        width: 220,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0x1AFFFFFF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'background_blur_linux',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(
                'Blurred sidebar demo',
                style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0x1AFFFFFF), height: 1),
            ),
            const SizedBox(height: 16),
            const _NavItem(icon: Icons.blur_on, label: 'Blur Types'),
            const _NavItem(
              icon: Icons.rounded_corner_rounded,
              label: 'Rounded',
            ),
            const _NavItem(icon: Icons.palette_outlined, label: 'Tint Color'),
            const _NavItem(icon: Icons.tune_rounded, label: 'Manual API'),
            const Spacer(),
            _SidebarSwitch(
              icon: Icons.power_settings_new_rounded,
              label: 'Enable blur',
              value: blurEnabled,
              onChanged: onBlurEnabledChanged,
            ),
            _SidebarSwitch(
              icon: Icons.fullscreen_rounded,
              label: 'Whole-window blur',
              value: wholeWindow,
              // Whole-window mode is meaningless while blur is off.
              onChanged: blurEnabled ? onWholeWindowChanged : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0x80FFFFFF)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Color(0xC0FFFFFF), fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _SidebarSwitch extends StatelessWidget {
  const _SidebarSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final fg = enabled ? const Color(0xC0FFFFFF) : const Color(0x55FFFFFF);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(icon, size: 18, color: fg),
      title: Text(label, style: TextStyle(color: fg, fontSize: 13)),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.backgroundColor,
    required this.cardsEnabled,
  });

  final Color backgroundColor;
  final bool cardsEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            // Make the content at least as tall as the viewport so the opaque
            // background fills it even when there is little to scroll.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            // The background is painted in the SAME layer as the cards, so the
            // Blurred punch clears it locally instead of revealing a separate
            // opaque layer underneath (which is what flickered while scrolling).
            child: ColoredBox(
              color: backgroundColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blur Types',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cardsEnabled
                          ? 'Each card punches a transparent hole through this '
                                'opaque background so KWin blur shows through.'
                          : 'Whole-window blur is on: the background is 80% '
                                'opaque so the blur frosts the entire window.',
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 1 - plain rect
                    _BlurCard(
                      title: 'Plain Rect Blur',
                      code: 'Blurred(color: Color(0x14FFFFFF))',
                      child: Blurred(
                        disabled: !cardsEnabled,
                        color: const Color(0x14FFFFFF),
                        child: const _CardBody(
                          icon: Icons.grid_view_rounded,
                          label: 'Plain rect - no border radius',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2 - rounded rect
                    _BlurCard(
                      title: 'Rounded Rect Blur',
                      code:
                          'Blurred(color: …, borderRadius: BorderRadius.circular(20))',
                      child: Blurred(
                        disabled: !cardsEnabled,
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0x14FFFFFF),
                        child: _CardBody(
                          icon: Icons.rounded_corner_rounded,
                          label: 'Scanline-approximated rounded corners',
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3 - custom tint colour
                    _BlurCard(
                      title: 'Custom Tint Color',
                      code:
                          'Blurred(color: Colors.blue.withValues(alpha: 0.12), borderRadius: …)',
                      child: Blurred(
                        disabled: !cardsEnabled,
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.blue.withValues(alpha: 0.12),
                        child: _CardBody(
                          icon: Icons.water_drop_outlined,
                          label: 'Blue tint over blur',
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlurCard extends StatelessWidget {
  const _BlurCard({
    required this.title,
    required this.code,
    required this.child,
  });

  final String title;
  final String code;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        code,
        style: const TextStyle(
          color: Color(0x66FFFFFF),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.icon, required this.label, this.borderRadius});

  final IconData icon;
  final String label;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x33FFFFFF)),
      borderRadius: borderRadius,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0x80FFFFFF), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Color(0xC0FFFFFF), fontSize: 13),
        ),
      ],
    ),
  );
}
