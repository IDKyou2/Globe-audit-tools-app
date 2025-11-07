// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddNewToolPage extends StatefulWidget {
  const AddNewToolPage({super.key});

  @override
  State<AddNewToolPage> createState() => _AddNewToolPageState();
}

class _AddNewToolPageState extends State<AddNewToolPage> {
  final _toolNameController = TextEditingController();
  String? _selectedtoolCategory; //Drop down controller
  XFile? _pickedImage;
  bool _isLoading = false;

  List<dynamic> _tools = [];

  @override
  void initState() {
    super.initState();
    _fetchTools();
  }

  void _showAddToolDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Add Tool'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedtoolCategory,
                  decoration: const InputDecoration(
                    labelText: 'Tool Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PPE', child: Text('PPE')),
                    DropdownMenuItem(
                      value: 'Common Tools',
                      child: Text('Common Tools'),
                    ),
                    DropdownMenuItem(
                      value: 'GPON Tools',
                      child: Text('GPON Tools'),
                    ),
                    DropdownMenuItem(
                      value: 'Additional Tools',
                      child: Text('Additional Tools'),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) =>
                            setState(() => _selectedtoolCategory = value),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _toolNameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Tool Name *',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),

            _isLoading
                ? const SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      await _addTool();
                      Navigator.pop(context); // close dialog after add
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF003E70),
                    ),
                  ),
          ],
        );
      },
    );
  }

  /// Add tool entry to the database
  Future<void> _addTool() async {
    final supabase = Supabase.instance.client;
    final category = _selectedtoolCategory;
    final name = _toolNameController.text.trim();
    //final status = _selectedStatus;

    // Validation
    if (category == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final check = await supabase
          .from('tools')
          .select('tools_id')
          .ilike('name', name)
          .maybeSingle();

      if (check != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tool name already exists!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFB00020),
          ),
        );
        _toolNameController.clear();
        setState(() => _isLoading = false);
        return;
      }

      // 🧾 Insert tool record with image_url
      await supabase.from('tools').insert({
        'category': category,
        'name': name,
        //'status': status,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tool added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _toolNameController.clear();
        setState(() {
          _selectedtoolCategory = null;
          _pickedImage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error adding tool: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding tool: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    _fetchTools();
  }

  Future<void> _fetchTools() async {
    final supabase = Supabase.instance.client;

    setState(() => _isLoading = true);

    final result = await supabase
        .from('tools')
        .select('tools_id, name, category')
        .order('created_at', ascending: false);

    setState(() {
      _tools = result;
      _isLoading = false;
    });
  }

  Future<void> _deleteTool(String toolId) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('tools').delete().eq('tools_id', toolId);

      // refresh the list
      await _fetchTools();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tool deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editTool(Map<String, dynamic> tool) {
    final supabase = Supabase.instance.client;
    // preload form
    setState(() {
      _selectedtoolCategory = tool['category'];
      _toolNameController.text = tool['name'];
    });

    // replace add tool with update
    showDialog(
      context: context,
      builder: (_) {
        final TextEditingController editNameController = TextEditingController(
          text: tool['name'],
        );
        String editSelectedCategory = tool['category']; //for dropdown

        return AlertDialog(
          title: const Text('Edit Tool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Line Text Controller
              //TextField(controller: _editNameController),
              TextField(
                controller: editNameController,
                decoration: const InputDecoration(
                  labelText: 'Tool Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20.0),
              DropdownButtonFormField<String>(
                value: editSelectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Tool Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'PPE', child: Text('PPE')),
                  DropdownMenuItem(
                    value: 'Common Tools',
                    child: Text('Common Tools'),
                  ),
                  DropdownMenuItem(
                    value: 'GPON Tools',
                    child: Text('GPON Tools'),
                  ),
                  DropdownMenuItem(
                    value: 'Additional Tools',
                    child: Text('Additional Tools'),
                  ),
                ],
                onChanged: (value) {
                  editSelectedCategory = value!;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Update'),
              onPressed: () async {
                await supabase
                    .from('tools')
                    .update({
                      'name': editNameController.text,
                      'category': editSelectedCategory,
                    })
                    .eq('tools_id', tool['tools_id']);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tool updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                Navigator.pop(context);
                await _fetchTools(); // refresh list
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _toolNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Tool'), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tools List
              Row(
                children: [
                  const Text(
                    "Tools List",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),

                  const Spacer(), // pushes button to the end

                  ElevatedButton.icon(
                    onPressed: _showAddToolDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Tool"),
                  ),
                ],
              ),

              const Divider(),

              //const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _tools.length,
                        itemBuilder: (context, index) {
                          final tool = _tools[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            elevation: 2,
                            child: ListTile(
                              title: Text(tool['name']),
                              subtitle: Text(tool['category']),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editTool(
                                      tool,
                                    ); // <- you will implement this
                                  } else if (value == 'delete') {
                                    _deleteTool(tool['tools_id']);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              /*
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedtoolCategory,
                decoration: const InputDecoration(
                  labelText: 'Tool Category *',
                  border: OutlineInputBorder(),
                  //prefixIcon: Icon(Icons.settings_applications),
                ),
                items: const [
                  DropdownMenuItem(value: 'PPE', child: Text('PPE')),
                  DropdownMenuItem(
                    value: 'Common Tools',
                    child: Text('Common Tools'),
                  ),
                  DropdownMenuItem(
                    value: 'GPON Tools',
                    child: Text('GPON Tools'),
                  ),
                  DropdownMenuItem(
                    value: 'Additional Tools',
                    child: Text('Additional Tools'),
                  ),
                ],
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _selectedtoolCategory = value),
              ),

              const SizedBox(height: 16),
              // Box Text controller
              TextField(
                controller: _toolNameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Tool Name *',
                  border: const OutlineInputBorder(),
                  //prefixIcon: const Icon(Icons.build),
                ),
              ),

              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _addTool,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Tool',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF003E70,
                        ), // button color
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),

              const SizedBox(height: 20),
*/
            ],
          ),
        ),
      ),
    );
  }
}
