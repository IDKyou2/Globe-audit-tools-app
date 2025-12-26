// ignore_for_file: file_names, no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddNewToolPage extends StatefulWidget {
  const AddNewToolPage({super.key});

  @override
  State<AddNewToolPage> createState() => _AddNewToolPageState();
}

class _AddNewToolPageState extends State<AddNewToolPage> {
  final _toolNameController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedCategory;
  bool _isLoading = false;
  late ScrollController _scrollController;
  bool _showScrollToTop = false;

  int? _selectedFilterCategoryId;
  bool _isCategoriesLoading = true;

  List<dynamic> _tools = [];
  List<dynamic> _filteredTools = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, int> _categoriesMap = {}; // name → id for inserts

  File? _selectedImage; //
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchTools();
    _fetchCategories();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _toolNameController.dispose();
    _searchController.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  // ---------------- FETCH CATEGORIES ----------------
  Future<void> _fetchCategories() async {
    if (!mounted) return;

    setState(() => _isCategoriesLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');

      if (!mounted) return;

      // 🔹 Remove duplicates by creating a Map with ID as key
      final Map<int, Map<String, dynamic>> uniqueCategories = {};
      for (final item in data) {
        final category = Map<String, dynamic>.from(item);
        final id = category['id'] as int;
        uniqueCategories[id] = category; // This overwrites duplicates
      }

      setState(() {
        _categories = uniqueCategories.values.toList();

        _categoriesMap = {
          for (final c in _categories) c['name'] as String: c['id'] as int,
        };

        _isCategoriesLoading = false;
      });

      // 🔍 DEBUG: Print to verify no duplicates
      debugPrint("Loaded ${_categories.length} unique categories");
      for (final cat in _categories) {
        debugPrint("   - ID: ${cat['id']}, Name: ${cat['name']}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching categories: $e");
      if (mounted) {
        setState(() => _isCategoriesLoading = false);
      }
    }
  }

  // ---------------- FETCH TOOLS WITH CATEGORY JOIN ----------------
  Future<void> _fetchTools() async {
    setState(() => _isLoading = true);

    try {
      final result = await Supabase.instance.client
          .from('tools')
          .select('tools_id, name, category:categories!inner(id, name)')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _tools = result;
        _filteredTools = result;
      });
    } catch (e) {
      debugPrint('Error fetching tools: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    TextEditingController _categoryController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogLoading = false;
        String? errorMessage; //for error

        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Add Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),

              isDialogLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final name = _categoryController.text.trim();

                        if (name.isEmpty) {
                          setStateDialog(() {
                            errorMessage = 'Category name is required.';
                          });
                          return;
                        }

                        setStateDialog(() {
                          isDialogLoading = true;
                          errorMessage = null;
                        });

                        try {
                          // Check if category exists
                          final result = await Supabase.instance.client
                              .from('categories')
                              .select('id, name') // safer
                              .ilike('name', name) // case-insensitive
                              .limit(1) // avoids maybeSingle error
                              .maybeSingle();

                          if (result != null) {
                            setStateDialog(() {
                              isDialogLoading = false;
                              errorMessage =
                                  'Category already exists. Try another name.';
                            });
                            return;
                          }

                          // Insert new category
                          await Supabase.instance.client
                              .from('categories')
                              .insert({'name': name});

                          Navigator.pop(dialogContext);

                          Fluttertoast.showToast(
                            msg: "Category added successfully",
                          );

                          await _fetchCategories();
                        } catch (e) {
                          setStateDialog(() {
                            isDialogLoading = false;
                            errorMessage = 'Error adding category.';
                          });
                          if (kDebugMode) {
                            print("CATEGORY ERROR: $e");
                          }
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003E70),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddDialog() async {
    _toolNameController.clear();
    _selectedCategory = null;
    _selectedImage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        String? error;

        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Add Tool'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category
                  DropdownButtonFormField<int>(
                    value: _selectedCategory != null
                        ? _categoriesMap[_selectedCategory!]
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Tool Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final selectedName = _categories.firstWhere(
                        (c) => c['id'] == v,
                      )['name'];
                      setStateDialog(() => _selectedCategory = selectedName);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Tool Name
                  TextField(
                    controller: _toolNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tool Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              isLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003E70),
                      ),
                      onPressed: () async {
                        final name = _toolNameController.text.trim();
                        final categoryName = _selectedCategory;
                        //String? imagePath; // for pic

                        if (name.isEmpty || categoryName == null) {
                          setStateDialog(() => error = 'Fill all fields.');
                          return;
                        }

                        setStateDialog(() {
                          error = null;
                          isLoading = true;
                        });

                        try {
                          final exists = await Supabase.instance.client
                              .from('tools')
                              .select()
                              .ilike('name', name)
                              .maybeSingle();

                          if (exists != null) {
                            setStateDialog(() {
                              error = 'Tool already exists';
                              isLoading = false;
                            });
                            return;
                          }
                          //Database queery
                          await Supabase.instance.client.from('tools').insert({
                            'name': name,
                            'category_id': _categoriesMap[categoryName],
                          });

                          // if (_selectedImage != null) {
                          //   final fileName =
                          //       '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';

                          //   final storageResponse = await Supabase
                          //       .instance
                          //       .client
                          //       .storage
                          //       .from('technician_tools')
                          //       .upload(
                          //         fileName,
                          //         _selectedImage!,
                          //         fileOptions: const FileOptions(upsert: false),
                          //       );

                          //   imagePath = storageResponse;
                          // }

                          Navigator.pop(dialogContext);
                          Fluttertoast.showToast(
                            msg: 'Tool added successfully',
                            backgroundColor: Colors.green,
                          );
                          await _fetchTools();
                        } catch (e) {
                          if (kDebugMode) {
                            print("Add Dialog Error: $e");
                          }
                          setStateDialog(() {
                            error = 'Error adding tool';
                            isLoading = false;
                          });
                        }
                      },
                      child: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  // Function to update tool
  /// Returns:
  /// 'success' → OK
  /// 'exists' → name already exists
  /// 'error: ...' → error message
  Future<String> _updateTool(
    Map<String, dynamic> tool,
    String newName,
    String newCategoryName,
    String? imagePath,
  ) async {
    try {
      if (newName.isEmpty) return "empty";

      final oldName = tool['name'];
      final oldCategoryId = tool['category']?['id'];
      final newCategoryId = _categoriesMap[newCategoryName];

      // No change check (include image)
      if (newName == oldName &&
          newCategoryId == oldCategoryId &&
          imagePath == tool['image_url']) {
        return "nochange";
      }

      // Check for existing tool name (exclude current)
      final existing = await Supabase.instance.client
          .from('tools')
          .select()
          .eq('name', newName)
          .neq('tools_id', tool['tools_id']);

      if (existing.isNotEmpty) return "exists";

      // 🔹 Update tool INCLUDING image (nullable)
      await Supabase.instance.client
          .from('tools')
          .update({
            'name': newName,
            'category_id': newCategoryId,
            'image_url': imagePath, // can be null
          })
          .eq('tools_id', tool['tools_id']);

      Fluttertoast.showToast(
        msg: 'Tool updated successfully',
        backgroundColor: Colors.green,
      );
      return "success";
    } catch (e) {
      return "error: $e";
    }
  }

  Future<void> _deleteTool(String toolId) async {
    try {
      await Supabase.instance.client
          .from('tools')
          .delete()
          .eq('tools_id', toolId);
      Fluttertoast.showToast(msg: 'Tool deleted', backgroundColor: Colors.red);
      await _fetchTools();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error deleting tool: $e');
    }
  }

  Future<void> _showUpdateDialog(Map<String, dynamic> tool) async {
    final TextEditingController nameController = TextEditingController(
      text: tool['name'],
    );
    // Initialize selectedCategory as the name, not the object
    String? selectedCategory = tool['category']?['name'];
    String? inlineError;
    bool isDialogLoading = false;
    _selectedImage = null;

    // Use this inside _showUpdateDialog, before the GestureDetector
    String? existingImagePath = tool['image_url'];
    String? displayImageUrl;

    if (existingImagePath != null && existingImagePath.isNotEmpty) {
      displayImageUrl = Supabase.instance.client.storage
          .from('technician_tools')
          .getPublicUrl(existingImagePath);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Update Tool'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tool Name',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: selectedCategory != null
                        ? _categoriesMap[selectedCategory]
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final name = _categories.firstWhere(
                        (c) => c['id'] == v,
                      )['name'];
                      setStateDialog(() => selectedCategory = name);
                    },
                  ),

                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () =>
                        _pickImage(ImageSource.gallery, setStateDialog),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (displayImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      displayImageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Center(
                                              child: Text(
                                                "Failed to load image",
                                              ),
                                            );
                                          },
                                    ),
                                  )
                                : const Center(
                                    child: Text("Tap to upload image"),
                                  )),
                    ),
                  ),

                  if (inlineError != null)
                    Text(
                      inlineError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              isDialogLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003E70),
                      ),
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        final newCategoryName = selectedCategory;
                        String? imagePath =
                            tool['image_url']; // keep existing image (can be null)

                        if (newName.isEmpty || newCategoryName == null) {
                          setStateDialog(() {
                            inlineError = "Fill all fields.";
                          });
                          return;
                        }

                        setStateDialog(() {
                          inlineError = null;
                          isDialogLoading = true;
                        });

                        try {
                          // 🔹 Upload image ONLY if user selected a new one
                          if (_selectedImage != null) {
                            final fileName =
                                '${tool['tools_id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

                            await Supabase.instance.client.storage
                                .from('technician_tools')
                                .upload(
                                  fileName,
                                  _selectedImage!,
                                  fileOptions: const FileOptions(upsert: true),
                                );

                            imagePath = fileName;
                          }

                          // 🔹 Update tool (including image_path)
                          final result = await _updateTool(
                            tool,
                            newName,
                            newCategoryName,
                            imagePath, // pass image path (nullable)
                          );

                          if (!mounted) return;

                          if (result == "empty") {
                            setStateDialog(() {
                              inlineError = "Please enter a tool name.";
                              isDialogLoading = false;
                            });
                            return;
                          }

                          if (result == "exists") {
                            setStateDialog(() {
                              inlineError = "Tool name already exists!";
                              isDialogLoading = false;
                            });
                            return;
                          }

                          if (result == "nochange") {
                            Navigator.pop(dialogContext);
                            return;
                          }

                          if (result.startsWith("error:")) {
                            setStateDialog(() {
                              inlineError = result;
                              isDialogLoading = false;
                            });
                            return;
                          }

                          // ✅ SUCCESS
                          Navigator.pop(dialogContext);
                          await _fetchTools();
                        } catch (e) {
                          setStateDialog(() {
                            inlineError = "Error: $e";
                            isDialogLoading = false;
                          });
                        }
                      },

                      child: const Text(
                        "Update",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteDialog(String toolId) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Tool'),
        content: const Text('Are you sure you want to remove this tool?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), //removes dialog
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); //removes dialog
              _deleteTool(toolId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> editCategory(Map<String, dynamic> category) async {
    final TextEditingController controller = TextEditingController(
      text: category['name'],
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Edit Category'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              isLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003E70),
                      ),
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) {
                          setStateDialog(() {
                            error = 'Category name cannot be empty';
                          });
                          return;
                        }

                        setStateDialog(() {
                          error = null;
                          isLoading = true;
                        });

                        try {
                          final supabase = Supabase.instance.client;
                          final oldName = category['name'];

                          // Update category name using ID
                          await supabase
                              .from('categories')
                              .update({'name': newName})
                              .eq('id', category['id']);

                          if (!context.mounted) return;

                          Navigator.pop(dialogContext);

                          // 🔹 Update all states
                          if (mounted) {
                            setState(() {
                              // Update selected category for add dialog
                              if (_selectedCategory == oldName) {
                                _selectedCategory = newName;
                              }

                              // 🔹 Keep filter ID (don't reset it)
                              // The filter uses ID, not name, so it's safe
                            });
                          }

                          await _fetchCategories();
                          await _fetchTools();
                        } catch (e) {
                          if (kDebugMode) {
                            print("Error in editCategory function: $e");
                          }
                          setStateDialog(() {
                            error = 'Error: $e';
                            isLoading = false;
                          });
                        }
                      },
                      child: const Text(
                        'Update',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> deleteCategory(Map<String, dynamic> category) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category['name']}"? All tools in this category will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final supabase = Supabase.instance.client;
                final categoryId = category['id'];

                // Delete tools under this category
                await supabase
                    .from('tools')
                    .delete()
                    .eq('category_id', categoryId);

                // Delete the category itself
                await supabase.from('categories').delete().eq('id', categoryId);

                Fluttertoast.showToast(msg: "Category deleted");

                // Refresh data
                await _fetchCategories();
                await _fetchTools();

                // Reset filter if the deleted category was selected
                if (_selectedFilterCategoryId == categoryId) {
                  setState(() {
                    _selectedFilterCategoryId = null;
                    _filteredTools = _tools;
                  });
                }

                // Reset add dialog category selection if it matches deleted category
                if (_selectedCategory == category['name']) {
                  setState(() {
                    _selectedCategory = null;
                  });
                }
              } catch (e) {
                Fluttertoast.showToast(msg: "Error deleting category: $e");
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(
    ImageSource source,
    void Function(void Function()) setStateDialog,
  ) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      // Must rebuild the dialog UI
      setStateDialog(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.grey[850] : Colors.grey[200];
    final hintColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search tools...',
        hintStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(
          Icons.search,
          color: isDarkMode ? Colors.white : const Color(0xFF003E70),
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _filteredTools = _tools;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() {
          _filteredTools = value.isEmpty
              ? _tools
              : _tools.where((tool) {
                  final name = tool['name']?.toLowerCase() ?? '';
                  final category =
                      tool['category']?['name']?.toLowerCase() ?? '';

                  return name.contains(value.toLowerCase()) ||
                      category.contains(value.toLowerCase());
                }).toList();
        });
      },
    );
  }

  Widget _buildToolCard(tool) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final subtitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shadowColor: Colors.black.withOpacity(0.15),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF003E70),
          radius: 24,
          child: Text(
            tool['name'][0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          tool['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(tool['category']?['name'] ?? 'Uncategorized'),

        trailing: PopupMenuButton<String>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'edit') _showUpdateDialog(tool);
            if (value == 'delete') _showDeleteDialog(tool['tools_id']);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Remove', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Map<int?, List<dynamic>> _groupToolsByCategory() {
    final Map<int?, List<dynamic>> grouped = {};

    // Initialize all categories
    for (final category in _categories) {
      grouped[category['id'] as int?] = [];
    }

    // Assign tools to their categories
    for (final tool in _filteredTools) {
      final categoryId = tool['category']?['id'] as int?;
      grouped.putIfAbsent(categoryId, () => []);
      grouped[categoryId]!.add(tool);
    }

    return grouped;
  }

  //Search tools
  Widget _buildToolList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF003E70)),
      );
    }

    final groupedTools = _groupToolsByCategory();

    // Map of categoryId → category object for easy lookup
    final Map<int?, Map<String, dynamic>> categoryMap = {
      for (final c in _categories) c['id'] as int?: c,
    };

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      children: groupedTools.entries.expand((entry) {
        final categoryId = entry.key;
        final toolsInCategory = entry.value;
        final categoryName =
            categoryMap[categoryId]?['name'] ?? 'Uncategorized';

        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$categoryName (${toolsInCategory.length})",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Color(0xFF003E70),
                      ),
                      onPressed: () => editCategory(categoryMap[categoryId]!),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => deleteCategory(categoryMap[categoryId]!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...toolsInCategory.map((tool) => _buildToolCard(tool)),
        ];
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.grey[100];

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showScrollToTop) ...[
            FloatingActionButton(
              heroTag: 'scrollUp',
              mini: true,
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400), //
                  curve: Curves.fastOutSlowIn, // more natural material curve
                );
              },
              backgroundColor: Colors.grey.shade900,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Manage Tools'),
        backgroundColor: const Color(0xFF003E70),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSearchBar(),
            ),

            //SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<int>(
                value:
                    _selectedFilterCategoryId != null &&
                        _categories.any(
                          (c) => c['id'] == _selectedFilterCategoryId,
                        )
                    ? _selectedFilterCategoryId
                    : null, // 🔹 Reset to null if category no longer exists
                decoration: InputDecoration(
                  labelText: 'Filter by Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: _isCategoriesLoading
                    ? const [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text('Loading categories...'),
                        ),
                      ]
                    : [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['name']),
                          ),
                        ),
                      ],
                onChanged: (value) {
                  setState(() {
                    _selectedFilterCategoryId = value;

                    _filteredTools = _tools.where((tool) {
                      final categoryId = tool['category']?['id'];

                      return _selectedFilterCategoryId == null ||
                          categoryId == _selectedFilterCategoryId;
                    }).toList();
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            // Add New Category button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end, // Align both buttons to right
                children: [
                  // Add New Category Button
                  ElevatedButton.icon(
                    onPressed:
                        _showAddCategoryDialog, // <-- create this function
                    icon: const Icon(Icons.add, size: 20, color: Colors.black),
                    label: const Text(
                      'Add New Category',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        // <-- OUTLINE COLOR
                        color: Color(0xFF003E70),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Add New Tool Button
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                    label: const Text(
                      'Add New Tool',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003E70),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Tool list
            Expanded(child: _buildToolList()),
          ],
        ),
      ),
    );
  }
}
