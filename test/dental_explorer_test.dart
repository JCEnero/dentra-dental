import 'dart:ui' as ui;

import 'package:dentra_mobile/features/dental_explorer/data/tooth_catalog.dart';
import 'package:dentra_mobile/features/dental_explorer/data/tooth_content.dart';
import 'package:dentra_mobile/features/dental_explorer/geometry/dentition_builder.dart';
import 'package:dentra_mobile/features/dental_explorer/geometry/tooth_geometry.dart';
import 'package:dentra_mobile/features/dental_explorer/rendering/dentition_renderer.dart';
import 'package:dentra_mobile/features/dental_explorer/rendering/orbit_camera.dart';
import 'package:dentra_mobile/features/dental_explorer/screens/dental_explorer_screen.dart';
import 'package:dentra_mobile/features/dental_explorer/state/explorer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('FDI catalog', () {
    test('has 32 unique teeth with valid FDI numbers', () {
      final numbers = ToothCatalog.all.map((t) => t.fdi).toSet();
      expect(numbers.length, 32);
      for (final t in ToothCatalog.all) {
        expect(t.quadrant, inInclusiveRange(1, 4));
        expect(t.position, inInclusiveRange(1, 8));
        expect(ToothCatalog.byIndex(t.index), same(t));
      }
    });

    test('names follow the quadrant and position', () {
      expect(ToothCatalog.byFdi(11)!.name, 'Upper right central incisor');
      expect(ToothCatalog.byFdi(23)!.name, 'Upper left canine');
      expect(ToothCatalog.byFdi(36)!.name, 'Lower left first molar');
      expect(ToothCatalog.byFdi(45)!.name, 'Lower right second premolar');
      expect(ToothCatalog.byFdi(48)!.type, ToothType.molar);
      expect(ToothCatalog.byFdi(19), isNull);
      expect(ToothCatalog.byFdi(51), isNull);
    });

    test('type counts match the adult dentition', () {
      expect(ToothCatalog.countOf(ToothType.incisor), 8);
      expect(ToothCatalog.countOf(ToothType.canine), 4);
      expect(ToothCatalog.countOf(ToothType.premolar), 8);
      expect(ToothCatalog.countOf(ToothType.molar), 12);
    });

    test('chart rows read as when facing the patient', () {
      expect(ToothCatalog.upperChartRow.map((t) => t.fdi),
          [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28]);
      expect(ToothCatalog.lowerChartRow.map((t) => t.fdi),
          [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38]);
    });

    test('every tooth has complete educational content', () {
      for (final t in ToothCatalog.all) {
        final type = ToothContent.forType(t.type);
        final pos = ToothContent.forTooth(t);
        expect(type.function, isNotEmpty);
        expect(type.concerns, isNotEmpty);
        expect(type.hygiene, isNotEmpty);
        expect(pos.anatomy, isNotEmpty);
        expect(pos.eruption, isNotEmpty);
        expect(pos.roots, isNotEmpty);
        expect(pos.fact, isNotEmpty);
      }
    });
  });

  group('3D model', () {
    late DentitionModel model;
    setUpAll(() => model = buildDentition(MeshDetail.low));

    test('every tooth and both gums have geometry', () {
      final owners = model.mesh.triOwner.toSet();
      for (var i = 0; i < kOwnerCount; i++) {
        expect(owners, contains(i), reason: 'owner $i has no triangles');
      }
      expect(model.anchors, hasLength(32));
    });

    test('upper teeth sit above lower teeth, right side at -x', () {
      final upper = model.anchors[ToothCatalog.byFdi(16)!.index].crownCenter;
      final lower = model.anchors[ToothCatalog.byFdi(46)!.index].crownCenter;
      expect(upper.y, greaterThan(lower.y));
      expect(upper.x, lessThan(0));
      expect(model.anchors[ToothCatalog.byFdi(26)!.index].crownCenter.x,
          greaterThan(0));
    });

    test('a tap on a tooth resolves to that tooth', () {
      final renderer = DentitionRenderer(model);
      const size = Size(400, 400);
      final recorder = ui.PictureRecorder();
      final pose = CameraPose(
        yaw: 0,
        pitch: 0.05,
        distance: renderer.fitDistance,
        target: model.center,
      );
      renderer.paint(Canvas(recorder), size, pose, SceneStyle());
      recorder.endRecording().dispose();

      for (final fdi in [11, 21, 31, 43]) {
        final tooth = ToothCatalog.byFdi(fdi)!;
        final (point, _) =
            renderer.project(model.anchors[tooth.index].crownCenter)!;
        expect(renderer.hitTest(point), tooth.index, reason: 'tooth $fdi');
      }
      // Empty space above the model hits nothing.
      expect(renderer.hitTest(const Offset(200, 2)), isNull);
    });
  });

  group('ExplorerController', () {
    test('Upper and Lower hide the other arch and clear its selection', () {
      final c = ExplorerController();
      c.select(ToothCatalog.byFdi(36));
      c.setRegion(ExplorerRegion.upper);
      expect(c.selected, isNull);
      expect(c.isVisible(ToothCatalog.byFdi(36)!), isFalse);
      expect(c.isVisible(ToothCatalog.byFdi(16)!), isTrue);
    });

    test('selecting a hidden tooth shows every tooth again', () {
      final c = ExplorerController()..setRegion(ExplorerRegion.upper);
      c.select(ToothCatalog.byFdi(41));
      expect(c.region, ExplorerRegion.all);
      expect(c.selected?.fdi, 41);
    });

    test('front and back regions split by tooth type', () {
      expect(ExplorerRegion.front.includes(ToothCatalog.byFdi(13)!), isTrue);
      expect(ExplorerRegion.front.includes(ToothCatalog.byFdi(14)!), isFalse);
      expect(ExplorerRegion.back.includes(ToothCatalog.byFdi(47)!), isTrue);
    });

    test('previous and next walk the chart and wrap around', () {
      final c = ExplorerController();
      expect(c.neighbour(ToothCatalog.byFdi(11)!, 1).fdi, 21);
      expect(c.neighbour(ToothCatalog.byFdi(18)!, -1).fdi, 38);
      expect(c.neighbour(ToothCatalog.byFdi(38)!, 1).fdi, 18);
    });
  });

  group('DentalExplorerScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final assets = buildDentitionAssets(null);
      await tester.pumpWidget(MaterialApp(
        home: DentalExplorerScreen(loadModel: () async => assets),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the 3D viewer, controls and tooth chart',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('Dental Explorer'), findsOneWidget);
      expect(find.text('Tooth chart'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Reset view'), findsOneWidget);
      // Numbers are off until the user turns them on.
      final numbers = tester.widget<Semantics>(find
          .ancestor(
              of: find.byTooltip('Tooth numbers'),
              matching: find.byType(Semantics))
          .first);
      expect(numbers.properties.toggled, isFalse);
      expect(find.bySemanticsLabel(RegExp(r'^Tooth 11,')), findsOneWidget);
    });

    testWidgets('choosing a tooth opens its details; closing returns',
        (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Tooth 11,')));
      await tester.pumpAndSettle();

      expect(find.text('Upper right central incisor'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('7–8 years'), 120,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('7–8 years'), findsOneWidget);
      expect(find.text('Tooth chart'), findsNothing);

      await tester.tap(find.text('Tooth 21'));
      await tester.pumpAndSettle();
      expect(find.text('Upper left central incisor'), findsOneWidget);

      expect(find.text('Care tips'), findsNothing);
      await tester.tap(find.text('Care'));
      await tester.pumpAndSettle();
      expect(find.text('Common concerns'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Care tips'), 120,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Care tips'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Tooth chart'), findsOneWidget);
    });

    testWidgets('no overflow on a small screen with large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final assets = buildDentitionAssets(null);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          home: DentalExplorerScreen(loadModel: () async => assets),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Tooth 11,')));
      await tester.pumpAndSettle();
      for (final tab in ['Anatomy', 'Care']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed model build offers a retry', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var calls = 0;
      final assets = buildDentitionAssets(null);
      await tester.pumpWidget(MaterialApp(
        home: DentalExplorerScreen(loadModel: () async {
          calls++;
          if (calls == 1) throw StateError('boom');
          return assets;
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't build the 3D model"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't build the 3D model"), findsNothing);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
    });
  });
}
