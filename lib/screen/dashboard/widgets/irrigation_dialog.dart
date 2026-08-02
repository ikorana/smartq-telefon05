import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../comminication/dataBridgeServis.dart';
import '../../../models/irrigation_system.dart';
import '../../../utils/irrigation_service.dart';
import '../dashboardController.dart';

class IrrigationDialog extends StatefulWidget {
  const IrrigationDialog({super.key});

  @override
  State<IrrigationDialog> createState() => _IrrigationDialogState();
}

class _IrrigationDialogState extends State<IrrigationDialog> {
  final irrigationService = Get.find<IrrigationService>();
  final dashboardController = Get.find<DashboardController>();
  StreamSubscription? _statusSubscription;
  
  IrrigationSystem? system;
  bool isLoading = true;
  String? selectedScheduleId;
  int? _runningStatus; // null: bekliyor, 0: çalışmıyor, 1: çalışıyor

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _listenForStatus();
    irrigationService.getIrrigationStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _listenForStatus() {
    _statusSubscription = Get.find<DataBridgeService>().dataStream.listen((data) {
      final payload = data['full_payload'];
      if (payload is Map && payload['com'] == 'get_irrigation') {
        if (mounted) {
          setState(() {
            _runningStatus = int.tryParse(payload['running']?.toString() ?? '');
          });
        }
      }
    });
  }

  Future<void> _loadConfig() async {
    final config = await irrigationService.getConfiguration();
    if (mounted) {
      setState(() {
        system = config;
        isLoading = false;
        if (config != null && config.schedules.isNotEmpty) {
          selectedScheduleId = config.schedules.first.id;
        }
      });
    }
  }

  void _updateSettings({String? newStatus, int? newSmart}) {
    if (system == null) return;

    final String status = newStatus ?? system!.status;
    final int smart = newSmart ?? system!.smart;

    irrigationService.updateSystemSettings(status: status, smart: smart);

    // UI'ı anlık güncellemek için (Gateway'den AK gelene kadar kullanıcı görsün)
    setState(() {
      system = IrrigationSystem(
        systemId: system!.systemId,
        name: system!.name,
        status: status,
        smart: smart,
        hardware: system!.hardware,
        schedules: system!.schedules,
      );
    });

    Get.snackbar(
      "Sistem",
      "Sulama ayarları güncellendi",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primary.withOpacity(0.8),
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.water_drop, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('garden_watering'.tr),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      content: SizedBox(
        width: 500,
        child: isLoading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : system == null
                ? Text('config_load_error'.tr)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'select_schedule_to_run'.tr, // "Çalıştırmak istediğiniz programı seçin"
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: system!.schedules.map((schedule) {
                              return _buildScheduleItem(schedule, theme);
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                        ),
                        child: Text(
                          'irrigation_info_desc'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _runningStatus == 1 
                  ? () {
                      irrigationService.stopIrrigation(stat: "pin");
                      Get.back();
                      Get.snackbar(
                        "Sistem", 
                        "Sulama sistemi durduruldu", 
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.redAccent.withOpacity(0.8),
                        colorText: Colors.white,
                      );
                    }
                  : null,
                icon: Icon(
                  Icons.stop_circle, 
                  color: _runningStatus == 1 ? Colors.redAccent : Colors.grey
                ),
                label: Text(
                  _runningStatus == 1 
                      ? "Sulama Çalışıyor. Sulamayı DURDUR" 
                      : (_runningStatus == 0 ? "Şu Anda Aktif Sulama YOK" : "Durum Sorgulanıyor..."), 
                  style: TextStyle(
                    color: _runningStatus == 1 ? Colors.redAccent : Colors.grey, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  )
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _runningStatus == 1 ? Colors.redAccent : Colors.grey)
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // --- SİSTEM AYARLARI (Küçültülmüş Chip Görünümü) ---
            if (system != null)
              Expanded(
                child: Row(
                  children: [
                    _buildSettingsChip(
                      label: "Sistem",
                      value: system!.status == "enabled",
                      onChanged: (bool val) => _updateSettings(newStatus: val ? "enabled" : "disabled"),
                      theme: theme,
                    ),
                    const SizedBox(width: 6),
                    _buildSettingsChip(
                      label: "Smart",
                      value: system!.smart == 1,
                      onChanged: (bool val) => _updateSettings(newSmart: val ? 1 : 0),
                      theme: theme,
                    ),
                  ],
                ),
              ),
            
            TextButton(
              onPressed: () => Get.back(),
              child: Text('cancel'.tr.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: selectedScheduleId == null
                  ? null
                  : () {
                      final selectedSchedule = system?.schedules.firstWhereOrNull((s) => s.id == selectedScheduleId);
                      if (selectedSchedule != null) {
                        Get.find<IrrigationService>().startSchedule(selectedSchedule.startTime);
                      }
                      
                      Get.back();
                      Get.snackbar(
                        "Sistem", 
                        "Sulama programı başlatıldı", 
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                        colorText: Colors.white,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(60, 36),
              ),
              child: Text('start_now'.tr.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleItem(Schedule schedule, ThemeData theme) {
    final isSelected = selectedScheduleId == schedule.id;

    return GestureDetector(
      onTap: () => setState(() => selectedScheduleId = schedule.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${schedule.startTime} - ${schedule.activeDays.map((d) => d.tr).join(', ')}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "Overlap: ${schedule.overlapSeconds}s",
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
                if (isSelected) Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
              ],
            ),
            const SizedBox(height: 15),
            // AKIŞ DİYAGRAMI (Flow Diagram)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFlowStep(Icons.settings_input_component, "Pompa", "", theme, isStart: true),
                  ...schedule.durations.map((d) {
                    final segment = system?.hardware.segments.firstWhereOrNull((s) => s.id == d.segmentId);
                    return Row(
                      children: [
                        _buildArrow(theme),
                        _buildFlowStep(
                          Icons.water_drop, 
                          segment?.name ?? "Bölge", 
                          "${d.time} dk", 
                          theme,
                          subLabel: "ID: ${d.id}",
                          onTap: () {
                            irrigationService.startSegment(
                              segmentId: d.segmentId,
                              relayId: d.relayId,
                              time: d.time,
                            );
                            Get.snackbar(
                              "Sistem", 
                              "${segment?.name ?? 'Bölge'} başlatma komutu gönderildi", 
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                              colorText: Colors.white,
                            );
                          },
                        ),
                      ],
                    );
                  }),
                  _buildArrow(theme),
                  _buildFlowStep(
                    Icons.stop_circle_outlined, 
                    "Bitiş", 
                    "", 
                    theme, 
                    isEnd: true,
                    onTap: () {
                      irrigationService.stopIrrigation(stat: "pin");
                      Get.snackbar(
                        "Sistem", 
                        "Sulama durdurma komutu (PIN) gönderildi", 
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.orange.withOpacity(0.8),
                        colorText: Colors.white,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep(IconData icon, String label, String duration, ThemeData theme, {String? subLabel, bool isStart = false, bool isEnd = false, VoidCallback? onTap}) {
    Color color = theme.colorScheme.onSurface.withOpacity(0.7);
    if (isStart) color = Colors.orange;
    if (isEnd) color = Colors.redAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            if (subLabel != null)
              Text(subLabel, style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurface.withOpacity(0.5))),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            if (duration.isNotEmpty)
              Text(duration, style: TextStyle(fontSize: 9, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.2)),
    );
  }

  Widget _buildSettingsChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                color: value ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 20,
              child: Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
