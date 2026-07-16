import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';

/// What the [NoteEditorScreen] hands back to the journal list: the saved note
/// (created or updated), or a flag that it was deleted. Null pop = no change.
class NoteEditResult {
  final ActivityEvent? saved;
  final bool deleted;
  const NoteEditResult.saved(this.saved) : deleted = false;
  const NoteEditResult.deleted() : saved = null, deleted = true;
}

/// A full-page note editor styled like a plain notes app. Tapping a note opens
/// it directly here (no separate viewer): the title and body are editable, the
/// photo is integrated inline, and a bottom toolbar adds a photo or a bullet.
/// Bullets render immediately (the marker is "• "), and on exit with unsaved
/// changes the user is asked to save or discard.
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
  String? get initialTitle => existing?.noteTitle;
  String? get initialText => existing?.note;
  List<NoteImageAttachment> get existingImages =>
      existing?.noteImages ?? const [];

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final _MarkdownEditingController _bodyCtrl = _MarkdownEditingController(
    text: widget.initialText ?? '',
  );
  final FocusNode _bodyFocus = FocusNode();
  late String _previousBody = widget.initialText ?? '';

  final List<File> _newPhotos = [];
  final Set<int> _removedImageIds = {};
  bool _removeLegacyPhoto = false;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  List<NoteImageAttachment> get _visibleExistingImages => widget.existingImages
      .where(
        (image) => image.legacy
            ? !_removeLegacyPhoto
            : !_removedImageIds.contains(image.id),
      )
      .toList();

  bool get _hasPhoto =>
      _newPhotos.isNotEmpty || _visibleExistingImages.isNotEmpty;

  bool _isDirty() {
    final titleChanged =
        _titleCtrl.text.trim() != (widget.initialTitle ?? '').trim();
    final bodyChanged =
        _bodyCtrl.text.trimRight() != (widget.initialText ?? '').trimRight();
    final photoChanged =
        _newPhotos.isNotEmpty ||
        _removedImageIds.isNotEmpty ||
        _removeLegacyPhoto;
    return titleChanged || bodyChanged || photoChanged;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<_NotePhotoSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Take photo'),
                subtitle: const Text('Take and crop one photo'),
                onTap: () =>
                    Navigator.pop(sheetContext, _NotePhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Choose photos'),
                subtitle: const Text('Select and crop multiple photos'),
                onTap: () =>
                    Navigator.pop(sheetContext, _NotePhotoSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final available = 6 - _visibleExistingImages.length - _newPhotos.length;
    if (available <= 0) {
      AppSnackBar.error(context, 'A note can contain up to 6 photos.');
      return;
    }

    try {
      final picker = ImagePicker();
      final List<XFile> selected;
      if (source == _NotePhotoSource.camera) {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 1800,
        );
        selected = photo == null ? [] : [photo];
      } else {
        selected = await picker.pickMultiImage(
          imageQuality: 90,
          maxWidth: 1800,
        );
      }
      if (!mounted || selected.isEmpty) return;
      if (selected.length > available) {
        AppSnackBar.error(
          context,
          'Only $available more photo${available == 1 ? '' : 's'} can be added.',
        );
      }
      for (final selectedPhoto in selected.take(available)) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: selectedPhoto.path,
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
              aspectRatioPresets: const [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            IOSUiSettings(
              title: 'Crop note photo',
              aspectRatioPresets: const [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
          ],
        );
        if (cropped != null && mounted) {
          setState(() => _newPhotos.add(File(cropped.path)));
        }
      }
    } catch (error) {
      if (mounted) {
        AppSnackBar.error(
          context,
          error,
          fallback: 'Could not add those photos. Please try again.',
        );
      }
    }
  }

  /// Saves the note via the API and returns the result, or null if there's
  /// nothing to save / the request failed.
  Future<NoteEditResult?> _performSave() async {
    final title = _titleCtrl.text.trim();
    final text = _bodyCtrl.text.trimRight();
    if (title.isEmpty && text.isEmpty && !_hasPhoto) {
      AppSnackBar.error(context, 'Write something or add a photo.');
      return null;
    }
    setState(() => _busy = true);
    try {
      final ActivityEvent event;
      if (widget.isEditing) {
        event = await ApiService.updatePlantNote(
          widget.plantId,
          widget.existing!.careLogId!,
          text,
          title: title,
          photos: _newPhotos,
          removeImageIds: _removedImageIds,
          removeLegacyPhoto: _removeLegacyPhoto,
        );
      } else {
        event = await ApiService.addPlantNote(
          widget.plantId,
          text,
          title: title,
          photos: _newPhotos,
        );
      }
      if (!mounted) return null;
      setState(() => _busy = false);
      return NoteEditResult.saved(event);
    } catch (e) {
      if (!mounted) return null;
      setState(() => _busy = false);
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not save the note. Please try again.',
      );
      return null;
    }
  }

  Future<void> _onSavePressed() async {
    final res = await _performSave();
    if (res == null || !mounted) return;
    Navigator.pop(context, res);
  }

  Future<void> _delete() async {
    if (widget.existing?.careLogId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Delete note',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This note will be removed permanently.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.deletePlantNote(
        widget.plantId,
        widget.existing!.careLogId!,
      );
      if (!mounted) return;
      Navigator.pop(context, const NoteEditResult.deleted());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not delete the note. Please try again.',
      );
    }
  }

  /// Back handler: if there are unsaved changes, ask to save or discard.
  Future<void> _handleBack() async {
    if (!_isDirty()) {
      Navigator.pop(context, null);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Save changes?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'You have unsaved changes to this note.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              'Keep editing',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    if (choice == 'discard') {
      Navigator.pop(context, null);
      return;
    }
    final res = await _performSave();
    if (res == null || !mounted) return;
    Navigator.pop(context, res);
  }

  /// Inserts "• " at the start of the current line (or focuses the body if the
  /// line is already bulleted).
  void _insertBullet() {
    final text = _bodyCtrl.text;
    var cursor = _bodyCtrl.selection.baseOffset;
    if (cursor < 0) cursor = text.length;
    final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    if (!RegExp(r'^\s*(?:•|[-*])\s').hasMatch(text.substring(lineStart))) {
      final next =
          '${text.substring(0, lineStart)}• ${text.substring(lineStart)}';
      _bodyCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor + 2),
      );
      _previousBody = next;
    }
    _bodyFocus.requestFocus();
  }

  void _toggleInlineFormat(String marker) {
    final text = _bodyCtrl.text;
    var selection = _bodyCtrl.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    final start = selection.start;
    final end = selection.end;
    final markerLength = marker.length;
    final isWrapped =
        start >= markerLength &&
        end + markerLength <= text.length &&
        text.substring(start - markerLength, start) == marker &&
        text.substring(end, end + markerLength) == marker;

    if (isWrapped) {
      final next =
          text.substring(0, start - markerLength) +
          text.substring(start, end) +
          text.substring(end + markerLength);
      _bodyCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: start - markerLength,
          extentOffset: end - markerLength,
        ),
      );
      _previousBody = next;
    } else {
      final selected = text.substring(start, end);
      final next =
          text.substring(0, start) +
          marker +
          selected +
          marker +
          text.substring(end);
      final innerStart = start + markerLength;
      _bodyCtrl.value = TextEditingValue(
        text: next,
        selection: selected.isEmpty
            ? TextSelection.collapsed(offset: innerStart)
            : TextSelection(
                baseOffset: innerStart,
                extentOffset: innerStart + selected.length,
              ),
      );
      _previousBody = next;
    }
    _bodyFocus.requestFocus();
  }

  /// Live bullet handling: continue the list on Enter, end it on an empty
  /// bullet, and convert a freshly typed "- " / "* " into "• " immediately.
  void _onBodyChanged(String value) {
    if (value.length == _previousBody.length + 1) {
      final cursor = _bodyCtrl.selection.baseOffset;
      if (cursor > 0 && cursor <= value.length) {
        final ch = value[cursor - 1];
        if (ch == '\n') {
          final newlineIndex = cursor - 1;
          final from = newlineIndex - 1;
          final prevNl = from < 0 ? -1 : value.lastIndexOf('\n', from);
          final lineStart = prevNl + 1;
          final line = value.substring(lineStart, newlineIndex);
          final m = RegExp(r'^(\s*)(?:•|[-*])\s+(.*)$').firstMatch(line);
          if (m != null) {
            if (m.group(2)!.trim().isNotEmpty) {
              final next =
                  '${value.substring(0, cursor)}• ${value.substring(cursor)}';
              _setBody(next, cursor + 2);
              return;
            }
            final next =
                value.substring(0, lineStart) + value.substring(cursor);
            _setBody(next, lineStart);
            return;
          }
        } else if (ch == ' ') {
          final from = cursor - 2 < 0
              ? -1
              : value.lastIndexOf('\n', cursor - 2);
          final lineStart = from + 1;
          final segment = value.substring(lineStart, cursor);
          if (segment == '- ' || segment == '* ') {
            final next =
                '${value.substring(0, lineStart)}• ${value.substring(cursor)}';
            _setBody(next, lineStart + 2);
            return;
          }
        }
      }
    }
    _previousBody = value;
  }

  void _setBody(String text, int cursor) {
    _bodyCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _previousBody = text;
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
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(widget.isEditing ? 'Edit note' : 'New note'),
          actions: [
            if (widget.isEditing)
              IconButton(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error,
                tooltip: 'Delete note',
              ),
            TextButton(
              onPressed: _busy ? null : _onSavePressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      autofocus: !widget.isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      decoration: _bareInput(
                        'Title',
                        const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bodyCtrl,
                      focusNode: _bodyFocus,
                      onChanged: _onBodyChanged,
                      minLines: 5,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        height: 1.5,
                      ),
                      decoration: _bareInput(
                        'Start writing about ${widget.plantName}…',
                        const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 17,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (_hasPhoto) ...[
                      const SizedBox(height: 18),
                      _buildInlinePhotos(),
                    ],
                  ],
                ),
              ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  /// A borderless, unfilled input decoration so the fields read like plain text.
  InputDecoration _bareInput(String hint, TextStyle hintStyle) {
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
    );
  }

  Widget _buildInlinePhotos() {
    final existing = _visibleExistingImages;
    final itemCount = existing.length + _newPhotos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              '$itemCount photo${itemCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final isExisting = index < existing.length;
            final existingImage = isExisting ? existing[index] : null;
            final newIndex = index - existing.length;
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: isExisting
                      ? CachedNetworkImage(
                          imageUrl: existingImage!.url,
                          fit: BoxFit.cover,
                          memCacheWidth: 700,
                        )
                      : Image.file(_newPhotos[newIndex], fit: BoxFit.cover),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() {
                        if (isExisting) {
                          if (existingImage!.legacy) {
                            _removeLegacyPhoto = true;
                          } else if (existingImage.id != null) {
                            _removedImageIds.add(existingImage.id!);
                          }
                        } else {
                          _newPhotos.removeAt(newIndex);
                        }
                      }),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ToolButton(
              icon: Icons.image_outlined,
              label: 'Photo',
              onTap: _pickPhoto,
            ),
            _ToolButton(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Bullet',
              onTap: _insertBullet,
            ),
            _ToolButton(
              icon: Icons.format_bold_rounded,
              label: 'Bold',
              onTap: () => _toggleInlineFormat('**'),
            ),
            _ToolButton(
              icon: Icons.format_italic_rounded,
              label: 'Italic',
              onTap: () => _toggleInlineFormat('_'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotePhotoSource { camera, gallery }

class _MarkdownEditingController extends TextEditingController {
  _MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    final expression = RegExp(r'(\*\*[^\n]+?\*\*|_[^\n]+?_)');
    var offset = 0;
    for (final match in expression.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final value = match.group(0)!;
      final isBold = value.startsWith('**');
      final markerLength = isBold ? 2 : 1;
      final marker = value.substring(0, markerLength);
      final content = value.substring(
        markerLength,
        value.length - markerLength,
      );
      final markerStyle = TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.6),
        fontSize: 12,
      );
      spans.add(TextSpan(text: marker, style: markerStyle));
      spans.add(
        TextSpan(
          text: content,
          style: isBold
              ? const TextStyle(fontWeight: FontWeight.w800)
              : const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
      spans.add(TextSpan(text: marker, style: markerStyle));
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return TextSpan(style: style, children: spans);
  }
}

/// A single icon-over-label tool in the editor's seamless bottom strip.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
