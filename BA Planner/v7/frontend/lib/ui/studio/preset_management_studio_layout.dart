import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection of
/// `release/section-preset-management.ba-section-studio.json`.
final SectionStudioDocument presetManagementStudioDocument =
    SectionStudioDocument(
      headerRows: 12,
      viewport: 'standard',
      showGrid: true,
      showSafeArea: true,
      selectedElementId: 'element-2',
      placementGap: 0,
      elements: const [
        SectionCanvasElement(
          id: 'element-1',
          label: '프리셋 목록',
          rect: SectionGridRect(0, 2, 18, 92),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.trapezoid,
            face: SectionAttachmentFace.left,
            faceSpan: 96,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: 'element-2',
          label: '프리셋 생성',
          rect: SectionGridRect(21, 2, 21, 92),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.parallelogram,
            face: SectionAttachmentFace.bottom,
            faceSpan: 96,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: 'element-3',
          label: '미저장 확인',
          rect: SectionGridRect(53, 42, 20, 12),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.parallelogram,
            face: SectionAttachmentFace.bottom,
            faceSpan: 96,
            height: 96,
          ),
        ),
      ],
    );
