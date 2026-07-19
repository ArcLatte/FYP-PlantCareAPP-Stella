import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';

class NoteEditResult {
  final ActivityEvent? saved;
  final bool deleted;
  const NoteEditResult.saved(this.saved) : deleted = false;
  const NoteEditResult.deleted() : saved = null, deleted = true;
}

/// One continuous WYSIWYG note page. Images are Quill embeds inside the same
/// document as the surrounding text, rather than separate attachment fields.
class NoteEditorScreen extends StatefulWidget {
  final int plantId;
  final String plantName;
  final ActivityEvent? existing;

  const NoteEditorScreen({
    super.key,
    required this.plantId,
    required this.plantName,
    this.existing,
  });

  bool get isEditing => existing != null;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.existing?.noteTitle ?? '',
  );
  late final quill.QuillController _controller;
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScroll = ScrollController();
  late String _initialDocument;
  late String _initialTitle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final document = _initialQuillDocument();
    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _initialDocument = jsonEncode(document.toDelta().toJson());
    _initialTitle = _titleController.text.trim();
  }

  quill.Document _initialQuillDocument() {
    final stored = widget.existing?.noteDocument;
    if (stored != null && stored.isNotEmpty) {
      try {
        return quill.Document.fromJson(stored);
      } catch (_) {
        // Fall through to the legacy-note conversion below.
      }
    }
    final document = quill.Document();
    final text = widget.existing?.note ?? '';
    if (text.isNotEmpty) document.insert(0, '$text\n');
    for (final image in widget.existing?.noteImages ?? const []) {
      document.insert(document.length - 1, quill.BlockEmbed.image(image.url));
      document.insert(document.length - 1, '\n');
    }
    return document;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  List<dynamic> get _delta => _controller.document.toDelta().toJson();

  Iterable<String> get _imageSources sync* {
    for (final operation in _delta) {
      if (operation is! Map) continue;
      final inserted = operation['insert'];
      if (inserted is Map && inserted['image'] is String) {
        yield inserted['image'] as String;
      }
    }
  }

  List<String> get _localImagePaths => _imageSources
      .where(
        (source) =>
            !source.startsWith('http://') && !source.startsWith('https://'),
      )
      .where((source) => File(source).existsSync())
      .toList();

  bool get _dirty =>
      _titleController.text.trim() != _initialTitle ||
      jsonEncode(_delta) != _initialDocument;

  Future<void> _pickPhoto() async {
    if (_imageSources.length >= 6) {
      AppSnackBar.error(context, 'A note can contain up to 6 photos.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photos'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final selected = source == ImageSource.camera
          ? <XFile>[
              if (await picker.pickImage(
                    source: source,
                    imageQuality: 90,
                    maxWidth: 1800,
                  )
                  case final XFile image)
                image,
            ]
          : await picker.pickMultiImage(imageQuality: 90, maxWidth: 1800);
      final available = 6 - _imageSources.length;
      for (final image in selected.take(available)) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          maxWidth: 1600,
          maxHeight: 1600,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 88,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop note photo',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: AppColors.primary,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: 'Crop note photo'),
          ],
        );
        if (cropped != null) _insertImage(cropped.path);
      }
    } catch (error) {
      if (mounted) {
        AppSnackBar.error(context, error, fallback: 'Could not add the photo.');
      }
    }
  }

  void _insertImage(String path) {
    final selection = _controller.selection;
    final index = selection.baseOffset < 0
        ? _controller.document.length - 1
        : selection.baseOffset;
    _controller.replaceText(
      index,
      selection.isCollapsed ? 0 : selection.end - selection.start,
      quill.BlockEmbed.image(path),
      TextSelection.collapsed(offset: index + 1),
    );
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
    _editorFocus.requestFocus();
  }

  String _plainText() =>
      _controller.document.toPlainText().replaceAll('\uFFFC', '').trim();

  Set<int> _removedImageIds() {
    final remaining = _imageSources.toSet();
    return {
      for (final image in widget.existing?.noteImages ?? const [])
        if (!image.legacy && image.id != null && !remaining.contains(image.url))
          image.id!,
    };
  }

  bool get _removeLegacyPhoto {
    final remaining = _imageSources.toSet();
    return (widget.existing?.noteImages ?? const []).any(
      (image) => image.legacy && !remaining.contains(image.url),
    );
  }

  Future<NoteEditResult?> _save() async {
    final title = _titleController.text.trim();
    final text = _plainText();
    if (title.isEmpty && text.isEmpty && _imageSources.isEmpty) {
      AppSnackBar.error(context, 'Write something or add a photo.');
      return null;
    }
    setState(() => _busy = true);
    final paths = _localImagePaths;
    try {
      final event = widget.isEditing
          ? await ApiService.updatePlantNote(
              widget.plantId,
              widget.existing!.careLogId!,
              text,
              title: title,
              photos: paths.map(File.new).toList(),
              photoTokens: paths,
              document: _delta,
              removeImageIds: _removedImageIds(),
              removeLegacyPhoto: _removeLegacyPhoto,
            )
          : await ApiService.addPlantNote(
              widget.plantId,
              text,
              title: title,
              photos: paths.map(File.new).toList(),
              photoTokens: paths,
              document: _delta,
            );
      if (!mounted) return null;
      setState(() => _busy = false);
      return NoteEditResult.saved(event);
    } catch (error) {
      if (!mounted) return null;
      setState(() => _busy = false);
      AppSnackBar.error(context, error, fallback: 'Could not save the note.');
      return null;
    }
  }

  Future<void> _saveAndClose() async {
    final result = await _save();
    if (result != null && mounted) Navigator.pop(context, result);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ApiService.deletePlantNote(
      widget.plantId,
      widget.existing!.careLogId!,
    );
    if (mounted) Navigator.pop(context, const NoteEditResult.deleted());
  }

  Future<void> _handleBack() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('You have unsaved changes to this note.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || save == null) return;
    if (!save) {
      Navigator.pop(context);
    } else {
      await _saveAndClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit note' : 'New note'),
          actions: [
            if (widget.isEditing)
              IconButton(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error,
              ),
            TextButton(
              onPressed: _busy ? null : _saveAndClose,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Expanded(
                child: quill.QuillEditor(
                  controller: _controller,
                  focusNode: _editorFocus,
                  scrollController: _editorScroll,
                  config: quill.QuillEditorConfig(
                    placeholder: 'Start writing about ${widget.plantName}...',
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: quill.QuillSimpleToolbar(
                    controller: _controller,
                    config: quill.QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showUnderLineButton: false,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showClearFormat: false,
                      showHeaderStyle: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      customButtons: [
                        quill.QuillToolbarCustomButtonOptions(
                          icon: const Icon(Icons.image_outlined),
                          tooltip: 'Insert photo',
                          onPressed: _pickPhoto,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
