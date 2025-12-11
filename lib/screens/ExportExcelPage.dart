// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
///
///
///
// ---------------------------------- EXPORT ONLY TODAYS INSPECTED TECHNICIANS --------------------------
///
///
///
////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ExportOptionsPage extends StatefulWidget {
  const ExportOptionsPage({super.key});

  @override
  State<ExportOptionsPage> createState() => _ExportOptionsPageState();
}

class _ExportOptionsPageState extends State<ExportOptionsPage> {
  bool _exporting = false;
  String? _lastExportedFilePath;
  String? _lastExportType;

  bool isToday(DateTime date) {
    //helper to check if a DateTime is today
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> exportExcel() async {
    // Request storage permission
    final status = await Permission.manageExternalStorage.request();

    if (!status.isGranted) {
      Fluttertoast.showToast(msg: "Storage permission denied");
      return;
    }

    setState(() => _exporting = true);

    try {
      final supabase = Supabase.instance.client;
      // ------------------------------- EXPORT ALL TECHNICIANS, LATEST UPDATED DISPLAY AT LAST --------------------------
      final rows = await supabase.from('technician_tools').select('''
        technicians:technicians!technician_tools_technician_id_fkey(
          name,
          e_signature,
          pictures
        ),
        tools:tools!technician_tools_tools_id_fkey(name, category),
        status,
        last_updated_at),
          technician_remarks:technician_remarks!technician_remarks_technician_id_fkey(
          remarks
        ),
      ''');

      // Build remarks map
      final Map<String, String> technicianRemarks = {};

      for (final row in rows) {
        final tech = row['technicians'];
        final remarksList = row['technician_remarks']; // this is always a List

        if (tech != null) {
          final name = tech['name'] ?? '';

          if (!technicianRemarks.containsKey(name)) {
            if (remarksList is List && remarksList.isNotEmpty) {
              technicianRemarks[name] = remarksList.first['remarks'] ?? '';
            } else {
              technicianRemarks[name] = '';
            }
          }
        }
      }

      final techMap = <String, DateTime>{};
      final techSignatures = <String, String?>{};
      final techPictures = <String, String?>{};

      for (final r in rows) {
        final name = r['technicians']['name'];
        final createdAt = DateTime.parse(r['last_updated_at']); // <-- NEW
        final signature = r['technicians']['e_signature'];
        final picture = r['technicians']['pictures'];

        if (isToday(createdAt)) {
          // Only include technicians whose last_updated_at is today
          if (!techMap.containsKey(name) || createdAt.isAfter(techMap[name]!)) {
            techMap[name] = createdAt;
            techSignatures[name] = signature;
            techPictures[name] = picture;
          }
        }
      }

      final techNames = techMap.keys.toList()
        ..sort((a, b) => techMap[a]!.compareTo(techMap[b]!));

      final categorizedTools = <String, Set<String>>{};
      for (final r in rows) {
        final tool = r['tools']['name'];
        final category = r['tools']['category'] ?? "Uncategorized";

        categorizedTools.putIfAbsent(category, () => <String>{});
        categorizedTools[category]!.add(tool);
      }

      final sortedCategories = categorizedTools.keys.toList()..sort();
      final table = <String, Map<String, String>>{};

      for (final category in sortedCategories) {
        for (final tool in categorizedTools[category]!.toList()..sort()) {
          table[tool] = {for (var tech in techNames) tech: "None"};
        }
      }

      for (final r in rows) {
        final tech = r['technicians']['name'];
        final tool = r['tools']['name'];
        final status = r['status'] ?? "None";

        table[tool]![tech] = status;
      }

      final excel = Excel.createExcel();
      final boldStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      final defectiveStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.red,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      final missingStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.orange,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      final onhandStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.green900,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      final now = DateTime.now();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        TextCellValue("Tools"),
        ...techNames.map((t) => TextCellValue(t)),
      ]);

      for (var col = 0; col <= techNames.length; col++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
                .cellStyle =
            boldStyle;
      }

      for (final category in sortedCategories) {
        final headerRow = sheet.maxRows;

        sheet.appendRow([TextCellValue(category)]);
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: headerRow,
                  ),
                )
                .cellStyle =
            boldStyle;

        final sortedTools = categorizedTools[category]!.toList()..sort();

        for (final tool in sortedTools) {
          final rowIndex = sheet.maxRows;

          sheet.appendRow([
            TextCellValue(tool),
            ...techNames.map((tech) => TextCellValue(table[tool]![tech]!)),
          ]);

          for (var col = 1; col <= techNames.length; col++) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
            );

            final value = cell.value.toString();

            if (value == "Defective") {
              cell.cellStyle = defectiveStyle;
            } else if (value == "Missing") {
              cell.cellStyle = missingStyle;
            } else if (value == "Onhand") {
              cell.cellStyle = onhandStyle;
            }
          }
        }
      }

      // Signatures row
      final signatureRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue("Signatures"),
        ...techNames.map((name) {
          final signatureUrl = techSignatures[name];
          if (signatureUrl != null && signatureUrl.isNotEmpty) {
            return TextCellValue(signatureUrl);
          } else {
            return TextCellValue("No signature");
          }
        }),
      ]);

      // Make "Signatures" bold
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: signatureRowIndex,
                ),
              )
              .cellStyle =
          boldStyle;

      // Insert empty row spacing
      sheet.appendRow([]);

      // Pictures row
      final picturesRowIndex = sheet.maxRows;
      sheet.appendRow([
        TextCellValue("Pictures"),
        ...techNames.map((name) {
          final pictureUrl = techPictures[name]; // <-- We must get this from DB
          if (pictureUrl != null && pictureUrl.isNotEmpty) {
            return TextCellValue(pictureUrl);
          } else {
            return TextCellValue("No picture");
          }
        }),
      ]);
      // Make "Pictures" bold
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: picturesRowIndex,
                ),
              )
              .cellStyle =
          boldStyle;

      // // Remarks row
      // final remarksRowIndex = sheet.maxRows;
      // sheet.appendRow([
      //   TextCellValue("Remarks"),
      //   ...techNames.map((name) {
      //     final remarks = technicianRemarks[name];
      //     if (remarks != null && remarks.trim().isNotEmpty) {
      //       return TextCellValue(remarks);
      //     } else {
      //       return TextCellValue("No Remarks");
      //     }
      //   }),
      // ]);
      // Make "Pictures" bold
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: picturesRowIndex,
                ),
              )
              .cellStyle =
          boldStyle;

      int startRow = sheet.maxRows;
      // ---------------------------------------------------------
      // ADD BLANK SPACING
      // ---------------------------------------------------------
      sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow),
      );
      sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 1),
      );
      // ---------------------------------------------------------
      // TECHNICIANS INSPECTED ROW
      // ---------------------------------------------------------
      final inspectedRowIndex = sheet.maxRows;

      sheet.appendRow([
        TextCellValue("Technicians Inspected"),
        TextCellValue(techNames.length.toString()),
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: inspectedRowIndex,
                ),
              )
              .cellStyle =
          boldStyle;
      // ---------------------------------------------------------
      // COUNT ONHAND & DEFECTIVE (based on the table actually written to sheet)
      // ---------------------------------------------------------
      int onhandCount = 0, defectiveCount = 0, missingCount = 0;

      // table: Map<String, Map<String, String>> where keys are tool names
      for (final toolEntry in table.entries) {
        final statusesByTech = toolEntry.value;
        for (final tech in techNames) {
          final status = statusesByTech[tech] ?? "None";
          if (status == "Onhand") onhandCount++;
          if (status == "Defective") defectiveCount++;
          if (status == "Missing") missingCount++;
        }
      }

      // ONHAND ROW
      sheet.appendRow([
        TextCellValue("Onhand"),
        TextCellValue(onhandCount.toString()),
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: sheet.maxRows - 1,
                ),
              )
              .cellStyle =
          boldStyle;

      // DEFECTIVE ROW
      sheet.appendRow([
        TextCellValue("Defective"),
        TextCellValue(defectiveCount.toString()),
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: sheet.maxRows - 1,
                ),
              )
              .cellStyle =
          boldStyle;

      sheet.appendRow([
        TextCellValue("Missing"),
        TextCellValue(missingCount.toString()),
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: sheet.maxRows - 1,
                ),
              )
              .cellStyle =
          boldStyle;

      final dir = Directory("/storage/emulated/0/Download");
      final fileName = "Tools-Audit-${now.month}-${now.day}-${now.year}.xlsx";
      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(excel.encode()!);

      setState(() {
        _lastExportedFilePath = file.path;
        _lastExportType = 'Excel';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Excel exported successfully\n$fileName"),
            backgroundColor: const Color(0xFF003E70),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => _openFile(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Export error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<List<dynamic>> fetchTodayRows() async {
    final supabase = Supabase.instance.client;

    // Convert device date to midnight start & end (local time)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Convert to ISO8601 for Supabase filter
    final startIso = startOfDay.toUtc().toIso8601String();
    final endIso = endOfDay.toUtc().toIso8601String();

    final rows = await supabase
        .from('technician_tools')
        .select()
        .gte('checked_at', startIso)
        .lt('checked_at', endIso);

    return rows;
  }

  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error opening file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open file: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<dynamic>> fetchTodayRowsWithJoins() async {
    final supabase = Supabase.instance.client;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));

    return await supabase
        .from('technician_tools')
        .select('''
        technicians:technicians!technician_tools_technician_id_fkey(
          name, 
          e_signature,
          pictures
        ),
        tools:tools!technician_tools_tools_id_fkey(name, category),
        status,
        checked_at,
        last_updated_at
      ''')
        .gte('checked_at', start.toIso8601String())
        .lt('checked_at', end.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 62, 112),
        title: const Text("Export Data", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.upload_file,
              size: 80,
              color: Color.fromARGB(255, 0, 62, 112),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Tools Audit Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Card(
              // Excel Export Card
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: InkWell(
                onTap: _exporting ? null : exportExcel,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.table_chart,
                          size: 32,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Export as Excel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click here to export excel file',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            if (_exporting) ...[
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text('Exporting...'),
            ],

            if (_lastExportedFilePath != null && !_exporting) ...[
              const SizedBox(height: 30),
              TextButton.icon(
                onPressed: () => _openFile(_lastExportedFilePath!),
                icon: const Icon(Icons.visibility),
                label: Text('View Last Export ($_lastExportType)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF003E70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
