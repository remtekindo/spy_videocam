import 'dart:async';
import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/scheduler_service.dart';
import '../widgets/recording_popup.dart';
import '../widgets/schedule_popup.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recordingService = RecordingService();
  final _schedulerService = SchedulerService();

  bool _showRecordingPopup = false;
  bool _isScheduledSession = false;
  bool _isMinimized = false;
  int? _scheduledHour;
  int? _scheduledMinute;
  Timer? _scheduleCountdownTimer;

  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _recordingService.stateStream.listen((state) {
      if (state == RecordingState.idle && mounted) {
        setState(() {
          _showRecordingPopup = false;
          _isMinimized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _scheduleCountdownTimer?.cancel();
    super.dispose();
  }

  // ─── Manual recording ───────────────────────────────────────────────

  Future<void> _startManualRecording() async {
    try {
      await _recordingService.startRecording(isScheduled: false);
      if (mounted) {
        setState(() {
          _isScheduledSession = false;
          _showRecordingPopup = true;
          _isMinimized = false;
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // ─── Scheduled recording ─────────────────────────────────────────────

  void _openSchedulePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SchedulePopup(
        onCancel: () => Navigator.of(context).pop(),
        onSchedule: (hour, minute) {
          Navigator.of(context).pop();
          _scheduleRecording(hour, minute);
        },
      ),
    );
  }

  Future<void> _scheduleRecording(int hour, int minute) async {
    try {
      await _schedulerService.scheduleRecording(hour: hour, minute: minute);
      setState(() {
        _scheduledHour = hour;
        _scheduledMinute = minute;
      });

      final delay = SchedulerService.timeUntil(hour, minute);
      _scheduleCountdownTimer?.cancel();
      _scheduleCountdownTimer = Timer(delay, () async {
        await _startScheduledRecording();
      });

      _showScheduledConfirmation(hour, minute, delay);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _startScheduledRecording() async {
    _scheduleCountdownTimer?.cancel();
    setState(() {
      _scheduledHour = null;
      _scheduledMinute = null;
    });

    try {
      await _recordingService.startRecording(isScheduled: true);
      if (mounted) {
        setState(() {
          _isScheduledSession = true;
          _showRecordingPopup = true;
          _isMinimized = false;
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _cancelSchedule() {
    _scheduleCountdownTimer?.cancel();
    _schedulerService.cancelSchedule();
    setState(() {
      _scheduledHour = null;
      _scheduledMinute = null;
    });
  }

  // ─── Popup control ───────────────────────────────────────────────────

  void _onMinimize() {
    setState(() => _isMinimized = true);
  }

  Future<void> _onStop() async {
    await _recordingService.stopRecording();
    setState(() {
      _showRecordingPopup = false;
      _isMinimized = false;
    });
  }

  void _onRestorePopup() {
    setState(() => _isMinimized = false);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFA32D2D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showScheduledConfirmation(int hour, int minute, Duration delay) {
    if (!mounted) return;
    final timeStr = SchedulerService.formatScheduleTime(hour, minute);
    final h = delay.inHours;
    final m = delay.inMinutes % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h jam');
    if (m > 0 || h == 0) parts.add('$m menit');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rekaman dijadwalkan pukul $timeStr · dimulai dalam ${parts.join(' ')}'),
        backgroundColor: const Color(0xFF185FA5),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRecording = _recordingService.state == RecordingState.recording;
    final isScheduled = _scheduledHour != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildAppHeader(),
                  const SizedBox(height: 24),
                  _buildStatusCard(isRecording, isScheduled),
                  const SizedBox(height: 24),
                  if (!isRecording) ...[
                    _buildSectionLabel('Rekam sekarang'),
                    const SizedBox(height: 10),
                    _buildManualButton(),
                    const SizedBox(height: 12),
                    _buildSectionLabel('Rekam otomatis'),
                    const SizedBox(height: 10),
                    _buildScheduledButton(isScheduled),
                  ],
                  if (isRecording && _isMinimized) ...[
                    const SizedBox(height: 8),
                    _buildMinimizedBar(),
                  ],
                ],
              ),
            ),
          ),

          // Recording popup overlay
          if (_showRecordingPopup && !_isMinimized)
            RecordingPopup(
              isScheduled: _isScheduledSession,
              onStop: _onStop,
              onMinimize: _onMinimize,
            ),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spy VideoCam',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v1.3.0 · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(bool isRecording, bool isScheduled) {
    Color bgColor;
    Color dotColor;
    String statusVal;
    String statusSub;

    if (isRecording) {
      bgColor = const Color(0xFFFCEBEB);
      dotColor = const Color(0xFFE24B4A);
      statusVal = _isScheduledSession ? 'Sesi terjadwal aktif' : 'Merekam';
      statusSub = 'Kamera aktif · chunk 10 menit';
    } else if (isScheduled) {
      bgColor = const Color(0xFFE6F1FB);
      dotColor = const Color(0xFF185FA5);
      statusVal = 'Menunggu jadwal';
      statusSub =
          'Mulai pukul ${SchedulerService.formatScheduleTime(_scheduledHour!, _scheduledMinute!)}';
    } else {
      bgColor = const Color(0xFFF5F5F5);
      dotColor = const Color(0xFF888888);
      statusVal = 'Tidak aktif';
      statusSub = 'Tidak ada sesi berjalan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bgColor == const Color(0xFFF5F5F5)
              ? const Color(0xFFE8E8E8)
              : bgColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusVal,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isRecording
                        ? const Color(0xFFA32D2D)
                        : isScheduled
                            ? const Color(0xFF0C447C)
                            : const Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSub,
                  style: TextStyle(
                    fontSize: 11,
                    color: isRecording
                        ? const Color(0xFFA32D2D)
                        : isScheduled
                            ? const Color(0xFF185FA5)
                            : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          if (isScheduled && !isRecording)
            GestureDetector(
              onTap: _cancelSchedule,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFB5D4F4), width: 0.5),
                ),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF185FA5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFFAAAAAA),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildManualButton() {
    return _ActionButton(
      icon: Icons.radio_button_checked,
      iconColor: const Color(0xFFE24B4A),
      iconBg: const Color(0xFFFCEBEB),
      label: 'Rekam manual',
      description: 'Mulai sekarang · maks 6 jam · stop kapan saja',
      onTap: _startManualRecording,
    );
  }

  Widget _buildScheduledButton(bool isScheduled) {
    return _ActionButton(
      icon: Icons.schedule,
      iconColor: const Color(0xFF185FA5),
      iconBg: const Color(0xFFE6F1FB),
      label: 'Rekam terjadwal',
      description: isScheduled
          ? 'Dijadwalkan pukul ${SchedulerService.formatScheduleTime(_scheduledHour!, _scheduledMinute!)}'
          : 'Atur jam mulai · tanggal hari ini otomatis',
      onTap: isScheduled ? null : _openSchedulePopup,
      disabled: isScheduled,
    );
  }

  Widget _buildMinimizedBar() {
    return GestureDetector(
      onTap: _onRestorePopup,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: StreamBuilder<RecordingSession?>(
          stream: _recordingService.sessionStream,
          initialData: _recordingService.session,
          builder: (context, snapshot) {
            final elapsed = snapshot.data?.elapsed ?? Duration.zero;
            final h = elapsed.inHours.toString().padLeft(2, '0');
            final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
            final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
            return Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE24B4A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'REC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE24B4A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$h:$m:$s',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                const Text(
                  'Ketuk untuk buka',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Reusable action button ───────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final bool disabled;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.description,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFCCCCCC),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}