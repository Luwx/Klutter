import 'package:background_blur_linux/background_blur_linux.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class ZoomTestBinding extends AutomatedTestWidgetsFlutterBinding {
  double _zoom = 1;

  set zoom(double value) {
    _zoom = value;
    handleMetricsChanged();
  }

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    final view = renderView.flutterView;
    final ratio = view.devicePixelRatio * _zoom;
    final constraints = BoxConstraints.fromViewConstraints(
      view.physicalConstraints,
    );
    return ViewConfiguration(
      physicalConstraints: constraints,
      logicalConstraints: constraints / ratio,
      devicePixelRatio: ratio,
    );
  }
}

void main() {
  final binding = ZoomTestBinding();
  const channel = MethodChannel('background_blur_linux');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return 'ok';
    });
  });

  tearDown(() {
    binding.zoom = 1;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  List<Map<Object?, Object?>> region() =>
      (calls.lastWhere((call) => call.method == 'enable').arguments as List)
          .cast<Map<Object?, Object?>>();

  testWidgets('blur regions follow render zoom independently of display DPI', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final dpr in [1.0, 2.0]) {
      tester.view
        ..devicePixelRatio = dpr
        ..physicalSize = Size(800 * dpr, 600 * dpr);
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(devicePixelRatio: 9),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 30,
                  width: 100,
                  height: 60,
                  child: Blurred(
                    expand: EdgeInsets.fromLTRB(4, 2, 8, 6),
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      for (final zoom in [1.0, 1.2, 2.0, 0.8]) {
        binding.zoom = zoom;
        await tester.pump();
        await tester.idle();
        expect(region(), [
          {
            'x': (36 * zoom).round(),
            'y': (28 * zoom).round(),
            'w': (112 * zoom).round(),
            'h': (68 * zoom).round(),
          },
        ], reason: 'DPI $dpr, zoom $zoom');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      binding.zoom = 1;
    }
  });

  testWidgets(
    'rounded sidebar blur covers the full window after zoom and resize',
    (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(1600, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 180,
                child: Blurred(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  expand: EdgeInsets.only(right: 30),
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );

      for (final zoom in [1.0, 1.2, 2.0, 0.8]) {
        binding.zoom = zoom;
        await tester.pump();
        await tester.idle();
        expect(region(), [
          for (final rect in blurRegionForRoundedRect(
            (210 * zoom).round(),
            600,
            BorderRadius.circular(10 * zoom),
          ))
            {'x': rect.x, 'y': rect.y, 'w': rect.width, 'h': rect.height},
        ], reason: 'zoom $zoom');
      }

      tester.view.physicalSize = const Size(1600, 1600);
      await tester.pump();
      await tester.idle();
      expect(region(), [
        for (final rect in blurRegionForRoundedRect(
          168,
          800,
          BorderRadius.circular(8),
        ))
          {'x': rect.x, 'y': rect.y, 'w': rect.width, 'h': rect.height},
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(calls.last.method, 'disable');
    },
  );
}
