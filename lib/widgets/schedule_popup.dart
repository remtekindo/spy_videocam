import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/scheduler_service.dart';

class SchedulePopup extends StatefulWidget {
  final Function(int hour, int minute) onSchedule;
  final VoidCallback onCancel;

  const SchedulePopup({
    super.key,
    required this.onSchedule,
    required this.onCancel,
  });

  @override
  State<SchedulePopup> createState() => _SchedulePopupState();
}

class _SchedulePopupState extends State<SchedulePopup> {
  late int _selectedHour;
  late int _selectedMinute;
  String? _errorMessage;

  final FixedExtentScrollController _hourController =
      FixedExtentScrollController();
  final FixedExtentScrollController _minuteController =
      FixedExtentScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default ke jam berikutnya
    _selectedHour = (now.hour + 1).clamp(0, 23);
    _selectedMinute = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hourController.jumpToItem(_selectedHour);
      _minuteController.jumpToItem(_selectedMinute);
    });
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = days[now.weekday - 1];
    final month = months[now.month - 1];
    return '$day, ${now.day} $month ${now.year}';
  }

  void _validate() {
    setState(() {
      final remaining =
          SchedulerService.timeUntil(_selectedHour, _selectedMinute);
      if (remaining == Duration.zero) {
        _errorMessage = 'Jam yang dipilih sudah lewat hari ini';
      } else {
        _errorMessage = null;
      }
    });
  }

  void _onConfirm() {
    final remaining =
        SchedulerService.timeUntil(_selectedHour, _selectedMinute);
    if (remaining == Duration.zero) {
      setState(() => _errorMessage = 'Jam yang dipilih sudah lewat hari ini');
      return;
    }
    widget.onSchedule(_selectedHour, _selectedMinute);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onCancel();
        return false;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildDateBadge(),
              _buildTimePicker(),
              if (_errorMessage != null) _buildError(),
              _buildCountdown(),
              const SizedBox(height: 16),
              _buildButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Text(
            'Rekam terjadwal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 13, color: Color(0xFF888888)),
            const SizedBox(width: 6),
            Text(
              'Tanggal rekaman:',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _todayLabel(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih jam mulai',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDrumPicker(
                controller: _hourController,
                itemCount: 24,
                label: (i) => i.toString().padLeft(2, '0'),
                onSelected: (i) {
                  _selectedHour = i;
                  _validate();
                },
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Expanded(child: _buildDrumPicker(
                controller: _minuteController,
                itemCount: 60,
                label: (i) => i.toString().padLeft(2, '0'),
                onSelected: (i) {
                  _selectedMinute = i;
                  _validate();
                },
              )),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Hanya jam & menit yang dapat diubah · tanggal mengikuti hari ini',
            style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrumPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) label,
    required ValueChanged<int> onSelected,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight selected row
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            diameterRatio: 1.4,
            squeeze: 1.1,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelected,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= itemCount) return null;
                return Center(
                  child: Text(
                    label(index),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'monospace',
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF7C1C1), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 13, color: Color(0xFFA32D2D)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA32D2D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final remaining =
        SchedulerService.timeUntil(_selectedHour, _selectedMinute);
    if (remaining == Duration.zero) return const SizedBox.shrink();

    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h jam');
    if (m > 0 || h == 0) parts.add('$m menit');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 12, color: Color(0xFF185FA5)),
          const SizedBox(width: 5),
          Text(
            'Rekaman dimulai dalam ${parts.join(' ')}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF185FA5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    final hasError = _errorMessage != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: const Color(0xFF888888),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: hasError ? null : _onConfirm,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: hasError
                      ? const Color(0xFFDDDDDD)
                      : const Color(0xFF185FA5),
                  width: 0.5,
                ),
                backgroundColor: hasError
                    ? const Color(0xFFF5F5F5)
                    : const Color(0xFFE6F1FB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: hasError
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFF0C447C),
              ),
              child: const Text(
                'Jadwalkan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}