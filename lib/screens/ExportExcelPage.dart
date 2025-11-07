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

      // ✅ Include category in query
      final rows = await supabase.from('technician_tools').select('''
      technicians:technicians!technician_tools_technician_id_fkey(name),
      tools:tools!technician_tools_tools_id_fkey(name, category),
      status
    ''');

      // ✅ Distinct sorted technicians A–Z
      final techNames =
          rows.map((r) => r['technicians']['name'] as String).toSet().toList()
            ..sort();

      // ✅ Categorize and sort tools
      final Map<String, Set<String>> categorizedTools = {};

      for (final r in rows) {
        final toolName = r['tools']['name'] as String;
        final category = r['tools']['category'] as String? ?? "Uncategorized";
        categorizedTools.putIfAbsent(category, () => <String>{});
        categorizedTools[category]!.add(toolName);
      }

      final sortedCategories = categorizedTools.keys.toList()..sort();

      // ✅ Create matrix
      final Map<String, Map<String, String>> table = {};
      for (final category in sortedCategories) {
        for (final tool in categorizedTools[category]!.toList()..sort()) {
          table[tool] = {};
          for (final tech in techNames) {
            table[tool]![tech] = "None";
          }
        }
      }

      // ✅ Fill values
      for (final r in rows) {
        final tech = r['technicians']['name'];
        final tool = r['tools']['name'];
        final status = (r['status'] ?? "");

        if (status == "Onhand") {
          table[tool]![tech] = "Onhand";
        } else if (status == "Defective") {
          table[tool]![tech] = "Defective";
        } else if (status == "Missing") {
          table[tool]![tech] = "Missing";
        } else {
          table[tool]![tech] = "None";
        }
      }

      // ✅ Prepare Excel
      final excel = Excel.createExcel();
      final boldStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      final today = DateTime.now();
      final yyyy = today.year.toString();
      final mm = today.month.toString().padLeft(2, '0');
      final dd = today.day.toString().padLeft(2, '0');
      //final sheetName = "$mm-$dd-$yyyy";

      //final sheet = excel[sheetName];
      final sheet = excel['Sheet1'];

      // ✅ Header row
      sheet.appendRow([
        TextCellValue("Tools"),
        ...techNames.map((t) => TextCellValue(t)),
      ]);

      // ✅ Append categorized tools
      for (final category in sortedCategories) {
        // ✅ Category header row (bold)
        final categoryRowIndex = sheet.maxRows;

        sheet.appendRow([TextCellValue(category)]);
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: categoryRowIndex,
                  ),
                )
                .cellStyle =
            boldStyle;

        final sortedTools = categorizedTools[category]!.toList()..sort();

        for (final tool in sortedTools) {
          sheet.appendRow([
            TextCellValue(tool),
            ...techNames.map(
              (tech) => TextCellValue(table[tool]![tech] ?? "None"),
            ),
          ]);
        }
      }

      // ✅ Save Excel
      final dir = Directory("/storage/emulated/0/Download");
      final fileName = "Tools-Audit-$mm-$dd-$yyyy.xlsx";
      final path = "${dir.path}/$fileName";

      final file = File(path);
      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Excel saved!\n$path")));
      }
    } catch (e) {
      debugPrint("Export error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        child: ElevatedButton(
          onPressed: _exporting
              ? null
              : () async {
                  setState(() => _exporting = true);
                  await exportExcel();
                  setState(() => _exporting = false);
                },
          child: Text("Export to Excel"),
        ),
      ),
    );
  }
}
