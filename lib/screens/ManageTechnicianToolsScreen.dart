import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';

class ManageTechnicianToolsScreen extends StatefulWidget {
  final Map<String, dynamic>? technician;
  const ManageTechnicianToolsScreen({super.key, this.technician});

  @override
  State<ManageTechnicianToolsScreen> createState() =>
      _ManageTechnicianToolsScreenState();
}

class _ManageTechnicianToolsScreenState
    extends State<ManageTechnicianToolsScreen> {
  late ScrollController _scrollController;
  bool _showScrollToTop = false;

  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;

  List<Map<String, dynamic>> _tools = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  //final Map<String, bool> _expandedCategories = {};
  Map<String, bool> _expandedCategories = {};
  List<String> _categories = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
    _fetchCategories();
    _scrollController = ScrollController();
    _refreshTechnicianData();

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
    _signatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('id', ascending: true);

      final fetched = data
          .map<String>((item) => item['name'] as String)
          .toList();

      setState(() {
        _categories = fetched;

        // initialize expanded map if new categories appear
        for (final cat in _categories) {
          _expandedCategories.putIfAbsent(cat, () => true);
        }
      });
    } catch (e) {
      print("Error fetching categories: $e");
    }
  }

  Future<void> _fetchTechnicianTools() async {
    setState(() => _loading = true);

    final technicianId = widget.technician?['id'];
    if (technicianId == null) {
      debugPrint('❌ No technician ID provided');
      setState(() => _loading = false);
      return;
    }

    try {
      final allTools = await _supabase
          .from('tools')
          .select('tools_id, name, category');

      final assignedTools = await _supabase
          .from('technician_tools')
          .select('tools_id, status')
          .eq('technician_id', technicianId);

      final combined = allTools.map<Map<String, dynamic>>((tool) {
        final match = assignedTools.firstWhere(
          (a) => a['tools_id'] == tool['tools_id'],
          orElse: () => {'status': 'None'},
        );

        return {
          'tools_id': tool['tools_id'],
          'name': tool['name'],
          'category': tool['category'],
          'status': match['status'] ?? 'None',
          'original_status': match['status'] ?? 'None',
        };
      }).toList();

      setState(() {
        _tools = combined;
        _hasChanges = false;

        final categories = combined.map((t) => t['category'] as String).toSet();
        _expandedCategories.clear();
        for (var c in categories) {
          _expandedCategories[c] = false;
        }
      });
    } catch (e) {
      debugPrint('❌ Error fetching technician tools: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load tools'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveChanges() async {
    final technicianId = widget.technician?['id'];
    if (technicianId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final changedTools = _tools.where((tool) {
        return tool['status'] != tool['original_status'];
      }).toList();

      if (changedTools.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            duration: Duration(milliseconds: 800),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      final updates = changedTools.map((tool) {
        return {
          'technician_id': technicianId,
          'tools_id': tool['tools_id'],
          'status': tool['status'],
          'last_updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('technician_tools').upsert(updates);

      for (var tool in _tools) {
        tool['original_status'] = tool['status'];
      }

      if (!mounted) return;
      setState(() => _hasChanges = false);

      Fluttertoast.showToast(
        msg: "Saved ${changedTools.length} changes",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('❌ Error saving changes: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save changes'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  
  }

  void _checkForChanges() {
    final hasChanges = _tools.any((tool) {
      return tool['status'] != tool['original_status'];
    });

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  IconData? _getCategoryIcon(String category) {
    switch (category) {
      case 'PPE':
        return Icons.security;
      case 'GPON Tools':
        return Icons.settings_input_antenna;
      case 'Common Tools':
        return Icons.build;
      case 'Additional Tools':
        return Icons.construction;
      case 'Vehicle Requirements':
        return Icons.car_rental;
      case 'Technician Requirements':
        return Icons.engineering;
      default:
        return null;
    }
  }

  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo captured'),
          backgroundColor: Color(0xFF003E70), //blue
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sharePhoto() async {
    if (_imageFile == null) return;

    try {
      final technicianName = widget.technician?['name'] ?? "Technician";

      await Share.shareXFiles([
        XFile(_imageFile!.path),
      ], text: "$technicianName Photo");
    } catch (e) {
      debugPrint('❌ Error sharing photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> saveSignature({
    required String technicianId,
    required File imageFile,
  }) async {
    final supabase = Supabase.instance.client;

    // 🔍 DEBUG: Check authentication
    final user = supabase.auth.currentUser;
    debugPrint("Current user: ${user?.id}");
    debugPrint("User role: ${user?.role}");

    if (user == null) {
      debugPrint("❌ User not authenticated!");
      return false;
    }

    try {
      final fileName =
          "signature_${technicianId}_${DateTime.now().millisecondsSinceEpoch}.png";

      final bytes = await imageFile.readAsBytes();

      debugPrint("📤 Uploading to bucket: technician_signatures");
      debugPrint("📄 Filename: $fileName");

      await supabase.storage
          .from('technician_signatures')
          .uploadBinary(fileName, bytes);

      final publicUrl = supabase.storage
          .from('technician_signatures')
          .getPublicUrl(fileName);

      await supabase
          .from('technicians')
          .update({'e_signature': publicUrl})
          .eq('id', technicianId);

      return true;
    } catch (e) {
      debugPrint("❌ Error saving e-signature: $e");
      return false;
    }
  }

  Future<void> _openSignaturePad() async {
    _signatureController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sign Here'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey[200]!,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_signatureController.isEmpty) {
                            Fluttertoast.showToast(msg: "Please sign first");
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            final technicianId = widget.technician?['id'];

                            if (technicianId == null) {
                              Fluttertoast.showToast(
                                msg: "Technician ID missing!",
                              );
                              setDialogState(() => isSaving = false);
                              return;
                            }

                            // Get signature PNG bytes
                            final sigBytes = await _signatureController
                                .toPngBytes();
                            if (sigBytes == null) {
                              Fluttertoast.showToast(
                                msg: "Failed to capture signature.",
                              );
                              setDialogState(() => isSaving = false);
                              return;
                            }

                            final fileName =
                                "signature_${technicianId}_${DateTime.now().millisecondsSinceEpoch}.png";

                            // Upload to Supabase Storage
                            await _supabase.storage
                                .from('technician_signatures')
                                .uploadBinary(fileName, sigBytes);

                            // Get public URL
                            final publicUrl = _supabase.storage
                                .from('technician_signatures')
                                .getPublicUrl(fileName);

                            print("✅ Signature uploaded: $publicUrl");

                            // Save URL to technicians table
                            await _supabase
                                .from('technicians')
                                .update({'e_signature': publicUrl})
                                .eq('id', technicianId);

                            print("✅ Signature URL saved to database");

                            // Close dialog first
                            Navigator.pop(context);

                            // ✅ Update local technician data and refresh UI
                            setState(() {
                              widget.technician?['e_signature'] = publicUrl;
                            });

                            print(
                              "✅ UI updated with signature: ${widget.technician?['e_signature']}",
                            );

                            Fluttertoast.showToast(
                              msg: "Signature saved successfully!",
                              backgroundColor: Colors.green,
                            );
                          } catch (e) {
                            Fluttertoast.showToast(
                              msg: "Error saving signature: $e",
                              backgroundColor: Colors.red,
                            );
                            print("❌ Error: $e");
                            setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003E70),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _refreshTechnicianData() async {
    final technicianId = widget.technician?['id'];
    if (technicianId == null) return;

    try {
      final data = await _supabase
          .from('technicians')
          .select('id, name, e_signature')
          .eq('id', technicianId)
          .single();

      setState(() {
        widget.technician?['e_signature'] = data['e_signature'];
      });
    } catch (e) {
      print("Error refreshing technician data: $e");
    }
  }

  //Widgets Section
  Widget _buildToolsList() {
    if (_tools.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tools & Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                final allExpanded =
                    _expandedCategories.values.isNotEmpty &&
                    _expandedCategories.values.every((e) => e);

                setState(() {
                  _expandedCategories.updateAll((key, value) => !allExpanded);
                });
              },
              icon: Icon(
                _expandedCategories.values.isNotEmpty &&
                        _expandedCategories.values.every((e) => e)
                    ? Icons.unfold_less
                    : Icons.unfold_more,
              ),
              label: Text(
                _expandedCategories.values.isNotEmpty &&
                        _expandedCategories.values.every((e) => e)
                    ? 'Collapse All'
                    : 'Expand All',
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 🔥 Dynamically display ALL categories from Supabase
        ..._categories.map((cat) => _buildCategoryTools(cat)).toList(),

        const SizedBox(height: 5),

        if (_imageFile != null) _buildCapturedPhoto(),
        // Only show signature if it exists AND changes have been saved
        if (widget.technician?['e_signature'] != null && !_hasChanges)
          _showSignature(),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCategoryTools(String category) {
    final iconData = _getCategoryIcon(category);

    // Filter tools that belong to this category
    final filteredTools =
        _tools
            .where(
              (tool) =>
                  (tool['category'] ?? '').toString().trim().toLowerCase() ==
                  category.trim().toLowerCase(),
            )
            .toList()
          ..sort((a, b) {
            final idA = int.tryParse(a['tools_id'].toString()) ?? 0;
            final idB = int.tryParse(b['tools_id'].toString()) ?? 0;
            return idA.compareTo(idB);
          });

    // If no tool belongs to this category, don't display the card
    if (filteredTools.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if category is expanded
    final isExpanded = _expandedCategories[category] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Column(
        children: [
          // CATEGORY HEADER
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF003E70),
                borderRadius: isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      )
                    : BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  iconData != null
                      ? Icon(iconData, color: Colors.white, size: 24)
                      : const SizedBox.shrink(), // disappears if null

                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            // TABLE HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Tool Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        Text(
                          'Onhand',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        Text(
                          'None',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        Text(
                          'Missing',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        Text(
                          'Defective',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TOOL ITEMS
            ...filteredTools.map((tool) {
              final currentStatus = tool['status'] ?? 'None';
              final hasChanged = tool['status'] != tool['original_status'];

              return Container(
                decoration: BoxDecoration(
                  color: hasChanged ? Colors.blue.shade50 : null,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        tool['name'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatusCheckbox(tool, 'Onhand', currentStatus),
                          _buildStatusCheckbox(tool, 'None', currentStatus),
                          _buildStatusCheckbox(tool, 'Missing', currentStatus),
                          _buildStatusCheckbox(
                            tool,
                            'Defective',
                            currentStatus,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCheckbox(Map tool, String status, String currentStatus) {
    return Checkbox(
      value: currentStatus == status,
      onChanged: _saving
          ? null
          : (value) {
              if (value == true) {
                setState(() => tool['status'] = status);
                _checkForChanges();
              }
            },
      activeColor: {
        'Onhand': Colors.green,
        'None': Colors.grey,
        'Missing': Colors.orange,
        'Defective': Colors.red,
      }[status],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildCapturedPhoto() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 0, 62, 112),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_camera, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Captured Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: _sharePhoto,
                  tooltip: 'Share/Download Photo',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                    });
                  },
                  tooltip: 'Remove Photo',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _imageFile!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Widget _buildSignatureCard() {
  Widget _showSignature() {
    final technicianName = widget.technician?['name'] ?? 'Technician';
    final signatureUrl = widget.technician?['e_signature'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF003E70),
            child: Row(
              children: [
                const Icon(Icons.edit, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    //'E-signature $technicianName',
                    'E-signature',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (signatureUrl != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _openSignaturePad,
                    tooltip: 'Update Signature',
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: signatureUrl != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          signatureUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text('Failed to load signature'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Signature saved',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No signature yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
          ),
          if (signatureUrl == null)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openSignaturePad,
                    icon: const Icon(Icons.draw),
                    label: const Text('Add Signature'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003E70),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final technicianName = widget.technician?['name'] ?? 'Technician';

    return Scaffold(
      appBar: AppBar(title: Text("$technicianName's tools")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTechnicianTools,
              child: _buildToolsList(),
            ),

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
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              },
              backgroundColor: Colors.grey.shade900,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
            const SizedBox(height: 5),
          ],

          // Hide camera when _hasChanges = true
          if (!_hasChanges) ...[
            FloatingActionButton(
              heroTag: 'camera',
              onPressed: _takePicture,
              backgroundColor: const Color(0xFF003E70),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
            SizedBox(height: 5),
            FloatingActionButton(
              heroTag: 'signature',
              onPressed: _openSignaturePad,
              backgroundColor: const Color(0xFF003E70),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ],
          if (_hasChanges) ...[
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'save',
              onPressed: _saving ? null : _saveChanges,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _saving ? 'Saving...' : 'Save Changes',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF003E70),
            ),
          ],
          /*
          Signature(
            controller: _signatureController,
            height: 200,
            backgroundColor: Colors.grey[200]!,
          ),
          ElevatedButton(
            onPressed: _saveSignature,
            child: const Text('Save Signature'),
          ),
          */
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
