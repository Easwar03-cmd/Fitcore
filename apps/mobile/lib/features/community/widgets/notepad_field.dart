import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Multi-line notepad with keyboard auto-correction and a mic button for
/// voice-to-text. Autosaves through [onSave] after the user pauses typing.
class NotepadField extends StatefulWidget {
  const NotepadField({
    super.key,
    required this.initialText,
    required this.onSave,
    this.onChanged,
    this.enabled = true,
    this.minLines = 8,
  });

  final String initialText;
  final Future<void> Function(String text) onSave;

  /// Fires on every edit, including dictated text.
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int minLines;

  @override
  State<NotepadField> createState() => _NotepadFieldState();
}

enum _SaveState { idle, saving, saved, failed }

class _NotepadFieldState extends State<NotepadField> {
  late final TextEditingController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _debounce;
  bool _listening = false;
  String _textBeforeDictation = '';
  _SaveState _saveState = _SaveState.idle;
  String _lastSaved = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _lastSaved = widget.initialText;
    _controller.addListener(() => widget.onChanged?.call(_controller.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _speech.cancel();
    // Flush a pending edit so closing the screen never loses notes.
    if (_controller.text != _lastSaved) {
      widget.onSave(_controller.text);
    }
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _save);
  }

  Future<void> _save() async {
    final text = _controller.text;
    if (text == _lastSaved) return;
    if (mounted) setState(() => _saveState = _SaveState.saving);
    try {
      await widget.onSave(text);
      _lastSaved = text;
      if (mounted) setState(() => _saveState = _SaveState.saved);
    } catch (_) {
      if (mounted) setState(() => _saveState = _SaveState.failed);
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
          _scheduleSave();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Voice input is not available. Check the microphone permission '
            'and that speech recognition is enabled on your device.'),
      ));
      return;
    }
    _textBeforeDictation = _controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        final spoken = r.recognizedWords;
        final sep = _textBeforeDictation.isEmpty ||
                _textBeforeDictation.endsWith(' ') ||
                _textBeforeDictation.endsWith('\n')
            ? ''
            : ' ';
        final text = '$_textBeforeDictation$sep$spoken';
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      ),
    );
  }

  String get _statusLabel => switch (_saveState) {
        _SaveState.idle => '',
        _SaveState.saving => 'Saving…',
        _SaveState.saved => 'Saved',
        _SaveState.failed => 'Not saved — will retry',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            minLines: widget.minLines,
            maxLines: null,
            maxLength: 20000,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            // Keyboard-level correction / suggestions.
            autocorrect: true,
            enableSuggestions: true,
            onChanged: (_) => _scheduleSave(),
            decoration: const InputDecoration(
              hintText: 'Write your notes, goals or how today went…',
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(_statusLabel, style: theme.textTheme.bodySmall),
            ),
            FilledButton.tonalIcon(
              onPressed: widget.enabled ? _toggleMic : null,
              icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(_listening ? 'Stop' : 'Dictate'),
            ),
          ],
        ),
        if (_listening)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Listening… speak now',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
      ],
    );
  }
}
