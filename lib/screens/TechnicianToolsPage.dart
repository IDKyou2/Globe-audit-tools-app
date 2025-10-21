// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechnicianToolsPage extends StatefulWidget {
  const TechnicianToolsPage({super.key});

  @override
  State<TechnicianToolsPage> createState() => _TechnicianToolsPageState();
}

class _TechnicianToolsPageState extends State<TechnicianToolsPage> {
  final supabase = Supabase.instance.client;
  String? _selectedTechnicianId;
  List<dynamic> _technicians = [];
  List<dynamic> _tools = [];
  Map<String, bool> _toolOwnership = {}; // toolId -> true/false
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
    _fetchTools();
  }

  Future<void> _fetchTechnicians() async {
    try {
      final data = await supabase.from('technicians').select();
      setState(() => _technicians = data);
    } catch (e) {
      _showMessage('Error fetching technicians: $e');
    }
  }

  Future<void> _fetchTools() async {
    try {
      final data = await supabase.from('tools').select();
      setState(() => _tools = data);
    } catch (e) {
      _showMessage('Error fetching tools: $e');
    }
  }

  Future<void> _fetchTechnicianTools(String technicianId) async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('technician_tools')
          .select()
          .eq('technician_id', technicianId);

      // Build ownership map: mark true if technician has the tool
      final ownedToolIds = data.map((t) => t['tool_id'].toString()).toSet();
      final map = {for (var tool in _tools) tool['id'].toString(): false};
      for (var id in ownedToolIds) {
        if (map.containsKey(id)) map[id] = true;
      }

      setState(() {
        _toolOwnership = map;
      });
    } catch (e) {
      _showMessage('Error fetching technician tools: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Technician Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTechnicianId,
              decoration: const InputDecoration(
                labelText: 'Select Technician',
                border: OutlineInputBorder(),
              ),
              items: _technicians.map<DropdownMenuItem<String>>((tech) {
                return DropdownMenuItem<String>(
                  value: tech['id'].toString(),
                  child: Text(tech['name'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTechnicianId = value;
                  _toolOwnership.clear();
                });
                if (value != null) _fetchTechnicianTools(value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _tools.length,
                      itemBuilder: (context, index) {
                        final tool = _tools[index];
                        final toolId = tool['id'].toString();
                        final isChecked = _toolOwnership[toolId] ?? false;
                        return CheckboxListTile(
                          title: Text(tool['name'] ?? 'Unnamed Tool'),
                          subtitle: Text(
                            tool['description'] ?? 'No description',
                          ),
                          value: isChecked,
                          onChanged: (bool? value) {
                            setState(() {
                              _toolOwnership[toolId] = value ?? false;
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
