import 'package:flutter/material.dart';
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
  bool _isSearching = false;
  late ScrollController _scrollController;
  bool _showScrollToTop = false;
  String? _selectedFilterCategory; // null = show all

  List<dynamic> _tools = [];
  List<dynamic> _filteredTools = [];

  static const _categories = [
    'PPE',
    'Common Tools',
    'GPON Tools',
    'Additional Tools',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTools();

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

  /*
  void _showSnack(
    String message, {
    Color color = const Color(0xFF003E70),
    Color textColor = Colors.white,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  */

  void _filterTools(String query) {
    setState(() {
      _filteredTools = query.isEmpty
          ? _tools
          : _tools.where((tool) {
              final name = tool['name']?.toString().toLowerCase() ?? '';
              final category = tool['category']?.toString().toLowerCase() ?? '';
              final search = query.toLowerCase();
              return name.contains(search) || category.contains(search);
            }).toList();
    });
  }

  Future<void> _fetchTools() async {
    setState(() => _isLoading = true);
    try {
      final result = await Supabase.instance.client
          .from('tools')
          .select('tools_id, name, category')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _tools = result;
        _filteredTools = result;
      });
    } catch (e) {
      debugPrint('❌ Error fetching tools: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddDialog() async {
    _toolNameController.clear();
    _selectedCategory = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogLoading = false;
        String? errorMessage; // INLINE ERROR MESSAGE

        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Add Tool'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _toolNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tool Name *',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Tool Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => _selectedCategory = v),
                ),

                const SizedBox(height: 10),

                // === INLINE VALIDATION MESSAGE ===
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
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
                        final name = _toolNameController.text.trim();
                        final category = _selectedCategory;

                        // ========== VALIDATION ==========
                        if (name.isEmpty || category == null) {
                          setStateDialog(
                            () => errorMessage =
                                'Please fill all required fields.',
                          );
                          return;
                        }

                        setStateDialog(() {
                          isDialogLoading = true;
                          errorMessage = null;
                        });

                        try {
                          // CHECK IF TOOL NAME EXISTS
                          final exists = await Supabase.instance.client
                              .from('tools')
                              .select('tools_id')
                              .ilike('name', name)
                              .maybeSingle();

                          if (exists != null) {
                            setStateDialog(() {
                              isDialogLoading = false;
                              errorMessage =
                                  'Tool name already exists. Try another one.';
                            });
                            return;
                          }

                          // INSERT TOOL
                          await Supabase.instance.client.from('tools').insert({
                            'name': name,
                            'category': category,
                          });

                          Navigator.pop(dialogContext); // close dialog

                          Fluttertoast.showToast(
                            msg: "Tool added successfully",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                          );
                          await _fetchTools();
                          //_showSnack('Tool added successfully');
                        } catch (e) {
                          setStateDialog(() {
                            isDialogLoading = false;
                            errorMessage = 'Error: $e';
                          });
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

  // Function to update tool
  /// Returns:
  /// 'success' → OK
  /// 'exists' → name already exists
  /// 'error: ...' → error message
  Future<String> _updateTool(
    Map<String, dynamic> tool,
    String updatedName,
    String updatedCategory,
  ) async {
    try {
      if (updatedName.isEmpty) return "empty";

      // NO CHANGES
      final oldName = tool['name'];
      final oldCategory = tool['category'];
      if (updatedName == oldName && updatedCategory == oldCategory) {
        return "nochange";
      }

      // DUPLICATE NAME
      final existing = await Supabase.instance.client
          .from('tools')
          .select()
          .eq('name', updatedName)
          .neq('tools_id', tool['tools_id']);

      if (existing.isNotEmpty) return "exists";

      // UPDATE
      await Supabase.instance.client
          .from('tools')
          .update({'name': updatedName, 'category': updatedCategory})
          .eq('tools_id', tool['tools_id']);

      Fluttertoast.showToast(
        msg: "Tool updated successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
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
      //_showSnack('Tool deleted successfully', textColor: Colors.red);

      Fluttertoast.showToast(
        msg: "Tool deleted successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      await _fetchTools();
    } catch (e) {
      //_showSnack('Error deleting tool: $e', color: Colors.red);
    }
  }

  Future<void> _showUpdateDialog(Map<String, dynamic> tool) async {
    final TextEditingController nameController = TextEditingController(
      text: tool['name'],
    );
    String? selectedCategory = tool['category'];
    String? inlineError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setStateDialog) => AlertDialog(
            title: const Text('Update Tool'),
            content: Column(
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
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedCategory = v),
                ),
                const SizedBox(height: 10),
                if (inlineError != null)
                  Text(inlineError!, style: const TextStyle(color: Colors.red)),
              ],
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
                        final newCategory = selectedCategory ?? "";

                        setStateDialog(() {
                          inlineError = null;
                          isDialogLoading = true;
                        });

                        final result = await _updateTool(
                          tool,
                          newName,
                          newCategory,
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
                          Navigator.pop(dialogContext); // CLOSE DIALOG
                          return;
                        }

                        if (result.startsWith("error:")) {
                          setStateDialog(() {
                            inlineError = result;
                            isDialogLoading = false;
                          });
                          return;
                        }

                        // SUCCESS → CLOSE DIALOG
                        Navigator.pop(dialogContext);
                        //_showSnack("Tool updated successfully");
                        await _fetchTools();
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
                  final category = tool['category']?.toLowerCase() ?? '';
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
        subtitle: Text(
          tool['category'],
          style: TextStyle(color: subtitleColor, fontSize: 13),
        ),
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

  Map<String, List<dynamic>> _groupToolsByCategory() {
    final Map<String, List<dynamic>> grouped = {};

    for (var tool in _filteredTools) {
      final category = tool['category'] ?? 'Uncategorized';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(tool);
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

    if (_filteredTools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 70, color: Colors.grey[500]),
            const SizedBox(height: 10),
            Text(
              'No results found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final groupedTools = _groupToolsByCategory();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      children: groupedTools.entries.expand((entry) {
        final categoryName = entry.key;
        final toolsInCategory = entry.value;

        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
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
            // Add button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                  label: const Text(
                    'Add New Tool',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003E70),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: _selectedFilterCategory,
                decoration: InputDecoration(
                  labelText: 'Filter by Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [null, ..._categories].map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c ?? 'All Categories'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilterCategory = value;
                    _filteredTools = _tools.where((tool) {
                      if (value == null) return true; // all
                      return tool['category'] == value;
                    }).toList();
                  });
                },
              ),
            ),

            const SizedBox(height: 12),
            // Tool list
            Expanded(child: _buildToolList()),
          ],
        ),
      ),
    );
  }
}
