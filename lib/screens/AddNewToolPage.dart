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
  String? _selectedtoolCategory;
  XFile? _pickedImage;

  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  /// 📸 Pick image from gallery or camera
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, // Optimize image size
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  /// 💾 Upload image to Supabase Storage and return public URL
  Future<String?> _uploadImage(String toolName) async {
    if (_pickedImage == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final fileExt = _pickedImage!.path.split('.').last.toLowerCase();

      // Sanitize tool name for filename
      final sanitizedName = toolName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName =
          '${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'public/$fileName';

      debugPrint('🔄 Uploading image: $filePath');

      await supabase.storage
          .from('tools')
          .upload(
            filePath,
            File(_pickedImage!.path),
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg', // Or detect based on fileExt
            ),
          );

      // ✅ Return public image URL
      final publicUrl = supabase.storage.from('tools').getPublicUrl(filePath);
      debugPrint('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Image upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// 🧩 Add tool entry to the database
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
      // ⬆ Upload image if selected
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await _uploadImage(name);
        // If image upload fails, you can decide whether to continue or stop
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // 🧾 Insert tool record with image_url
      await supabase.from('tools').insert({
        'category': category,
        'name': name,
        //'status': status,
        'image_url': imageUrl, // ✅ Can be null if no image selected
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
          // _selectedStatus = null;
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 📸 Image picker section
                GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _pickedImage != null
                            ? Colors.green
                            : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[50],
                    ),
                    child: _pickedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to select tool image',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _pickedImage = null),
                                  ),
                                ),
                              ),
                            ],
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
                    prefixIcon: Icon(Icons.settings_applications),
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
                  decoration: const InputDecoration(
                    labelText: 'Tool Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build),
                  ),
                ),

                /*
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.check_circle),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OK', child: Text('OK')),
                    DropdownMenuItem(value: 'Missing', child: Text('Missing')),
                    DropdownMenuItem(
                      value: 'Defective',
                      child: Text('Defective'),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _selectedStatus = value),
                ),
                */
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _addTool,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tool'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
