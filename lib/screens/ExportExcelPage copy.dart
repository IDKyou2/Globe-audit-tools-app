// ignore_for_file: file_names

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportExcelPage extends StatefulWidget {
  const ExportExcelPage({super.key});

  @override
  State<ExportExcelPage> createState() => _ExportExcelPageState();
}

class _ExportExcelPageState extends State<ExportExcelPage> {
  bool _exporting = false;

  Future<void> exportExcel() async {
    try {
      final supabase = Supabase.instance.client;

      // 🔹 Fetch technician + tool data including created_at for sorting
      final rows = await supabase.from('technician_tools').select('''
      technicians:technicians!technician_tools_technician_id_fkey(name, updated_at),
      tools:tools!technician_tools_tools_id_fkey(name, category),
      status
    ''');

      // 🔹 Extract technicians with created_at
      final techMap = <String, DateTime>{};

      for (final r in rows) {
        final name = r['technicians']['name'];
        final createdAt = DateTime.parse(r['technicians']['updated_at']);
        techMap[name] = createdAt; // newest overwrites, OK
      }

      // 🔹 Sort technicians by CREATED_AT (oldest → newest)
      final techNames = techMap.keys.toList()
        ..sort((a, b) => techMap[a]!.compareTo(techMap[b]!));

      // 🔹 Categorize tools
      final categorizedTools = <String, Set<String>>{};
      for (final r in rows) {
        final tool = r['tools']['name'];
        final category = r['tools']['category'] ?? "Uncategorized";

        categorizedTools.putIfAbsent(category, () => <String>{});
        categorizedTools[category]!.add(tool);
      }

      final sortedCategories = categorizedTools.keys.toList()..sort();

      // 🔹 Create table matrix
      final table = <String, Map<String, String>>{};
      for (final category in sortedCategories) {
        for (final tool in categorizedTools[category]!.toList()..sort()) {
          table[tool] = {for (var tech in techNames) tech: "None"};
        }
      }

      // 🔹 Fill table values
      for (final r in rows) {
        final tech = r['technicians']['name'];
        final tool = r['tools']['name'];
        final status = r['status'] ?? "None";

        table[tool]![tech] = status;
      }

      // 🔹 Prepare Excel
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

      // 🔹 Header row
      sheet.appendRow([
        TextCellValue("Tools"),
        ...techNames.map((t) => TextCellValue(t)),
      ]);

      // Apply header formatting
      for (var col = 0; col <= techNames.length; col++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
                .cellStyle =
            boldStyle;
      }

      // 🔹 Insert Tools + Statuses
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

          // Apply conditional color styles
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

      // 🔹 Save to Downloads
      final dir = Directory("/storage/emulated/0/Download");
      final fileName = "Tools-Audit-${now.month}-${now.day}-${now.year}.xlsx";
      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Excel saved!\n${file.path}"),
            backgroundColor: Color(0xFF001F3A),
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
    }
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
              Icons.file_download,
              size: 80,
              color: Color.fromARGB(255, 0, 62, 112),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Tools Audit to Excel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'The file will be saved in your Downloads folder',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _exporting
                  ? null
                  : () async {
                      setState(() => _exporting = true);
                      await exportExcel();
                      setState(() => _exporting = false);
                    },
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(
                _exporting ? "Exporting..." : "Export to Excel",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003E70),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
