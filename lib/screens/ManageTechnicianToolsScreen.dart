// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<Map<String, dynamic>> _tools = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
  }

  /// Fetch all tools and mark which ones this technician has on hand
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
          .select('tools_id, is_onhand')
          .eq('technician_id', technicianId);

      final combined = allTools.map<Map<String, dynamic>>((tool) {
        final match = assignedTools.firstWhere(
          (a) => a['tools_id'] == tool['tools_id'],
          orElse: () => {'is_onhand': 'No'},
        );

        return {
          'tools_id': tool['tools_id'],
          'name': tool['name'],
          'category': tool['category'],
          'is_onhand': match['is_onhand'] ?? 'No',
          'original_is_onhand': match['is_onhand'] ?? 'No',
        };
      }).toList();

      setState(() {
        _tools = combined;
        _hasChanges = false;
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
      final changedTools = _tools.where((tool) {
        return tool['is_onhand'] != tool['original_is_onhand'];
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

      final updates = changedTools
          .map(
            (tool) => {
              'technician_id': technicianId,
              'tools_id': tool['tools_id'],
              'is_onhand': tool['is_onhand'],
            },
          )
          .toList();

      await _supabase.from('technician_tools').upsert(updates);

      for (var tool in _tools) {
        tool['original_is_onhand'] = tool['is_onhand'];
      }

      if (!mounted) return;
      setState(() => _hasChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${changedTools.length} changes'),
          backgroundColor: Colors.green,
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
      return tool['is_onhand'] != tool['original_is_onhand'];
    });

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  /// Build tools by category
  Widget _buildCategoryTools(String category) {
    final filteredTools = _tools
        .where((tool) => tool['category'] == category)
        .toList();

    if (filteredTools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No $category tools found',
          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          category,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const Divider(),
        ...filteredTools.map((tool) {
          return CheckboxListTile(
            title: Text(tool['name'] ?? 'Unnamed tool'),
            value: tool['is_onhand'] == 'Yes',
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    final newStatus = value ? 'Yes' : 'No';

                    setState(() {
                      tool['is_onhand'] = newStatus;
                    });

                    _checkForChanges();
                  },
          );
        }),
      ],
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
        const Text(
          'Tools On-hand',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Changes'),
            )
          : null,
    );
  }
}
