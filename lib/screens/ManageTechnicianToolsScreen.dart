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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
  }

  Future<void> _fetchTechnicianTools() async {
    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final technicianId = widget.technician?['id'];

    try {
      // Get all tools
      final allTools = await supabase.from('tools').select();

      // Get assigned tools for this technician
      final assignedTools = await supabase
          .from('technician_tools')
          .select('tool_id, has_tool')
          .eq('technician_id', technicianId);

      // Combine them
      final combined = allTools.map<Map<String, dynamic>>((tool) {
        final match = assignedTools.firstWhere(
          (a) => a['tool_id'] == tool['id'],
          orElse: () => {'has_tool': false},
        );
        return {
          'id': tool['id'],
          'tool_name': tool['tool_name'],
          'has_tool': match['has_tool'] ?? false,
        };
      }).toList();

      setState(() {
        _tools = combined;
      });
    } catch (e) {
      print('Error fetching technician tools: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateToolStatus(int toolId, bool hasTool) async {
    final supabase = Supabase.instance.client;
    final technicianId = widget.technician?['id'];

    try {
      await supabase.from('technician_tools').upsert({
        'technician_id': technicianId,
        'tool_id': toolId,
        'has_tool': hasTool,
      });
    } catch (e) {
      print('Error updating tool status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final technicianName = widget.technician?['name'] ?? 'Technician';

    return Scaffold(
      appBar: AppBar(title: Text('$technicianName\'s Tools')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tools.length,
              itemBuilder: (context, index) {
                final tool = _tools[index];
                return CheckboxListTile(
                  title: Text(tool['tool_name']),
                  value: tool['has_tool'],
                  onChanged: (value) {
                    setState(() {
                      tool['has_tool'] = value!;
                    });
                    _updateToolStatus(tool['id'], value!);
                  },
                );
              },
            ),
    );
  }
}
