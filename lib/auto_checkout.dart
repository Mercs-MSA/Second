import 'package:flutter/material.dart';
import 'package:second/backend.dart';
import 'package:second/config_table.dart';

class AutoClockOutSettings extends StatefulWidget {
  final AttendanceTrackerBackend backend;
  const AutoClockOutSettings({super.key, required this.backend});

  @override
  State<AutoClockOutSettings> createState() => _AutoClockOutSettingsState();
}

class _AutoClockOutSettingsState extends State<AutoClockOutSettings> {
  bool _isLoading = false;
  // Data structure to hold independent settings for each day
  final Map<String, DayConfig> _configs = {
    'Sunday': DayConfig(),
    'Monday': DayConfig(),
    'Tuesday': DayConfig(),
    'Wednesday': DayConfig(),
    'Thursday': DayConfig(),
    'Friday': DayConfig(),
    'Saturday': DayConfig(),
  };

  @override
  void initState() {
    super.initState();
    final entries = widget.backend.timingsTable?.entries ?? [];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    for (var entry in entries) {
      if (entry.dayOfWeek >= 0 && entry.dayOfWeek < days.length) {
        final day = days[entry.dayOfWeek];
        _configs[day] = DayConfig(
          isEnabled: entry.enable,
          triggerTime: TimeOfDay.fromDateTime(entry.checkTime),
          outTime: TimeOfDay.fromDateTime(entry.applyTime),
          isPreviousDay: entry.backdate,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auto Clock-Out Rules"),
        // Removes the default back arrow
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: _configs.keys.map((day) => _buildDayTile(day)).toList(),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDayTile(String day) {
    final config = _configs[day]!;

    return ExpansionTile(
      leading: Icon(
        Icons.circle,
        size: 12,
        color: config.isEnabled ? Colors.green : Colors.grey,
      ),
      title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: config.isEnabled
          ? Text(
              "Check at ${config.triggerTime.format(context)} ➔ Set to ${config.outTime.format(context)}",
            )
          : const Text("Disabled"),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Enable for this day"),
                value: config.isEnabled,
                onChanged: (val) => setState(() => config.isEnabled = val),
              ),
              if (config.isEnabled) ...[
                ListTile(
                  title: const Text("If still in at:"),
                  trailing: OutlinedButton(
                    onPressed: () => _selectTime(context, day, true),
                    child: Text(config.triggerTime.format(context)),
                  ),
                ),
                ListTile(
                  title: const Text("Record out as:"),
                  trailing: OutlinedButton(
                    onPressed: () => _selectTime(context, day, false),
                    child: Text(config.outTime.format(context)),
                  ),
                ),
                CheckboxListTile(
                  title: const Text("Record on previous calendar day"),
                  subtitle: Text(
                    "Record checkout on the previous calendar day\n(useful if running checks after midnight)",
                  ),
                  value: config.isPreviousDay,
                  onChanged: (val) =>
                      setState(() => config.isPreviousDay = val ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String getPreviousDay(String currentDay) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    int currentIndex = days.indexOf(currentDay);
    if (currentIndex == -1) return currentDay;
    int prevIndex = (currentIndex - 1 + days.length) % days.length;
    return days[prevIndex];
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        final table = widget.backend.timingsTable;
                        if (table != null) {
                          const days = [
                            'Sunday',
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                          ];
                          List<CheckoutConfigEntry> newEntries = [];
                          for (int i = 0; i < days.length; i++) {
                            final day = days[i];
                            final config = _configs[day]!;
                            final now = DateTime.now();
                            newEntries.add(
                              CheckoutConfigEntry(
                                i,
                                DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  config.triggerTime.hour,
                                  config.triggerTime.minute,
                                ),
                                DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  config.outTime.hour,
                                  config.outTime.minute,
                                ),
                                config.isPreviousDay,
                                config.isEnabled,
                              ),
                            );
                          }
                          await table.setEntries(newEntries);
                        }
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error saving settings: $e"),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text("Save"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    String day,
    bool isTrigger,
  ) async {
    final config = _configs[day]!;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isTrigger ? config.triggerTime : config.outTime,
    );
    if (picked != null) {
      setState(() {
        if (isTrigger) {
          config.triggerTime = picked;
        } else {
          config.outTime = picked;
        }
      });
    }
  }
}

// Simple data model for independent daily settings
class DayConfig {
  bool isEnabled;
  TimeOfDay triggerTime;
  TimeOfDay outTime;
  bool isPreviousDay;

  DayConfig({
    this.isEnabled = true,
    this.triggerTime = const TimeOfDay(hour: 3, minute: 0),
    this.outTime = const TimeOfDay(hour: 21, minute: 0),
    this.isPreviousDay = true,
  });
}
