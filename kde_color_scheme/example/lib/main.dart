import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kde_color_scheme/kde_color_scheme.dart';

void main() {
  runApp(const TitlebarExampleApp());
}

class TitlebarExampleApp extends StatefulWidget {
  const TitlebarExampleApp({super.key});

  @override
  State<TitlebarExampleApp> createState() => _TitlebarExampleAppState();
}

class _TitlebarExampleAppState extends State<TitlebarExampleApp> {
  static const List<Color> _colors = <Color>[
    Color(0xFF1B5E20),
    Color(0xFF0D47A1),
    Color(0xFF4A148C),
    Color(0xFFB71C1C),
    Color(0xFFFFD54F),
    Color(0xFFECEFF1),
  ];

  Color? _selected;
  String _status = 'Using the system color scheme.';

  Color _foregroundFor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;

  Future<void> _select(Color color) async {
    setState(() => _selected = color);
    try {
      final applied = await KdeTitlebar.setTitlebarColors(
        background: color,
        foreground: _foregroundFor(color),
        inactiveBackground: Color.lerp(color, Colors.grey, 0.5),
        inactiveForeground: _foregroundFor(color).withValues(alpha: 0.6),
      );
      _setStatus(
        applied
            ? 'Title bar colors applied.'
            : 'This session does not support KWin decoration palettes.',
      );
    } on PlatformException catch (error) {
      _setStatus('Failed: ${error.code}');
    }
  }

  Future<void> _reset() async {
    setState(() => _selected = null);
    await KdeTitlebar.resetTitlebarColors();
    _setStatus('Using the system color scheme.');
  }

  void _setStatus(String status) {
    if (mounted) {
      setState(() => _status = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = _selected ?? Colors.blueGrey;
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: seed),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final color in _colors)
                    _Swatch(
                      color: color,
                      selected: color == _selected,
                      onTap: () => _select(color),
                    ),
                ],
              ),
              OutlinedButton(
                onPressed: _selected == null ? null : _reset,
                child: const Text('Reset to system colors'),
              ),
              Text(_status),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
