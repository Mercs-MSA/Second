import 'package:flutter/material.dart';

class AutoClockOutSettings extends StatefulWidget {
  const AutoClockOutSettings({super.key});

  @override
  State<AutoClockOutSettings> createState() => _AutoClockOutSettingsState();
}

class _AutoClockOutSettingsState extends State<AutoClockOutSettings> {
  // Data structure to hold independent settings for each day
  final Map<String, DayConfig> _configs = {
    'Monday': DayConfig(),
    'Tuesday': DayConfig(),
    'Wednesday': DayConfig(),
    'Thursday': DayConfig(),
    'Friday': DayConfig(),
    'Saturday': DayConfig(),
    'Sunday': DayConfig(),
  };

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
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                // Perform Save Logic here
                Navigator.pop(context);
              },
              child: const Text("SAVE CHANGES"),
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
  bool isEnabled = true;
  TimeOfDay triggerTime = const TimeOfDay(hour: 3, minute: 0);
  TimeOfDay outTime = const TimeOfDay(hour: 21, minute: 0);
  bool isPreviousDay = true;
}
