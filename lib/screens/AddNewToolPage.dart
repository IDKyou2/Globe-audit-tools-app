import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  @override
  void dispose() {
    _toolNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color color = const Color(0xFF003E70)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  Future<void> _addTool(BuildContext dialogContext) async {
    final name = _toolNameController.text.trim();
    final category = _selectedCategory;

    if (name.isEmpty || category == null) {
      _showSnack('Please fill all required fields.', color: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exists = await Supabase.instance.client
          .from('tools')
          .select('tools_id')
          .ilike('name', name)
          .maybeSingle();

      if (exists != null) {
        _showSnack('Tool name already exists!', color: Colors.red);
        _toolNameController.clear();

        setState(() => _selectedCategory = null);

        if (mounted) Navigator.pop(dialogContext); // Close the dialog
        return;
      }

      await Supabase.instance.client.from('tools').insert({
        'name': name,
        'category': category,
      });

      _showSnack('Tool added successfully!');
      _toolNameController.clear();
      setState(() => _selectedCategory = null);

      // Close the dialog
      if (mounted) Navigator.pop(dialogContext);

      await _fetchTools();
    } catch (e) {
      debugPrint('❌ Error adding tool: $e');
      _showSnack('Error adding tool: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Function to update tool
  Future<void> _updateTool(
    Map<String, dynamic> tool,
    String updatedName,
    String updatedCategory,
    BuildContext dialogContext,
  ) async {
    if (updatedName.isEmpty) {
      _showSnack('Please fill all required fields.', color: Colors.orange);
      return;
    }

    try {
      // Store navigator reference before async call
      final navigator = Navigator.of(dialogContext, rootNavigator: true);

      // Check if another tool already has the same name
      final existing = await Supabase.instance.client
          .from('tools')
          .select()
          .eq('name', updatedName)
          .neq('tools_id', tool['tools_id']); // exclude current tool

      if (existing.isNotEmpty) {
        if (mounted) {
          navigator.pop(); // close the dialog automatically
          _showSnack('Tool name already exists!', color: Colors.red);
        }
        return;
      }

      // Proceed with update
      await Supabase.instance.client
          .from('tools')
          .update({'name': updatedName, 'category': updatedCategory})
          .eq('tools_id', tool['tools_id']);

      if (mounted) {
        navigator.pop(); // close dialog after successful update
        _showSnack('Tool updated successfully!');
      }

      await _fetchTools();
    } catch (e) {
      if (mounted) _showSnack('Error updating tool: $e', color: Colors.red);
    }
  }

  Future<void> _deleteTool(String toolId) async {
    try {
      await Supabase.instance.client
          .from('tools')
          .delete()
          .eq('tools_id', toolId);
      _showSnack('Tool deleted successfully!');
      await _fetchTools();
    } catch (e) {
      _showSnack('Error deleting tool: $e', color: Colors.red);
    }
  }

  Future<void> _showAddDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Tool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _toolNameController,
                enabled: !_isLoading,
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
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() => _selectedCategory = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            _isLoading
                ? const SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(),
                  )
                : ElevatedButton.icon(
                    onPressed: () =>
                        _addTool(dialogContext), // <-- pass dialogContext
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
        );
      },
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> tool) async {
    final editController = TextEditingController(text: tool['name']);
    String editCategory = tool['category'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setStateDialog) => AlertDialog(
          title: const Text('Edit Tool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editController,
                decoration: const InputDecoration(
                  labelText: 'Tool Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: editCategory,
                decoration: const InputDecoration(
                  labelText: 'Tool Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setStateDialog(() => editCategory = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003E70),
              ),
              onPressed: () async {
                await _updateTool(
                  tool,
                  editController.text.trim(),
                  editCategory,
                  dialogContext, // dialog context from builder
                );
              },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
            if (value == 'edit') _showEditDialog(tool);
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
              'No tools found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _filteredTools.length,
      itemBuilder: (_, index) => _buildToolCard(_filteredTools[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.grey[100];

    return Scaffold(
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
            const SizedBox(height: 12),
            // Tool list
            Expanded(child: _buildToolList()),
          ],
        ),
      ),
    );
  }
}
