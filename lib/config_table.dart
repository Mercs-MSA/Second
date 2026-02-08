import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:googleapis/binaryauthorization/v1.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:http/http.dart';
import 'package:second/settings.dart';
import 'package:second/util.dart';

class CheckoutConfigEntry {
  int dayOfWeek;
  DateTime checkTime;
  DateTime applyTime;
  bool backdate;
  bool enable;

  CheckoutConfigEntry(
    this.dayOfWeek,
    this.checkTime,
    this.applyTime,
    this.backdate,
    this.enable,
  );

  @override
  String toString() {
    return "CheckoutConfigEntry(day:$dayOfWeek,check:$checkTime,apply:$applyTime,backdate:$backdate,enable:$enable)";
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutConfigEntry &&
          runtimeType == other.runtimeType &&
          dayOfWeek == other.dayOfWeek &&
          checkTime.hour == other.checkTime.hour &&
          checkTime.minute == other.checkTime.minute &&
          applyTime.hour == other.applyTime.hour &&
          applyTime.minute == other.applyTime.minute &&
          backdate == other.backdate;

  @override
  int get hashCode => Object.hash(
    dayOfWeek,
    checkTime.hour,
    checkTime.minute,
    applyTime.hour,
    applyTime.minute,
    backdate,
  );
}

class CheckoutScheduler {
  List<CheckoutConfigEntry> configs;
  final Function(CheckoutConfigEntry entry, DateTime appliedTime) onTrigger;
  final String _storageKey = "checkout_execution_registry";

  Timer? _timer;

  CheckoutScheduler({required this.configs, required this.onTrigger});

  void start() {
    _checkAndExecute();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _checkAndExecute(),
    );
  }

  void stop() => _timer?.cancel();

  Future<void> _checkAndExecute() async {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final settings = SettingsManager.getInstance;

    String rawData = settings.prefs?.getString(_storageKey) ?? "{}";
    Map<String, dynamic> registry = jsonDecode(rawData);
    bool needsUpdate = false;

    // Since configs is not final, we iterate through the current state of the list
    for (var entry in configs) {
      if (!entry.enable) continue;

      // The hashCode acts as our unique ID based on the specific schedule values
      final String entryId = entry.hashCode.toString();

      if (registry[entryId] == todayStr) continue;

      bool isCorrectDay = entry.dayOfWeek == now.weekday;
      bool isTimePassed =
          (now.hour > entry.checkTime.hour) ||
          (now.hour == entry.checkTime.hour &&
              now.minute >= entry.checkTime.minute);

      if (isCorrectDay && isTimePassed) {
        registry[entryId] = todayStr;
        needsUpdate = true;

        DateTime appliedTime = DateTime(
          now.year,
          now.month,
          now.day,
          entry.applyTime.hour,
          entry.applyTime.minute,
          entry.applyTime.second,
        );

        if (entry.backdate) {
          appliedTime = appliedTime.subtract(const Duration(hours: 24));
        }

        onTrigger(entry, appliedTime);
      }
    }

    if (needsUpdate) {
      await settings.prefs?.setString(_storageKey, jsonEncode(registry));
    }
  }
}

class CheckoutConfigurationTable {
  Spreadsheet spreadsheet;
  SheetsApi api;
  String sheetName;
  late List<String> headerOrder;

  ValueNotifier<List<CheckoutConfigEntry>> entries = ValueNotifier(
    <CheckoutConfigEntry>[],
  );

  CheckoutConfigurationTable(
    this.api,
    this.spreadsheet,
    this.sheetName, {
    this.headerOrder = const ["day", "check", "apply", "backdate", "enable"],
  });

  Future<void> load() async {
    var request = await api.spreadsheets.values.get(
      spreadsheet.spreadsheetId ?? "",
      "$sheetName!A2:${columnToReference(headerOrder.length)}",
      majorDimension: "ROWS",
    );

    final values = request.values ?? const <List<Object?>>[];

    List<CheckoutConfigEntry> newEntries = [];

    for (final rawEntry in values) {
      newEntries.add(
        CheckoutConfigEntry(
          [
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
          ].indexOf(
            (rawEntry[headerOrder.indexOf("day")]! as String)
                .trim()
                .toLowerCase(),
          ),
          parseTime(rawEntry[headerOrder.indexOf("check")]! as String),
          parseTime(rawEntry[headerOrder.indexOf("apply")]! as String),
          (rawEntry[headerOrder.indexOf("backdate")]! as String)
                  .toLowerCase() ==
              "true",
          (rawEntry[headerOrder.indexOf("enable")]! as String).toLowerCase() ==
              "true",
        ),
      );
    }

    entries.value = newEntries;
  }

  Future<void> setEntries(List<CheckoutConfigEntry> newEntries) async {
    List<List<Object>> values = [];
    final days = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];

    for (final entry in newEntries) {
      List<Object> row = List.filled(headerOrder.length, "");
      row[headerOrder.indexOf("day")] = days[entry.dayOfWeek];
      row[headerOrder.indexOf("check")] =
          "${entry.checkTime.hour.toString().padLeft(2, '0')}:${entry.checkTime.minute.toString().padLeft(2, '0')}";
      row[headerOrder.indexOf("apply")] =
          "${entry.applyTime.hour.toString().padLeft(2, '0')}:${entry.applyTime.minute.toString().padLeft(2, '0')}";
      row[headerOrder.indexOf("backdate")] = entry.backdate.toString();
      row[headerOrder.indexOf("enable")] = entry.enable.toString();
      values.add(row);
    }

    await api.spreadsheets.values.update(
      ValueRange(values: values, majorDimension: "ROWS"),
      spreadsheet.spreadsheetId ?? "",
      "$sheetName!A2:${columnToReference(headerOrder.length)}${newEntries.length + 1}",
      valueInputOption: "USER_ENTERED",
    );

    entries.value = newEntries;
  }
}
