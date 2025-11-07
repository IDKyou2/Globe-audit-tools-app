// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
//import 'dart:io';
//import 'package:mobile_scanner/mobile_scanner.dart';

class ManageTechnicianToolsScreen extends StatefulWidget {
  final Map<String, dynamic>? technician;

  const ManageTechnicianToolsScreen({super.key, this.technician});

  @override
  State<ManageTechnicianToolsScreen> createState() =>
      _ManageTechnicianToolsScreenState();
}

class _ManageTechnicianToolsScreenState
    extends State<ManageTechnicianToolsScreen> {
  final _supabase = Supabase.instance.client;

  String? _scannedCode;
  //MobileScannerController? _scannerController;

  List<Map<String, dynamic>> _tools = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  final ImagePicker _picker = ImagePicker();

  // Track which categories are expanded
  final Map<String, bool> _expandedCategories = {
    /*
    'PPE': false,
    'GPON Tools': false,
    'Common Tools': false,
    'Additional Tools': false,
    */
  };

  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
  }

  Future<void> _fetchTechnicianTools() async {
    setState(() => _loading = true);

    final technicianId = widget.technician?['id'];
    if (technicianId == null) {
      debugPrint('❌ No technician ID provided');
      setState(() => _loading = false);
      return;
    }

    try {
      // Fetch all available tools
      final allTools = await _supabase
          .from('tools')
          .select('tools_id, name, category');

      // Fetch only the technician's assigned tools with their status
      final assignedTools = await _supabase
          .from('technician_tools')
          .select('tools_id, status')
          .eq('technician_id', technicianId);

      // Combine both lists
      final combined = allTools.map<Map<String, dynamic>>((tool) {
        final match = assignedTools.firstWhere(
          (a) => a['tools_id'] == tool['tools_id'],
          orElse: () => {'status': 'None'},
        );

        return {
          'tools_id': tool['tools_id'],
          'name': tool['name'],
          'category': tool['category'],
          'status': match['status'] ?? 'None',
          'original_status': match['status'] ?? 'None',
        };
      }).toList();

      setState(() {
        _tools = combined;
        _hasChanges = false;

        // dynamic categories - default collapsed
        final categories = combined.map((t) => t['category'] as String).toSet();
        _expandedCategories.clear();
        for (var c in categories) {
          _expandedCategories[c] = false;
        }
      });
    } catch (e) {
      debugPrint('❌ Error fetching technician tools: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load tools'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Save all changes to the database
  Future<void> _saveChanges() async {
    final technicianId = widget.technician?['id'];
    if (technicianId == null || _saving) return;
    setState(() => _saving = true);

    try {
      // Find tools where the status was changed
      final changedTools = _tools.where((tool) {
        return tool['status'] != tool['original_status'];
      }).toList();

      if (changedTools.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            duration: Duration(milliseconds: 800),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      // Prepare updated data for Supabase
      final updates = changedTools
          .map(
            (tool) => {
              'technician_id': technicianId,
              'tools_id': tool['tools_id'],
              'status': tool['status'],
            },
          )
          .toList();

      await _supabase.from('technician_tools').upsert(updates);

      // Update local copies
      for (var tool in _tools) {
        tool['original_status'] = tool['status'];
      }

      if (!mounted) return;
      setState(() => _hasChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${changedTools.length} changes'),
          backgroundColor: const Color(0xFF003E70),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error saving changes: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save changes'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Check if there are unsaved changes
  void _checkForChanges() {
    final hasChanges = _tools.any((tool) {
      return tool['status'] != tool['original_status'];
    });

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  /// Get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'PPE':
        return Icons.security;
      case 'GPON Tools':
        return Icons.settings_input_antenna;
      case 'Common Tools':
        return Icons.build;
      case 'Additional Tools':
        return Icons.construction;
      default:
        return Icons.category;
    }
  }

  /// Open camera to capture image
  Future<void> _openCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build tools by category with dropdown
  Widget _buildCategoryTools(String category) {
    final filteredTools =
        _tools.where((tool) => tool['category'] == category).toList()..sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );

    if (filteredTools.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedCategories[category] ?? false;
    //final toolCount = filteredTools.length;
    //final okCount = filteredTools.where((t) => t['status'] == 'OK').length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: Column(
        children: [
          // Dropdown header
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 62, 112),
                borderRadius: isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      )
                    : BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        /*
                        Text(
                          '$okCount / $toolCount tools',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        */
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Tools list with labels header (shown when expanded)
          if (isExpanded) ...[
            // Column Headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Tool Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        Text(
                          'Onhand',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'None',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Missing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Defective',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tool rows
            ...filteredTools.map((tool) {
              final currentStatus = tool['status'] ?? 'None';
              final hasChanged = tool['status'] != tool['original_status'];

              return Container(
                decoration: BoxDecoration(
                  color: hasChanged ? Colors.blue.shade50 : null,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Tool name
                    Expanded(
                      flex: 3,
                      child: Text(
                        tool['name'] ?? 'Unnamed tool',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Checkboxes
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Onhand
                          Checkbox(
                            value: tool['status'] == 'Onhand',
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      tool['status'] = value == true
                                          ? 'Onhand'
                                          : 'None';
                                      print(
                                        "Tool ${tool['tools_id']} set to ${tool['status']}",
                                      );
                                    });
                                    _checkForChanges();
                                  },
                            activeColor: Colors.green,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),

                          // None
                          Checkbox(
                            value: currentStatus == 'None',
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == true) {
                                      setState(() {
                                        tool['status'] = 'None';
                                      });
                                      _checkForChanges();
                                    }
                                  },
                            activeColor: Colors.grey,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),

                          // Missing
                          Checkbox(
                            value: currentStatus == 'Missing',
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == true) {
                                      setState(() {
                                        tool['status'] = 'Missing';
                                      });
                                      _checkForChanges();
                                    }
                                  },
                            activeColor: Colors.orange,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),

                          // Defective
                          Checkbox(
                            value: currentStatus == 'Defective',
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == true) {
                                      setState(() {
                                        tool['status'] = 'Defective';
                                      });
                                      _checkForChanges();
                                    }
                                  },
                            activeColor: Colors.red,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Build the list of tools organized by category
  Widget _buildToolsList() {
    if (_tools.isEmpty) {
      return const Center(child: Text('No tools found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scanner Section (Updated)
        Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 20),
          child: InkWell(
            onTap: _showScanner,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 62, 112),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _scannedCode != null
                              ? 'Last scan: $_scannedCode'
                              : 'Tap to scan',
                          style: TextStyle(
                            fontSize: 14,
                            color: _scannedCode != null
                                ? Colors.green
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _scannedCode != null
                        ? Icons.check_circle
                        : Icons.arrow_forward_ios,
                    color: _scannedCode != null
                        ? Colors.green
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Tools Onhand Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All tools',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                final allExpanded = _expandedCategories.values.every((e) => e);
                setState(() {
                  _expandedCategories.updateAll((key, value) => !allExpanded);
                });
              },
              icon: Icon(
                _expandedCategories.values.every((e) => e)
                    ? Icons.unfold_less
                    : Icons.unfold_more,
              ),
              label: Text(
                _expandedCategories.values.every((e) => e)
                    ? 'Collapse All'
                    : 'Expand All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCategoryTools('PPE'),
        _buildCategoryTools('GPON Tools'),
        _buildCategoryTools('Common Tools'),
        _buildCategoryTools('Additional Tools'),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  /// Show QR/Barcode scanner
  Future<void> _showScanner() async {
    /*
    final scannerController = MobileScannerController();
    bool scanned = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 0, 62, 112),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Scan QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () async {
                            // 👇 Stop camera before closing
                            await scannerController.stop();
                            await scannerController.dispose();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Scanner View
                  Expanded(
                    child: MobileScanner(
                      controller: scannerController,
                      onDetect: (capture) async {
                        if (scanned) return;
                        scanned = true;

                        for (final barcode in capture.barcodes) {
                          final code = barcode.rawValue;
                          if (code != null) {
                            setState(() => _scannedCode = code);

                            // 👇 Stop the scanner before closing modal
                            await scannerController.stop();
                            await scannerController.dispose();

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Scanned: $code'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            break;
                          }
                        }
                      },
                    ),
                  ),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Position the QR code or barcode within the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Just in case user swipes down to close the sheet
    await scannerController.stop();
    await scannerController.dispose();
    */
  }

  @override
  Widget build(BuildContext context) {
    final technicianName = widget.technician?['name'] ?? 'Technician';

    return Scaffold(
      appBar: AppBar(title: Text("$technicianName's Tools")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTechnicianTools,
              child: _buildToolsList(),
            ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _saveChanges,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _saving ? 'Saving...' : 'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF003E70),
            )
          : null,
    );
  }
}
