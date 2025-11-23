// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool isAdding = false;
  bool isUpdating = false;

  // Display time and date
  String formatDateTime(dynamic rawDate) {
    if (rawDate == null) return 'Never';

    final dt = DateTime.parse(rawDate.toString());
    return DateFormat('MM/dd/yyyy, hh:mm a').format(dt);
  }

  List<dynamic> _technicians = [];
  List<dynamic> _filteredTechnicians = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchTechnicians();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  Future<void> fetchTechnicians() async {
    final supabase = Supabase.instance.client;

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('technicians')
          .select()
          .order('created_at', ascending: false) // SECOND priority
          .order('last_checked_at', ascending: false); // FIRST priority
      //.order('created_at', ascending: false); // Newest first

      if (mounted) {
        setState(() {
          _technicians = response;
          _filteredTechnicians = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching technicians: $e')),
        );
      }
    }
  }

  /// Search function
  void _filterTechnicians(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTechnicians = _technicians;
      } else {
        _filteredTechnicians = _technicians.where((technician) {
          final name = technician['name']?.toString().toLowerCase() ?? '';
          final cluster = technician['cluster']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) || cluster.contains(searchLower);
        }).toList();
      }
    });
  }

  void showAddTechnicianDialog() {
    final List<String> clusters = ['Davao North', 'Davao South'];
    String? selectedCluster;
    final TextEditingController nameController = TextEditingController();
    String? inlineError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Technician'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !isDialogLoading,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: const OutlineInputBorder(),
                      errorText: inlineError, // show inline error
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCluster,
                    hint: const Text('Choose cluster *'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: clusters.map((cluster) {
                      return DropdownMenuItem<String>(
                        value: cluster,
                        child: Text(cluster),
                      );
                    }).toList(),
                    onChanged: isDialogLoading
                        ? null
                        : (newValue) {
                            setDialogState(() => selectedCluster = newValue);
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () {
                          nameController.dispose();
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003E70),
                  ),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          setDialogState(() => inlineError = null);

                          // Inline validation
                          if (name.isEmpty || selectedCluster == null) {
                            setDialogState(() {
                              inlineError = 'Please fill all required fields.';
                            });
                            return;
                          }

                          // Disable while adding
                          setState(() => isAdding = true);
                          setDialogState(() => isDialogLoading = true);

                          try {
                            final supabase = Supabase.instance.client;

                            // Case-insensitive duplicate check
                            final existing = await supabase
                                .from('technicians')
                                .select('id')
                                .ilike('name', name)
                                .maybeSingle();

                            if (existing != null) {
                              setDialogState(() {
                                inlineError =
                                    'Technician "$name" already exists.';
                                isDialogLoading = false;
                              });
                              setState(() => isAdding = false);
                              return;
                            }

                            // Insert technician
                            final now = DateTime.now();
                            final formattedDate = DateFormat(
                              'MM/dd/yyyy, h:mm a',
                            ).format(now);

                            await supabase.from('technicians').insert({
                              'name': name,
                              'cluster': selectedCluster,
                              'created_at': formattedDate,
                            });

                            await fetchTechnicians();

                            if (mounted) Navigator.pop(dialogContext);
                          } catch (e) {
                            setDialogState(() {
                              inlineError = 'Error adding technician: $e';
                              isDialogLoading = false;
                            });
                          } finally {
                            if (mounted) {
                              setState(() => isAdding = false);
                              setDialogState(() => isDialogLoading = false);
                            }
                          }
                        },
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Separate function for adding technician
  Future<void> _addTechnician(
    BuildContext dialogContext,
    String name,
    String? cluster,
    StateSetter setDialogState,
    void Function(String?) setInlineError, // callback to update inlineError
  ) async {
    // Inline validation for empty fields
    if (name.isEmpty || cluster == null) {
      setInlineError('Please fill all required fields.');
      return;
    }

    setState(() => isAdding = true);

    try {
      final supabase = Supabase.instance.client;

      // Check for duplicates (case-insensitive)
      final exists = await supabase
          .from('technicians')
          .select('id')
          .ilike('name', name)
          .maybeSingle();

      if (exists != null) {
        setInlineError('Technician "$name" already exists.');
        return;
      }

      // Insert technician
      final now = DateTime.now();
      final formattedDate = DateFormat('MM/dd/yyyy, h:mm a').format(now);

      await supabase.from('technicians').insert({
        'name': name,
        'cluster': cluster,
        'created_at': formattedDate,
      });

      // Close the dialog
      if (mounted) Navigator.pop(dialogContext);

      // Refresh the list
      await fetchTechnicians();
    } catch (e) {
      setInlineError('Error adding technician: $e');
    } finally {
      if (mounted) setState(() => isAdding = false);
    }
  }

  Future<void> addQuery({
    required String name,
    required String? cluster,
    required BuildContext dialogContext,
  }) async {
    if (isAdding) return;

    if (name.isEmpty || cluster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields.',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Color.fromARGB(255, 255, 193, 7),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isAdding = true);

    try {
      final supabase = Supabase.instance.client;

      // ✅ Check for duplicates
      final existing = await supabase
          .from('technicians')
          .select('id')
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        setState(() => isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Technician "$name" already exists.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final now = DateTime.now();
      final formattedDate = DateFormat('MM/dd/yyyy, h:mm a').format(now);

      await supabase.from('technicians').insert({
        'name': name,
        'cluster': cluster,
        'created_at': formattedDate,
      });

      await fetchTechnicians();

      if (mounted) {
        Navigator.pop(dialogContext);
        _nameController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Technician "$name" added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding technician: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isAdding = false);
      }
    }
  }

  void showEditTechnicianDialog(Map<String, dynamic> technician) {
    final TextEditingController nameController = TextEditingController(
      text: technician['name'],
    );
    String? editSelectedCluster = technician['cluster'];
    String? inlineError;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            title: const Text('Edit Technician'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !isDialogLoading,
                  decoration: InputDecoration(
                    labelText: 'Technician Name',
                    border: const OutlineInputBorder(),
                    errorText: inlineError, // show inline error here too
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: editSelectedCluster,
                  decoration: const InputDecoration(
                    labelText: 'Cluster *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Davao North',
                      child: Text('Davao North'),
                    ),
                    DropdownMenuItem(
                      value: 'Davao South',
                      child: Text('Davao South'),
                    ),
                  ],
                  onChanged: isDialogLoading
                      ? null
                      : (value) =>
                            setDialogState(() => editSelectedCluster = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading
                    ? null
                    : () {
                        nameController.dispose();
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003E70),
                ),
                onPressed: isDialogLoading
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        final newCluster = editSelectedCluster;

                        setDialogState(() {
                          inlineError = null;
                          isDialogLoading = true;
                        });

                        // Check empty fields
                        if (newName.isEmpty || newCluster == null) {
                          setDialogState(() {
                            inlineError = 'Please fill all required fields.';
                            isDialogLoading = false;
                          });
                          return;
                        }

                        // Check if nothing changed
                        if (newName == technician['name'] &&
                            newCluster == technician['cluster']) {
                          Navigator.pop(dialogContext); // Close immediately
                          return;
                        }

                        try {
                          final supabase = Supabase.instance.client;

                          // Check if new name already exists (case-insensitive)
                          final existing = await supabase
                              .from('technicians')
                              .select('id')
                              .ilike('name', newName) // case-insensitive
                              .neq('id', technician['id'])
                              .maybeSingle();

                          if (existing != null) {
                            setDialogState(() {
                              inlineError = 'Technician already exists.';
                              isDialogLoading = false;
                            });
                            return;
                          }

                          // Proceed with update
                          await supabase
                              .from('technicians')
                              .update({'name': newName, 'cluster': newCluster})
                              .eq('id', technician['id']);

                          await fetchTechnicians();

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Technician updated successfully!',
                                ),
                                backgroundColor: Color(0xFF003E70),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() {
                              inlineError = 'Error updating technician: $e';
                              isDialogLoading = false;
                            });
                          }
                        }
                      },
                child: isDialogLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> updateQuery({
    required Map<String, dynamic> technician,
    required TextEditingController nameController,
    required String? selectedCluster,
    required BuildContext dialogContext,
  }) async {
    // Prevent multiple simultaneous operations
    if (isUpdating) return;

    final name = nameController.text.trim();
    final cluster = selectedCluster;

    if (name.isEmpty || cluster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: Color.fromARGB(255, 255, 193, 7),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isUpdating = true);
    Navigator.pop(dialogContext);

    try {
      await Supabase.instance.client
          .from('technicians')
          .update({'name': name, 'cluster': cluster})
          .eq('id', technician['id']);

      await fetchTechnicians();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Technician updated successfully!'),
            backgroundColor: Color(0xFF003E70),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating technician: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      nameController.dispose();
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  void _showDeleteTechnicianDialog(Map<String, dynamic> technician) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Technician'),
        content: Text(
          'Are you sure you want to remove "${technician['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first

              try {
                await Supabase.instance.client
                    .from('technicians')
                    .delete()
                    .eq('id', technician['id']);

                await fetchTechnicians();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Technician deleted successfully!'),
                      backgroundColor: Colors.green,
                      //backgroundColor: Color(0xFF003E70),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting technician: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> updateLastChecked(String technicianId) async {
    try {
      final now = DateTime.now();
      final formatted = DateFormat('MM/dd/yyyy, h:mm a').format(now);

      await Supabase.instance.client
          .from('technicians')
          .update({'last_checked_at': formatted})
          .eq('id', technicianId); // uuid is string
    } catch (e) {
      debugPrint('Error updating last checked: $e');
    }
  }

  // Main build
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bgColor = isDarkMode ? Colors.black : Colors.grey[100];
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final subtitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    return RefreshIndicator(
      onRefresh: fetchTechnicians,
      color: const Color(0xFF003E70),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search + Add
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isSearching
                          ? TextField(
                              key: const ValueKey('searchField'),
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search name or cluster...',
                                hintStyle: TextStyle(color: subtitleColor),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Color(0xFF003E70),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchController.clear();
                                      _filteredTechnicians = _technicians;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: bgColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                              ),
                              onChanged: _filterTechnicians,
                            )
                          : Row(
                              key: const ValueKey('searchIcon'),
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.search,
                                    size: 26,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF003E70),
                                  ),
                                  onPressed: () =>
                                      setState(() => _isSearching = true),
                                ),
                                const Spacer(),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: showAddTechnicianDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add technician',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003E70),
                    ),
                  ),
                ],
              ),
            ),

            // Search count
            if (_isSearching && _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  'Found ${_filteredTechnicians.length} result(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Content list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF003E70),
                      ),
                    )
                  : _filteredTechnicians.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 60,
                            color: subtitleColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No results found',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      itemCount: _filteredTechnicians.length,
                      itemBuilder: (context, index) {
                        final tech = _filteredTechnicians[index];
                        return Card(
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF003E70),
                              child: Text(
                                tech['name']?.substring(0, 1).toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              tech['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tech['cluster'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                                if (tech['last_checked_at'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Last Checked: ${formatDateTime(tech['last_checked_at'])}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await updateLastChecked(tech['id']);
                                    await context.push(
                                      '/view-tools',
                                      extra: {
                                        'id': tech['id'],
                                        'name': tech['name'],
                                      },
                                    );
                                    if (!mounted) return;
                                    fetchTechnicians();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFF003E70),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Check Tools',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF003E70),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 24,
                                    color: subtitleColor,
                                  ),
                                  onPressed: () async {
                                    final selected = await showMenu<String>(
                                      context: context,
                                      position: const RelativeRect.fromLTRB(
                                        100,
                                        100,
                                        0,
                                        0,
                                      ),
                                      items: [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Remove',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                    if (selected == 'edit')
                                      showEditTechnicianDialog(tech);
                                    if (selected == 'delete')
                                      _showDeleteTechnicianDialog(tech);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
