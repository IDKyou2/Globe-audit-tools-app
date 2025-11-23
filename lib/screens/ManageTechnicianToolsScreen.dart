import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

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
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  List<Map<String, dynamic>> _tools = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  final Map<String, bool> _expandedCategories = {};

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
      final allTools = await _supabase
          .from('tools')
          .select('tools_id, name, category');

      final assignedTools = await _supabase
          .from('technician_tools')
          .select('tools_id, status')
          .eq('technician_id', technicianId);

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

  Future<void> _saveChanges() async {
    final technicianId = widget.technician?['id'];
    if (technicianId == null || _saving) return;
    setState(() => _saving = true);

    try {
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

      final updates = changedTools.map((tool) {
        return {
          'technician_id': technicianId,
          'tools_id': tool['tools_id'],
          'status': tool['status'],
          'last_updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('technician_tools').upsert(updates);

      for (var tool in _tools) {
        tool['original_status'] = tool['status'];
      }

      if (!mounted) return;
      setState(() => _hasChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${changedTools.length} changes'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
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

  void _checkForChanges() {
    final hasChanges = _tools.any((tool) {
      return tool['status'] != tool['original_status'];
    });

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

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

  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo captured successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sharePhoto() async {
    if (_imageFile == null) return;

    try {
      await Share.shareXFiles(
        [XFile(_imageFile!.path)],
        text: 'Technician Tools Photo',
      );
    } catch (e) {
      debugPrint('❌ Error sharing photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCategoryTools(String category) {
    final filteredTools =
        _tools.where((tool) => tool['category'] == category).toList()
          ..sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
                  (b['name'] as String).toLowerCase(),
                ),
          );

    if (filteredTools.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedCategories[category] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: Column(
        children: [
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
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
          if (isExpanded) ...[
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
                    Expanded(
                      flex: 3,
                      child: Text(
                        tool['name'] ?? 'Unnamed tool',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Checkbox(
                            value: tool['status'] == 'Onhand',
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      tool['status'] =
                                          value == true ? 'Onhand' : 'None';
                                    });
                                    _checkForChanges();
                                  },
                            activeColor: Colors.green,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
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

  Widget _buildToolsList() {
    if (_tools.isEmpty) {
      return const Center(child: Text('No tools found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        const SizedBox(height: 24),
        if (_imageFile != null) _buildCapturedPhoto(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCapturedPhoto() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 0, 62, 112),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_camera,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Captured Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: _sharePhoto,
                  tooltip: 'Share/Download Photo',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                    });
                  },
                  tooltip: 'Remove Photo',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _imageFile!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final technicianName = widget.technician?['name'] ?? 'Technician';

    return Scaffold(
      appBar: AppBar(title: Text("$technicianName's tools")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTechnicianTools,
              child: _buildToolsList(),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _takePicture,
            backgroundColor: const Color(0xFF003E70),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          if (_hasChanges) ...[
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'save',
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
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF003E70),
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}