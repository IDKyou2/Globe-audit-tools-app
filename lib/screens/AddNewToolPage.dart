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
  String? _selectedStatus, _selectedtoolCategory;
  XFile? _pickedImage;

  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  /// 📸 Pick image from gallery or camera
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  /// 💾 Upload image to Supabase Storage and return public URL
  Future<String?> _uploadImage(String toolName) async {
    if (_pickedImage == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final fileExt = _pickedImage!.path.split('.').last;
      final fileName =
          '${toolName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'public/$fileName';

      await supabase.storage
          .from('tools')
          .upload(
            filePath,
            File(_pickedImage!.path),
            fileOptions: const FileOptions(upsert: true),
          );

      // ✅ Return public image URL
      final publicUrl = supabase.storage.from('tools').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Image upload failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      return null;
    }
  }

  /// 🧩 Add tool entry to the database
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
      // ⬆ Upload image if selected
      final imageUrl = await _uploadImage(name);

      // 🧾 Insert tool record with image_url
      await supabase.from('tools').insert({
        'category': category,
        'name': name,
        'status': status,
        'image_url': imageUrl, // ✅ Add image URL
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tool added successfully!')),
        );

        // Reset form
        _toolNameController.clear();
        setState(() {
          _selectedtoolCategory = null;
          _selectedStatus = null;
          _pickedImage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error adding tool: $e');
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
                // 📸 Image picker section
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _pickedImage == null
                        ? const Center(child: Text('Tap to select tool image'))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🧾 Tool category
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
