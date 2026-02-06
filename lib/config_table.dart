import 'package:googleapis/binaryauthorization/v1.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:http/http.dart';
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
}

class CheckoutConfigurationTable {
  Spreadsheet spreadsheet;
  SheetsApi api;
  String sheetName;
  late List<String> headerOrder;

  List<CheckoutConfigEntry> entries = [];

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

    entries = newEntries;
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

    entries = newEntries;
  }
}
