import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/photo_picker_sheet.dart';

/// What the [NoteEditorScreen] hands back to the journal list: the saved note
/// (created or updated), or a flag that it was deleted. Null pop = no change.
class NoteEditResult {
  final ActivityEvent? saved;
  final bool deleted;
  const NoteEditResult.saved(this.saved) : deleted = false;
  const NoteEditResult.deleted()
      : saved = null,
        deleted = true;
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
  String? get existingPhotoUrl => existing?.notePhotoUrl;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.initialTitle ?? '');
  late final TextEditingController _bodyCtrl =
      TextEditingController(text: widget.initialText ?? '');
  final FocusNode _bodyFocus = FocusNode();
  late String _previousBody = widget.initialText ?? '';

  File? _newPhoto;
  bool _removeExisting = false;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  bool get _hasPhoto =>
      _newPhoto != null ||
      (widget.existingPhotoUrl != null && !_removeExisting);

  bool _isDirty() {
    final titleChanged =
        _titleCtrl.text.trim() != (widget.initialTitle ?? '').trim();
    final bodyChanged =
        _bodyCtrl.text.trimRight() != (widget.initialText ?? '').trimRight();
    final photoChanged = _newPhoto != null || _removeExisting;
    return titleChanged || bodyChanged || photoChanged;
  }

  Future<void> _pickPhoto() async {
    final res = await showPhotoPickerSheet(context);
    if (res?.file != null) {
      setState(() {
        _newPhoto = res!.file;
        _removeExisting = false;
      });
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
          photo: _newPhoto,
          removePhoto: _removeExisting && _newPhoto == null,
        );
      } else {
        event = await ApiService.addPlantNote(
          widget.plantId,
          text,
          title: title,
          photo: _newPhoto,
        );
      }
      if (!mounted) return null;
      setState(() => _busy = false);
      return NoteEditResult.saved(event);
    } catch (e) {
      if (!mounted) return null;
      setState(() => _busy = false);
      AppSnackBar.error(context, 'Failed to save note: $e');
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
        title: const Text('Delete note',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This note will be removed permanently.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.deletePlantNote(
          widget.plantId, widget.existing!.careLogId!);
      if (!mounted) return;
      Navigator.pop(context, const NoteEditResult.deleted());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(context, 'Failed to delete note: $e');
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
        title: const Text('Save changes?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('You have unsaved changes to this note.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Keep editing',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
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
    final lineStart =
        cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
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
          final from = cursor - 2 < 0 ? -1 : value.lastIndexOf('\n', cursor - 2);
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
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                    if (_hasPhoto) ...[
                      const SizedBox(height: 14),
                      _buildInlinePhoto(),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bodyCtrl,
                      focusNode: _bodyFocus,
                      onChanged: _onBodyChanged,
                      minLines: 10,
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

  Widget _buildInlinePhoto() {
    final showNew = _newPhoto != null;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: showNew
              ? Image.file(
                  _newPhoto!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: widget.existingPhotoUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() {
              if (showNew) {
                _newPhoto = null;
              } else {
                _removeExisting = true;
              }
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
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
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
