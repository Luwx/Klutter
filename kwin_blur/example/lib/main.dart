import 'package:flutter/material.dart';
import 'package:kwin_blur/kwin_blur.dart';

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


class DemoShell extends StatelessWidget {
  const DemoShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Intentionally opaque - individual Blurred(color: ...) widgets punch
      // their own transparent holes through this background.
      backgroundColor: const Color(0xFF0D1117),
      // body: Stack(
      //   children: [
      //     const Positioned.fill(child: _AppBackground()),
      //     Row(
      //       crossAxisAlignment: CrossAxisAlignment.stretch,
      //       children: const [
      //         _BlurredSidebar(),
      //         Expanded(child: _ContentArea()),
      //       ],
      //     ),
      //   ],
      // ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _BlurredSidebar(),
          Expanded(child: _ContentArea()),
        ],
      ),
    );
  }
}


class _BlurredSidebar extends StatelessWidget {
  const _BlurredSidebar();

  @override
  Widget build(BuildContext context) {
    return Blurred(
      // Punch a transparent hole + apply a subtle tint.
      // The Scaffold background is opaque, without this color param the blur
      // would not be visible.
      color: const Color(0x0DFFFFFF),
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
                'kwin_blur',
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
            const _SidebarNote(),
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

class _SidebarNote extends StatelessWidget {
  const _SidebarNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: const Text(
        'Scaffold is opaque.\nBlurred(color: …) punches\na transparent hole so\nKWin blur shows through.',
        style: TextStyle(color: Color(0x80FFFFFF), fontSize: 10, height: 1.6),
      ),
    ),
  );
}


class _ContentArea extends StatelessWidget {
  const _ContentArea();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          const Text(
            'Scaffold background is opaque. The color parameter punches a '
            'transparent hole so KWin blur shows through.',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // 1 - plain rect
          _BlurCard(
            title: 'Plain Rect Blur',
            code: "Blurred(color: Color(0x14FFFFFF))",
            child: Blurred(
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
            code: "Blurred(color: …, borderRadius: BorderRadius.circular(20))",
            child: Blurred(
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
                "Blurred(color: Colors.blue.withValues(alpha: 0.12), borderRadius: …)",
            child: Blurred(
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

          // 4 - disabled
          _BlurCard(
            title: 'Disabled',
            code: "Blurred(disabled: true, color: …)",
            child: Blurred(
              disabled: true,
              borderRadius: BorderRadius.circular(16),
              color: const Color(0x14FFFFFF),
              child: _CardBody(
                icon: Icons.blur_off,
                label: 'disabled: true - no hole punched, no blur',
                borderRadius: BorderRadius.circular(16),
                dimmed: true,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 5 - no color (legacy, requires transparent scaffold)
          _BlurCard(
            title: 'No Color (Legacy Mode)',
            code: "Blurred() - requires transparent Scaffold",
            child: Blurred(
              borderRadius: BorderRadius.circular(16),
              child: _CardBody(
                icon: Icons.layers_outlined,
                label: 'No punch hole - needs transparent app window',
                borderRadius: BorderRadius.circular(16),
                background: const Color(0x22FFFFFF),
              ),
            ),
          ),
        ],
      ),
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
  const _CardBody({
    required this.icon,
    required this.label,
    this.borderRadius,
    this.dimmed = false,
    this.background,
  });

  final IconData icon;
  final String label;
  final BorderRadius? borderRadius;
  final bool dimmed;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: background,
      border: Border.all(
        color: dimmed ? const Color(0x20FFFFFF) : const Color(0x33FFFFFF),
      ),
      borderRadius: borderRadius,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: dimmed ? const Color(0x40FFFFFF) : const Color(0x80FFFFFF),
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: dimmed ? const Color(0x40FFFFFF) : const Color(0xC0FFFFFF),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
