import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'section_studio_document.dart';

const _sectionStudioTypeGroup = XTypeGroup(
  label: 'BA Planner Section Studio JSON',
  extensions: <String>['json'],
);

class LoadedSectionStudioFile {
  const LoadedSectionStudioFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

abstract interface class SectionStudioFileService {
  Future<LoadedSectionStudioFile?> open();

  Future<String?> save({
    required String suggestedName,
    required String contents,
  });
}

class NativeSectionStudioFileService implements SectionStudioFileService {
  const NativeSectionStudioFileService();

  @override
  Future<LoadedSectionStudioFile?> open() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_sectionStudioTypeGroup],
    );
    if (file == null) return null;
    return LoadedSectionStudioFile(
      name: file.name,
      contents: await file.readAsString(),
    );
  }

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_sectionStudioTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(contents)),
      mimeType: 'application/json',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}

String defaultSectionStudioFileName() =>
    'section-template.$sectionStudioDocumentExtension';
