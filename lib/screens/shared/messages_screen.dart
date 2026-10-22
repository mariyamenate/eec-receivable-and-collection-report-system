import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

// Fixed paths for lib/screens/shared/ folder
import '../../models/meeting.dart';
import '../../models/chat_message.dart';
import '../../services/meeting_service.dart';
import '../../services/chat_service.dart';

/// Matches the exact UI from the screenshot:
/// Left  → Video meeting · full control
/// Right → Team chat + voice
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // ── Colors matching the screenshot ───────────────────────────────────────
  static const Color _primary = Color(0xFF0D7377); // dark teal
  static const Color _headerBg = Color(0xFFE8F5F3); // light mint
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _fieldBg = Colors.white;

  // ── Meeting form ──────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController(text: 'Weekly Collection Meeting');
  final _notesCtrl = TextEditingController();
  final _linkCtrl = TextEditingController(text: 'https://meet.jit.si/EEC-Collection-20260831');
  DateTime _scheduledAt = DateTime(2026, 9, 2);
  String _status = 'Live now';
  Meeting? _currentMeeting;
  bool _meetingSaving = false;

  // ── Chat ──────────────────────────────────────────────────────────────────
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _chatLoading = false;
  bool _sending = false;

  // ── Recipient selection (NEW) ─────────────────────────────────────────────
  int? _selectedRecipientId; // null = All Team
  String _selectedRecipientName = 'All Team';

  // Temporary list – replace later with real users from your API
  final List<Map<String, dynamic>> _people = [
    {'id': null, 'name': 'All Team'},
    {'id': 11, 'name': 'Abebe (Collector - Construction)'},
    {'id': 12, 'name': 'Sara (Collector - Water)'},
    {'id': 21, 'name': 'Dawit (Team Leader)'},
    {'id': 31, 'name': 'Hanna (Senior Accountant)'},
    {'id': 41, 'name': 'Yonas (Finance Director)'},
  ];

  // ── Voice recording ───────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _playingId;

  // Demo user – replace with real auth later
  final int _myUserId = 1;
  final String _myName = 'Collector';

  // true = works offline with local data (recommended while backend not ready)
  static const bool useLocalFallback = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _linkCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Meeting actions ───────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      setState(() => _scheduledAt = date);
    }
  }

  Future<void> _saveMeeting() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a meeting title');
      return;
    }
    setState(() => _meetingSaving = true);
    try {
      final room = _extractRoom(_linkCtrl.text.trim());
      final meeting = Meeting(
        id: _currentMeeting?.id,
        title: _titleCtrl.text.trim(),
        scheduledAt: _scheduledAt,
        jitsiRoom: room,
        status: _status.toLowerCase().contains('live') ? 'live' : 'scheduled',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final saved = useLocalFallback
          ? (_currentMeeting?.id != null
          ? await MeetingService.updateMeetingLocal(meeting)
          : await MeetingService.createMeetingLocal(meeting))
          : (_currentMeeting?.id != null
          ? await MeetingService.updateMeeting(meeting)
          : await MeetingService.createMeeting(meeting));

      setState(() {
        _currentMeeting = saved;
        _status = saved.status == 'live' ? 'Live now' : 'Scheduled';
      });
      _snack('Meeting saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _meetingSaving = false);
    }
  }

  Future<void> _markLive() async {
    setState(() {
      _status = 'Live now';
      _meetingSaving = true;
    });
    try {
      if (_currentMeeting?.id != null) {
        if (useLocalFallback) {
          final updated = _currentMeeting!.copyWith(status: 'live');
          await MeetingService.updateMeetingLocal(updated);
          setState(() => _currentMeeting = updated);
        } else {
          final updated = await MeetingService.markLive(_currentMeeting!.id!);
          setState(() => _currentMeeting = updated);
        }
      }
      _snack('Meeting is now LIVE');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _meetingSaving = false);
    }
  }

  Future<void> _joinVideo() async {
    final urlText = _linkCtrl.text.trim();
    if (urlText.isEmpty) {
      _snack('Enter a video link first');
      return;
    }
    final url = Uri.tryParse(urlText);
    if (url == null) {
      _snack('Invalid link');
      return;
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open the link');
    }
  }

  String _extractRoom(String link) {
    if (link.contains('meet.jit.si/')) {
      return link.split('meet.jit.si/').last.split('?').first;
    }
    return link;
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _chatLoading = true);
    try {
      final list = useLocalFallback
          ? await ChatService.getMessagesLocal(meetingId: _currentMeeting?.id)
          : await ChatService.getMessages(meetingId: _currentMeeting?.id);
      setState(() => _messages = list);
      _scrollToBottom();
    } catch (e) {
      debugPrint('load messages error: $e');
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _sendText() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _chatCtrl.clear();
    try {
      final msg = useLocalFallback
          ? await ChatService.sendTextLocal(
        content: text,
        meetingId: _currentMeeting?.id,
        senderId: _myUserId,
        senderName: _myName,
        recipientId: _selectedRecipientId, // ← NEW
      )
          : await ChatService.sendText(
        content: text,
        meetingId: _currentMeeting?.id,
        senderId: _myUserId,
        senderName: _myName,
        recipientId: _selectedRecipientId, // ← NEW
      );
      setState(() => _messages = [..._messages, msg]);
      _scrollToBottom();
    } catch (e) {
      _snack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _snack('Microphone permission required');
      return;
    }
    if (!await _recorder.hasPermission()) {
      _snack('No microphone permission');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path == null || path.isEmpty) return;

    setState(() => _sending = true);
    try {
      final msg = useLocalFallback
          ? await ChatService.sendVoiceLocal(
        localFilePath: path,
        durationSeconds: _recordSeconds,
        meetingId: _currentMeeting?.id,
        senderId: _myUserId,
        senderName: _myName,
        recipientId: _selectedRecipientId, // ← NEW
      )
          : await ChatService.sendVoice(
        localFilePath: path,
        durationSeconds: _recordSeconds,
        meetingId: _currentMeeting?.id,
        senderId: _myUserId,
        senderName: _myName,
        recipientId: _selectedRecipientId, // ← NEW
      );
      setState(() => _messages = [..._messages, msg]);
      _scrollToBottom();
    } catch (e) {
      _snack('Voice send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _playVoice(ChatMessage msg) async {
    if (_playingId == msg.id?.toString()) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    try {
      final source = msg.content.startsWith('http')
          ? UrlSource(msg.content)
          : DeviceFileSource(msg.content);
      await _player.play(source);
      setState(() => _playingId = msg.id?.toString());
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingId = null);
      });
    } catch (e) {
      _snack('Playback failed: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _weekdayLabel(DateTime d) {
    return DateFormat('EEEE').format(d).toUpperCase();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildMeetingCard()),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: _buildChatCard()),
            ],
          )
              : Column(
            children: [
              Expanded(flex: 5, child: _buildMeetingCard()),
              const SizedBox(height: 12),
              Expanded(flex: 5, child: _buildChatCard()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Left card: Video meeting · full control ───────────────────────────────
  Widget _buildMeetingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text(
              'Video meeting · full control',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3A3A),
              ),
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('MEETING TITLE'),
                  _textField(_titleCtrl, hint: 'Weekly Collection Meeting'),
                  const SizedBox(height: 16),

                  _fieldLabel('MEETING DATE (${_weekdayLabel(_scheduledAt)})'),
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: _textField(
                        TextEditingController(
                          text: DateFormat('MM/dd/yyyy').format(_scheduledAt),
                        ),
                        hint: 'MM/DD/YYYY',
                        suffix: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('VIDEO LINK (JITSI / ZOOM / GOOGLE MEET)'),
                  _textField(
                    _linkCtrl,
                    hint: 'https://meet.jit.si/...',
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('STATUS'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _fieldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _status,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        items: const [
                          DropdownMenuItem(value: 'Live now', child: Text('Live now')),
                          DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                          DropdownMenuItem(value: 'Ended', child: Text('Ended')),
                          DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('NOTES (AGENDA / DECISIONS)'),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _fieldBg,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _joinVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Join video call',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _meetingSaving ? null : _saveMeeting,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF424242),
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _meetingSaving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Save meeting', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _meetingSaving ? null : _markLive,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF424242),
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Mark live', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Right card: Team chat + voice ─────────────────────────────────────────
  Widget _buildChatCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text(
              'Team chat + voice',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3A3A),
              ),
            ),
          ),

          // ========== NEW: Send to dropdown ==========
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: DropdownButtonFormField<int?>(
              value: _selectedRecipientId,
              decoration: InputDecoration(
                labelText: 'Send to',
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
              items: _people.map((p) {
                return DropdownMenuItem<int?>(
                  value: p['id'] as int?,
                  child: Text(p['name'] as String, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRecipientId = value;
                  _selectedRecipientName =
                  _people.firstWhere((p) => p['id'] == value)['name'] as String;
                });
              },
            ),
          ),
          // ===========================================

          // Messages area
          Expanded(
            child: _chatLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No messages yet. Type or record a voice message.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 14,
                  ),
                ),
              ),
            )
                : ListView.builder(
              controller: _chatScroll,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),

          // Recording indicator
          if (_isRecording)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Recording… ${_formatDuration(_recordSeconds)}  (tap Record again to send)',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    enabled: !_isRecording,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? 'Recording…'
                          : (_selectedRecipientId == null
                          ? 'Message to All Team…'
                          : 'Private message to $_selectedRecipientName…'),
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                ElevatedButton(
                  onPressed: (_sending || _isRecording) ? null : _sendText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Send', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                // Record button
                OutlinedButton.icon(
                  onPressed: _sending ? null : _toggleRecord,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 18,
                    color: _isRecording ? Colors.red : _primary,
                  ),
                  label: Text(
                    _isRecording ? 'Stop' : 'Record',
                    style: TextStyle(
                      color: _isRecording ? Colors.red : _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isRecording ? Colors.red : _border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat bubble ───────────────────────────────────────────────────────────
  Widget _buildBubble(ChatMessage msg) {
    final isMine = msg.isMine;
    final time = DateFormat('HH:mm').format(msg.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _primary : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ),
            if (msg.type == 'voice')
              _voiceBubble(msg, isMine)
            else
              Text(
                msg.content,
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 14.5,
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceBubble(ChatMessage msg, bool isMine) {
    final playing = _playingId == msg.id?.toString();
    return Row(
      children: [
        IconButton(
          onPressed: () => _playVoice(msg),
          icon: Icon(
            playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: isMine ? Colors.white : _primary,
            size: 30,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(msg.durationSeconds ?? 0),
          style: TextStyle(
            fontSize: 13,
            color: isMine ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Color(0xFF757575),
        ),
      ),
    );
  }

  Widget _textField(
      TextEditingController controller, {
        String? hint,
        Widget? suffix,
      }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}