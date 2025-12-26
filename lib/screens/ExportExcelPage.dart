// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      Fluttertoast.showToast(msg: "Storage permission denied");
      return;
    }

    setState(() => _exporting = true);

    try {
      final supabase = Supabase.instance.client;
      final nowUtc = DateTime.now().toUtc();

      // UTC-safe start/end of today
      final start = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final end = start.add(const Duration(days: 1));
      final formattedDate = DateFormat('MMMM d, yyyy').format(nowUtc);

      // ---------------- FETCH TODAY'S STATUS ----------------
      final todayRows = await supabase
          .from('technician_tools')
          .select('''
          technician_id,
          tools_id,
          status,
          last_updated_at,
          technicians:technician_tools_technician_id_fkey(
            id,
            name,
            e_signature,
            pictures
          ),
          tools:technician_tools_tools_id_fkey(
            name,
            categories:tools_category_id_fkey(name)
          )
        ''')
          .gte('last_updated_at', start.toIso8601String())
          .lt('last_updated_at', end.toIso8601String());

      if (todayRows.isEmpty) {
        Fluttertoast.showToast(msg: "No inspections found for today");
        return;
      }

      // ---------------- FETCH ALL TOOLS ----------------
      final allToolsRows = await supabase
          .from('tools')
          .select('name, categories:categories!inner(name)');

      // ---------------- FETCH REMARKS ----------------
      final remarkRows = await supabase
          .from('technician_remarks')
          .select('technician_id, remarks');

      final Map<String, String> remarksByTechId = {
        for (final r in remarkRows)
          r['technician_id'].toString(): r['remarks'] ?? '',
      };

      // ---------------- TECHNICIAN METADATA ----------------
      final Map<String, DateTime> techLatest = {};
      final Map<String, String?> techSignatures = {};
      final Map<String, String?> techPictures = {};
      final Map<String, String> techRemarks = {};

      for (final r in todayRows) {
        final tech = r['technicians'];
        if (tech == null) continue;

        final techId = tech['id'].toString();
        final name = tech['name'];
        final updatedAt = DateTime.parse(r['last_updated_at']);

        if (!techLatest.containsKey(name) ||
            updatedAt.isAfter(techLatest[name]!)) {
          techLatest[name] = updatedAt;
          techSignatures[name] = tech['e_signature'];
          techPictures[name] = tech['pictures'];
          techRemarks[name] = remarksByTechId[techId] ?? '';
        }
      }

      final techNames = techLatest.keys.toList()..sort();

      // ---------------- CATEGORIZE TOOLS ----------------
      final Map<String, Set<String>> categorizedTools = {};
      for (final t in allToolsRows) {
        final toolName = t['name'];
        final category = t['categories']?['name'] ?? 'Uncategorized';
        categorizedTools.putIfAbsent(category, () => <String>{});
        categorizedTools[category]!.add(toolName);
      }

      // ---------------- BUILD TOOL STATUS TABLE ----------------
      final Map<String, Map<String, String>> table = {};
      for (final tools in categorizedTools.values) {
        for (final tool in tools) {
          table[tool] = {for (final tech in techNames) tech: 'None'};
        }
      }
      // Overwrite with today’s actual statuses
      for (final r in todayRows) {
        final tech = r['technicians']?['name'];
        final tool = r['tools']?['name'];
        final status = r['status'] ?? 'None';
        if (tech != null && tool != null) table[tool]![tech] = status;
      }

      // ---------------- CREATE EXCEL ----------------
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      final bold = CellStyle(bold: true);
      final onhandStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.green900,
      );
      final defectiveStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.red,
      );
      final missingStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.orange,
      );

      // Date header
      sheet.appendRow([TextCellValue(formattedDate)]);
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
              .cellStyle =
          bold;
      sheet.appendRow([TextCellValue('')]);

      // Technician header
      sheet.appendRow([TextCellValue(''), ...techNames.map(TextCellValue.new)]);
      for (int i = 0; i <= techNames.length; i++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
                .cellStyle =
            bold;
      }

      // Tool rows
      for (final category in categorizedTools.keys.toList()..sort()) {
        sheet.appendRow([TextCellValue(category)]);
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: sheet.maxRows - 1,
                  ),
                )
                .cellStyle =
            bold;

        for (final tool in categorizedTools[category]!.toList()..sort()) {
          final rowIndex = sheet.maxRows;
          sheet.appendRow([
            TextCellValue(tool),
            ...techNames.map((t) => TextCellValue(table[tool]![t]!)),
          ]);

          for (int col = 1; col <= techNames.length; col++) {
            final value = sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: col,
                    rowIndex: rowIndex,
                  ),
                )
                .value
                .toString();
            if (value == 'Onhand') {
              sheet
                      .cell(
                        CellIndex.indexByColumnRow(
                          columnIndex: col,
                          rowIndex: rowIndex,
                        ),
                      )
                      .cellStyle =
                  onhandStyle;
            } else if (value == 'Defective') {
              sheet
                      .cell(
                        CellIndex.indexByColumnRow(
                          columnIndex: col,
                          rowIndex: rowIndex,
                        ),
                      )
                      .cellStyle =
                  defectiveStyle;
            } else if (value == 'Missing') {
              sheet
                      .cell(
                        CellIndex.indexByColumnRow(
                          columnIndex: col,
                          rowIndex: rowIndex,
                        ),
                      )
                      .cellStyle =
                  missingStyle;
            }
          }
        }
      }

      // ---------------- REMARKS / SIGNATURES / PICTURES ----------------
      void appendMetaRow(String title, Map<String, String?> source) {
        sheet.appendRow([
          TextCellValue(title),
          ...techNames.map(
            (t) => TextCellValue(
              source[t]?.isNotEmpty == true ? source[t]! : 'N/A',
            ),
          ),
        ]);
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: sheet.maxRows - 1,
                  ),
                )
                .cellStyle =
            bold;
      }

      appendMetaRow('Remarks', techRemarks);
      appendMetaRow('Signatures', techSignatures);
      appendMetaRow('Pictures', techPictures);

      // ---------------- COUNTS ----------------
      int onhand = 0, defective = 0, missing = 0;
      for (final row in table.values) {
        for (final status in row.values) {
          if (status == 'Onhand') onhand++;
          if (status == 'Defective') defective++;
          if (status == 'Missing') missing++;
        }
      }

      sheet.appendRow([TextCellValue('')]); //Blank row
      sheet.appendRow([TextCellValue('')]); //Blank row

      // Add counts
      void appendCountRow(String title, int value, CellStyle style) {
        final rowIndex = sheet.maxRows;

        sheet.appendRow([
          TextCellValue(title),
          TextCellValue(value.toString()),
        ]);

        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            style;
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            style;
      }

      appendCountRow('Onhand', onhand, bold);
      appendCountRow('Defective', defective, bold);
      appendCountRow('Missing', missing, bold);
      appendCountRow('Technicians Inspected', techNames.length, bold);

      // ---------------- SAVE FILE ----------------
      final dir = Directory('/storage/emulated/0/Download');
      final fileName =
          'Tools-Audit-${nowUtc.month}-${nowUtc.day}-${nowUtc.year}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      setState(() => _lastExportedFilePath = file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel exported successfully\n$fileName'),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () => _openFile(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
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
        .gte('last_updated_at', startIso)
        .lt('last_updated_at', endIso);

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
                label: Text('View Last Export'),
                // label: Text('View Last Export ($_lastExportType)'),
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
