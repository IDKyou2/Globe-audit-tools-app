// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportOptionsPage extends StatefulWidget {
  const ExportOptionsPage({super.key});
  

  @override
  State<ExportOptionsPage> createState() => _ExportOptionsPageState();
}

class _ExportOptionsPageState extends State<ExportOptionsPage> {
  bool _exporting = false;
  String? _lastExportedFilePath;
  String? _lastExportType;
  

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

      final rows = await supabase.from('technician_tools').select('''
      technicians:technicians!technician_tools_technician_id_fkey(name, updated_at, e_signature),
      tools:tools!technician_tools_tools_id_fkey(name, category),
      status
    ''');

      final techMap = <String, DateTime>{};
      final techSignatures = <String, String?>{};

      for (final r in rows) {
        final name = r['technicians']['name'];
        final createdAt = DateTime.parse(r['technicians']['updated_at']);
        final signature = r['technicians']['e_signature'];

        techMap[name] = createdAt;
        techSignatures[name] = signature;
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

      // Add signatures section - aligned with technician columns
      final signatureRow = sheet.maxRows + 2;

      sheet.appendRow([]);

      sheet.appendRow([
        TextCellValue("Signature:"),
        ...techNames.map((name) {
          final signatureUrl = techSignatures[name];
          if (signatureUrl != null && signatureUrl.isNotEmpty) {
            return TextCellValue(signatureUrl);
          } else {
            return TextCellValue("No signature");
          }
        }),
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: signatureRow + 1,
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
            content: Text("Excel exported successfully!\n$fileName"),
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

  //PDF
  Future<void> exportPDF() async {
    setState(() => _exporting = true);

    try {
      final supabase = Supabase.instance.client;

      final rows = await supabase.from('technician_tools').select('''
      technicians:technicians!technician_tools_technician_id_fkey(name, updated_at, e_signature),
      tools:tools!technician_tools_tools_id_fkey(name, category),
      status
    ''');

      final techMap = <String, DateTime>{};
      final techSignatures = <String, String?>{};

      for (final r in rows) {
        final name = r['technicians']['name'];
        final createdAt = DateTime.parse(r['technicians']['updated_at']);
        final signature = r['technicians']['e_signature'];

        techMap[name] = createdAt;
        techSignatures[name] = signature;
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

      // Download signature images
      final signatureImages = <String, pw.MemoryImage?>{};
      for (final techName in techNames) {
        final signatureUrl = techSignatures[techName];
        if (signatureUrl != null && signatureUrl.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(signatureUrl));
            if (response.statusCode == 200) {
              signatureImages[techName] = pw.MemoryImage(response.bodyBytes);
              debugPrint("✅ Downloaded signature for $techName");
            }
          } catch (e) {
            debugPrint("❌ Error downloading signature for $techName: $e");
            signatureImages[techName] = null;
          }
        } else {
          signatureImages[techName] = null;
        }
      }

      // Create PDF
      final pdf = pw.Document();
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            final widgets = <pw.Widget>[];

            widgets.add(
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Tools Audit Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );

            widgets.add(
              pw.Text(
                'Generated: ${now.month}/${now.day}/${now.year}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );

            widgets.add(pw.SizedBox(height: 20));

            for (final category in sortedCategories) {
              final sortedTools = categorizedTools[category]!.toList()..sort();

              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.blue900,
                  child: pw.Text(
                    category,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              );

              widgets.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    ...{
                      for (var i = 0; i < techNames.length; i++)
                        i + 1: const pw.FlexColumnWidth(1),
                    },
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Tool Name',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        ...techNames.map(
                          (name) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              name,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...sortedTools.map((tool) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(tool),
                          ),
                          ...techNames.map((tech) {
                            final status = table[tool]![tech]!;
                            final color = status == 'Onhand'
                                ? PdfColors.green
                                : status == 'Missing'
                                ? PdfColors.orange
                                : status == 'Defective'
                                ? PdfColors.red
                                : PdfColors.grey;

                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                status,
                                style: pw.TextStyle(
                                  color: color,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              );

              widgets.add(pw.SizedBox(height: 16));
            }

            widgets.add(pw.SizedBox(height: 20));
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.blue900,
                child: pw.Text(
                  'Technician Signatures',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            );

            widgets.add(pw.SizedBox(height: 10));

            final signatureWidgets = <pw.Widget>[];
            for (final techName in techNames) {
              final signatureImage = signatureImages[techName];

              signatureWidgets.add(
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        techName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        height: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: signatureImage != null
                            ? pw.Image(signatureImage, fit: pw.BoxFit.contain)
                            : pw.Center(
                                child: pw.Text(
                                  'No signature',
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );

              if (techName != techNames.last) {
                signatureWidgets.add(pw.SizedBox(width: 10));
              }
            }

            widgets.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: signatureWidgets,
              ),
            );

            return widgets;
          },
        ),
      );

      final dir = Directory("/storage/emulated/0/Download");
      final fileName = "Tools-Audit-${now.month}-${now.day}-${now.year}.pdf";
      final file = File("${dir.path}/$fileName");

      await file.writeAsBytes(await pdf.save());

      setState(() {
        _lastExportedFilePath = file.path;
        _lastExportType = 'PDF';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF exported successfully!\n$fileName"),
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
            const SizedBox(height: 10),
            const Text(
              'Choose your preferred format',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Excel Export Card
            Card(
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
                              'Editable spreadsheet with signature URLs',
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

            /*
            // PDF Export Card
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: InkWell(
                onTap: _exporting ? null : exportPDF,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf,
                          size: 32,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Export as PDF',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Professional report with embedded signatures',
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
            */
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
