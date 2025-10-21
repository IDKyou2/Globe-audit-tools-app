// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddNewToolPage extends StatefulWidget {
  const AddNewToolPage({super.key});

  @override
  State<AddNewToolPage> createState() => _AddNewToolPageState();
}

class _AddNewToolPageState extends State<AddNewToolPage> {
  final _toolNameController = TextEditingController();
  String? _selectedStatus, _selectedtoolCategory;

  bool _isLoading = false;
  List<dynamic> _technicians = [];

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.from('technicians').select();
      setState(() => _technicians = response);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching technicians: $e')));
    }
  }

  Future<void> _addTool() async {
    final supabase = Supabase.instance.client;

    final category = _selectedtoolCategory;
    final name = _toolNameController.text.trim();

    final status = _selectedStatus;

    if (category == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await supabase.from('tools').insert({
        'category': category,
        'name': name,
        'status': status,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tool added successfully!')),
        );

        _toolNameController.clear();
        setState(() {
          _selectedtoolCategory = null;
          _selectedStatus = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding tool: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _toolNameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Tool')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedtoolCategory,
                  decoration: const InputDecoration(
                    labelText: 'Tool Type *',
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
                  onChanged: (value) =>
                      setState(() => _selectedtoolCategory = value),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _toolNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tool Name *',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OK', child: Text('OK')),
                    DropdownMenuItem(value: 'Missing', child: Text('Missing')),
                    DropdownMenuItem(
                      value: 'Defective',
                      child: Text('Defective'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),

                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _addTool,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tool'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
