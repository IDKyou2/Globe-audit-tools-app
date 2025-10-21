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
  List<Map<String, dynamic>> _tools = [];
  bool _loading = true;
  Set<String> _updatingTools = <String>{}; // Track tools being updated

  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
  }

  /// ✅ Fetch all tools and mark which ones this technician has on hand
  Future<void> _fetchTechnicianTools() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    final technicianId = widget.technician?['id'];
    if (technicianId == null) {
      print('❌ No technician ID provided');
      setState(() => _loading = false);
      return;
    }

    try {
      // Get all tools
      final allTools = await supabase.from('tools').select();

      // Get this technician's assigned tools
      final assignedTools = await supabase
          .from('technician_tools')
          .select('tools_id, is_onhand')
          .eq('technician_id', technicianId);

      // Merge both lists
      final combined = allTools.map<Map<String, dynamic>>((tool) {
        final match = assignedTools.firstWhere(
          (a) => a['tools_id'] == tool['tools_id'],
          orElse: () => {'is_onhand': 'No'},
        );
        return {
          'tools_id': tool['tools_id'],
          'name': tool['name'],
          'is_onhand': match['is_onhand'] ?? 'No',
        };
      }).toList();

      setState(() {
        _tools = combined;
      });
    } catch (e) {
      print('❌ Error fetching technician tools: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// ✅ Update the tool's on-hand status (now fully async)
  Future<void> _updateToolStatus(String toolId, String newStatus) async {
    final supabase = Supabase.instance.client;
    final technicianId = widget.technician?['id'] as String?;

    if (_updatingTools.contains(toolId)) return;

    setState(() => _updatingTools.add(toolId));

    try {
      await supabase.from('technician_tools').upsert({
        'technician_id': technicianId,
        'tools_id': toolId,
        'is_onhand': newStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Updated to $newStatus'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating tool status: $e');

      if (mounted) {
        setState(() {
          final index = _tools.indexWhere((t) => t['id'] == toolId);
          if (index != -1) {
            _tools[index]['is_onhand'] = newStatus == 'Yes' ? 'No' : 'Yes';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update tool'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingTools.remove(toolId));
      }
    }
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
              child: _tools.isEmpty
                  ? const Center(child: Text('No tools found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tools.length,
                      itemBuilder: (context, index) {
                        final tool = _tools[index];
                        final isUpdating = _updatingTools.contains(
                          tool['tools_id'],
                        );

                        return CheckboxListTile(
                          title: Text(tool['name'] ?? 'Unnamed tool'),
                          subtitle: isUpdating
                              ? const Text(
                                  'Updating...',
                                  style: TextStyle(fontSize: 12),
                                )
                              : null,
                          value: tool['is_onhand'] == 'Yes',
                          onChanged: isUpdating
                              ? null
                              : (bool? value) {
                                  if (value == null) return;

                                  final newStatus = value ? 'Yes' : 'No';

                                  // Optimistic UI update
                                  setState(() {
                                    tool['is_onhand'] = newStatus;
                                  });

                                  // Fire-and-forget update (non-blocking)
                                  _updateToolStatus(
                                    tool['tools_id'],
                                    newStatus,
                                  );
                                },
                        );
                      },
                    ),
            ),
    );
  }
}
