import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/chat_provider.dart' show OutgoingAttachment;

const _mimeByExt = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  '3gp': 'video/3gpp',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
};

String? _mimeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _mimeByExt[fileName.substring(dot + 1).toLowerCase()];
}

/// Bottom input bar: text, attach (camera / photo / video / document), send,
/// reply preview, and an "post as update" toggle for admins.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onSendAttachment,
    required this.onError,
    required this.isAdmin,
    this.replyingToLabel,
    this.onCancelReply,
  });

  final Future<void> Function(String text, bool asUpdate) onSendText;
  final Future<void> Function(OutgoingAttachment file) onSendAttachment;
  final void Function(String message) onError;
  final bool isAdmin;
  final String? replyingToLabel;
  final VoidCallback? onCancelReply;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _asUpdate = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSendText(text, _asUpdate);
      _controller.clear();
      if (_asUpdate) setState(() => _asUpdate = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(_Source source) async {
    Navigator.of(context).pop();
    setState(() => _busy = true);
    try {
      final file = await _pick(source);
      if (file == null) return;
      await widget.onSendAttachment(file);
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<OutgoingAttachment?> _pick(_Source source) async {
    final picker = ImagePicker();
    switch (source) {
      case _Source.camera:
      case _Source.gallery:
        final x = await picker.pickImage(
          source: source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
        );
        if (x == null) return null;
        final mime = _mimeFor(x.name) ?? 'image/jpeg';
        return OutgoingAttachment(
          bytes: await x.readAsBytes(),
          fileName: x.name,
          contentType: mime,
        );
      case _Source.video:
        final x = await picker.pickVideo(source: ImageSource.gallery);
        if (x == null) return null;
        return OutgoingAttachment(
          bytes: await x.readAsBytes(),
          fileName: x.name,
          contentType: _mimeFor(x.name) ?? 'video/mp4',
        );
      case _Source.document:
        final r = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'txt'],
        );
        final f = r?.files.single;
        if (f == null || f.bytes == null) return null;
        return OutgoingAttachment(
          bytes: f.bytes!,
          fileName: f.name,
          contentType: _mimeFor(f.name) ?? 'application/pdf',
        );
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => _attach(_Source.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => _attach(_Source.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => _attach(_Source.video),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document (PDF / text)'),
              onTap: () => _attach(_Source.document),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyingToLabel != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.reply_rounded),
                title: Text(widget.replyingToLabel!,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onCancelReply,
                ),
              ),
            if (widget.isAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: FilterChip(
                    avatar: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Post as update'),
                    selected: _asUpdate,
                    onSelected: (v) => setState(() => _asUpdate = v),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    icon: const Icon(Icons.attach_file_rounded),
                    onPressed: _busy ? null : _showAttachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _asUpdate ? 'Write an update…' : 'Message',
                        counterText: '',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : IconButton(
                            icon: Icon(Icons.send_rounded, color: cs.onPrimary),
                            onPressed: _send,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Source { camera, gallery, video, document }
