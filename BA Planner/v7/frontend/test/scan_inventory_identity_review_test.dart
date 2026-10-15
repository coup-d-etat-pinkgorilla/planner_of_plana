import 'dart:convert';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/widgets/scan_inventory_identity_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const identity = 'Item_Icon_SkillBook_Abydos_0';
  final slot = ScannerUnresolvedSlot(
    slot: 7,
    profile: InventoryScanProfile.techNotes,
    width: 1280,
    height: 720,
    cropPng: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==',
    ),
    candidates: const [
      ScannerIdentitySuggestion(identity: identity, score: 0.81),
    ],
  );
  const catalog = [
    InventoryCatalogEntry(
      resourceKey: identity,
      itemId: identity,
      displayName: 'Abydos 기술 노트 T1',
      category: 'tech_notes',
      profileId: 'tech_notes',
      orderIndex: 0,
      zeroFillAllowed: true,
      school: 'Abydos',
      family: 'tech_notes',
      tier: 1,
    ),
    InventoryCatalogEntry(
      resourceKey: 'Item_Icon_SkillBook_Abydos_1',
      itemId: 'Item_Icon_SkillBook_Abydos_1',
      displayName: 'Abydos 기술 노트 T2',
      category: 'tech_notes',
      profileId: 'tech_notes',
      orderIndex: 1,
      zeroFillAllowed: true,
      school: 'Abydos',
      family: 'tech_notes',
      tier: 2,
    ),
  ];

  testWidgets(
    'candidate selection exposes session-only and persistent actions',
    (tester) async {
      final calls = <(String, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScanInventoryIdentityReview(
                slots: [slot],
                catalog: catalog,
                onAssign: (_, identity, persist) async {
                  calls.add((identity, persist));
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('확인이 필요한 새 아이템'), findsOneWidget);
      expect(find.textContaining('Abydos 기술 노트 T1 81%'), findsOneWidget);
      await tester.tap(find.byType(ChoiceChip));
      await tester.pump();
      await tester.tap(find.text('이번 세션만'));
      await tester.pump();
      expect(calls, [(identity, false)]);
    },
  );

  testWidgets('catalog search can select a profile-scoped identity', (
    tester,
  ) async {
    final calls = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanInventoryIdentityReview(
            slots: [slot],
            catalog: catalog,
            onAssign: (_, identity, persist) async {
              calls.add((identity, persist));
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'T2');
    await tester.pump();
    await tester.tap(find.text('Abydos 기술 노트 T2'));
    await tester.pump();
    await tester.tap(find.text('영구 승인'));
    await tester.pump();
    expect(calls, [('Item_Icon_SkillBook_Abydos_1', true)]);
  });
}
