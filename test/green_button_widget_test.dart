import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/automation_store.dart';
import 'package:verdi/features/automation_screen.dart';

class _UtilityPicker extends FilePicker {
  _UtilityPicker(this.xml);
  String xml;
  List<String>? requestedExtensions;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    requestedExtensions = allowedExtensions;
    final bytes = Uint8List.fromList(utf8.encode(xml));
    return FilePickerResult([
      PlatformFile(name: 'utility.xml', size: bytes.length, bytes: bytes),
    ]);
  }
}

void main() {
  testWidgets(
    'real XML picker queues user intervals, review confirms, reimport skips',
    (tester) async {
      final fixture = File('examples/green-button-electricity.xml')
          .readAsStringSync();
      final picker = _UtilityPicker(fixture);
      FilePicker.platform = picker;
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final activities = ActivityStore(preferences);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutomationScreen(activities: activities, onChanged: () {}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Home');
      await tester.ensureVisible(find.text('Choose Green Button XML'));
      await tester.tap(find.text('Choose Green Button XML'));
      await tester.pumpAndSettle();
      expect(picker.requestedExtensions, ['xml']);
      expect(AutomationStore(preferences).load().pending, hasLength(2));
      expect(activities.load(), isEmpty);
      await tester.ensureVisible(find.text('Confirm activity').first);
      await tester.tap(find.text('Confirm activity').first);
      await tester.pumpAndSettle();
      expect(activities.load(), hasLength(1));
      expect(activities.load().single.source, 'utility-green-button');
      await tester.ensureVisible(find.text('Choose Green Button XML'));
      await tester.tap(find.text('Choose Green Button XML'));
      await tester.pumpAndSettle();
      expect(AutomationStore(preferences).load().pending, hasLength(1));
      picker.xml = '<not-green-button/>';
      await tester.tap(find.text('Choose Green Button XML'));
      await tester.pumpAndSettle();
      expect(AutomationStore(preferences).load().pending, hasLength(1));
      expect(activities.load(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
