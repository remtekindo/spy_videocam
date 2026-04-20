import 'package:flutter/material.dart';
import '../services/recording_service.dart';

class RecordingPopup extends StatefulWidget {
  final bool isScheduled;
  final VoidCallback onStop;
  final VoidCallback onMinimize;

  const RecordingPopup({
    super.key,
    required this.isScheduled,
    required this.onStop,
    required this.onMinimize,
  });

  @override
  State<RecordingPopup> createState() => _RecordingPopupState();
}

class _RecordingPopupState extends State<RecordingPopup>
    with SingleTickerProviderStateMixin {
  final _service = RecordingService();
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Blokir back button — popup hanya bisa ditutup via tombol Stop
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
          ),
          child: StreamBuilder<RecordingSession?>(
            stream: _service.sessionStream,
            initialData: _service.session,
            builder: (context, snapshot) {
              final session = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildRecIndicator(),
                  _buildDurationDisplay(session),
                  _buildChunkInfo(session),
                  const SizedBox(height: 8),
                  _buildMaxDurationBar(session),
                  const SizedBox(height: 20),
                  _buildButtons(),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.isScheduled ? 'Rekam terjadwal' : 'Rekam manual',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'tutup via tombol stop',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF888888),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _dotController,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE24B4A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.isScheduled ? 'REC · Terjadwal' : 'REC',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA32D2D),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationDisplay(RecordingSession? session) {
    final elapsed = session?.elapsed ?? Duration.zero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          const Text(
            'Durasi berjalan',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(elapsed),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w300,
              color: Color(0xFF1A1A1A),
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChunkInfo(RecordingSession? session) {
    final chunk = session?.chunkIndex ?? 1;
    final saved = session?.savedFiles ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Chunk ke-$chunk  ·  Tersimpan: $saved file',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _buildMaxDurationBar(RecordingSession? session) {
    final elapsed = session?.elapsed ?? Duration.zero;
    final maxSeconds = RecordingService.maxAllowedDuration.inSeconds;
    final progress = (elapsed.inSeconds / maxSeconds).clamp(0.0, 1.0);
    final remaining = RecordingService.maxAllowedDuration - elapsed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Batas maks 6 jam',
                style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
              ),
              Text(
                'Sisa ${_formatDuration(remaining)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.85
                    ? const Color(0xFFE24B4A)
                    : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onMinimize,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: const Color(0xFF1A1A1A),
              ),
              child: const Text(
                'Minimize',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _confirmStop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFF7C1C1), width: 0.5),
                backgroundColor: const Color(0xFFFCEBEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: const Color(0xFFA32D2D),
              ),
              child: const Text(
                'Stop',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmStop(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hentikan rekaman?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        content: const Text(
          'File chunk terakhir akan disimpan. Rekaman tidak dapat dilanjutkan.',
          style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onStop();
            },
            child: const Text(
              'Hentikan',
              style: TextStyle(
                color: Color(0xFFA32D2D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}