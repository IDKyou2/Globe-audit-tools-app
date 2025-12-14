// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:signature/signature.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle, Uint8List;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
///
///
///                                      WORKING COPY
///
////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ManageTechnicianToolsScreen extends StatefulWidget {
  final String technicianId; // Add this

  final Map<String, dynamic>? technician;
  const ManageTechnicianToolsScreen({
    super.key,
    this.technician,
    required this.technicianId,
  });

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

  final TextEditingController _remarksController = TextEditingController();
  String? _existingRemark;
  bool _isEditingRemark = false;

  @override
  void initState() {
    super.initState();
    _fetchTechnicianTools();
    _fetchCategories();
    _scrollController = ScrollController();
    _refreshTechnicianData();
    _loadRemarks();

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
    _remarksController.dispose();
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

    final technicianId = widget.technicianId; // use string directly

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
    final technicianId = widget.technicianId; // always string

    if (technicianId == null || _saving) return;
    setState(() => _saving = true);

    try {
      final changedTools = _tools.where((tool) {
        return tool['status'] != tool['original_status'];
      }).toList();

      if (changedTools.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        return;
      }

      // Upsert the technician_tools table
      final updates = changedTools.map((tool) {
        return {
          'technician_id': technicianId,
          'tools_id': tool['tools_id'],
          'status': tool['status'],
          // 'last_updated_at': DateTime.now().toIso8601String(),
          'last_updated_at': DateTime.now()
              .toUtc()
              .toIso8601String(), // Explicit UTC
        };
      }).toList();

      // await _supabase.from('technician_tools').upsert(updates);
      await _supabase
          .from('technician_tools')
          .upsert(updates, onConflict: 'technician_id,tools_id');

      // ----------------------------------------- AUDIT_LOGS TABLE ----------------------------------------
      // Insert into audit table with date
      // final today = DateTime.now();
      // final auditInserts = changedTools.map((tool) {
      //   return {
      //     'technician_id': technicianId, // from technician_tools
      //     'tools_id': tool['tools_id'],
      //     'status': tool['status'],
      //     'date_added': DateTime.now().toIso8601String().substring(0, 10),
      //   };
      // }).toList();

      // // await _supabase.from('audit_logs').insert(auditInserts);
      // await _supabase.from('audit_logs').upsert(auditInserts);

      // Update local tool states
      for (var tool in _tools) {
        tool['original_status'] = tool['status'];
      }

      if (!mounted) return;
      setState(() => _hasChanges = false);

      // Fluttertoast.showToast(
      //   msg: "Saved ${changedTools.length} changes",
      //   toastLength: Toast.LENGTH_LONG,
      //   gravity: ToastGravity.BOTTOM,
      //   backgroundColor: const Color.fromARGB(255, 24, 172, 29),
      //   textColor: Colors.white,
      // );
      Fluttertoast.showToast(msg: "Saved ${changedTools.length} changes");
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
    final supabase = Supabase.instance.client;

    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    setState(() {
      _imageFile = file;
    });

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    try {
      final technicianId = widget.technicianId; // always string

      // Upload to the correct bucket
      await supabase.storage
          .from('technicians_pictures')
          .upload(fileName, file);

      // Get URL from the SAME bucket
      final publicUrl = supabase.storage
          .from('technicians_pictures')
          .getPublicUrl(fileName);

      // Save URL to database — INSERT or UPDATE depends on your logic
      await supabase
          .from('technicians')
          .update({'pictures': publicUrl})
          .eq('id', technicianId); // <- replace this with your actual id

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            //saved to database
            content: Text('Photo uploaded.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $error'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print("Upload failed: $error");
    }
  }

  Future<void> _sharePhoto() async {
    //Share icon function
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

  Future<Uint8List> addNameToSignature(
    Uint8List signatureBytes,
    String name,
  ) async {
    final codec = await ui.instantiateImageCodec(signatureBytes);
    final frame = await codec.getNextFrame();
    final signatureImage = frame.image;

    const extraHeight = 30; // space for the name

    // Create a larger canvas BEFORE drawing
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final totalWidth = signatureImage.width.toDouble();
    final totalHeight = signatureImage.height.toDouble() + extraHeight;

    // Fill background (optional)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalWidth, totalHeight),
      Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // Draw the signature normally, without scaling
    canvas.drawImage(signatureImage, const Offset(0, 0), Paint());

    // Draw text BELOW the signature
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: ui.Color(0xFF000000),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center the name horizontally
    final nameX = (totalWidth - textPainter.width) / 2;
    final nameY = signatureImage.height.toDouble();

    textPainter.paint(canvas, Offset(nameX, nameY));

    // Final image
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(
      signatureImage.width,
      signatureImage.height + extraHeight,
    );

    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  Future<void> _openSignaturePad() async {
    _signatureController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        bool isProcessing = false;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sign Here'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Signature Pad
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54),
                      ),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.grey[200]!,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // Cancel button
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                // Clear button
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          _signatureController.clear();
                        },
                  child: const Text('Clear'),
                ),

                // Display button
                // TextButton(
                //   onPressed: isProcessing
                //       ? null
                //       : () async {
                //           if (_signatureController.isEmpty) {
                //             Fluttertoast.showToast(msg: "Please sign first");
                //             return;
                //           }

                //           setDialogState(() => isProcessing = true);

                //           try {
                //             final technicianName =
                //                 widget.technician?['name'] ?? "Technician";

                //             // Get signature PNG
                //             final sigBytes = await _signatureController
                //                 .toPngBytes();
                //             if (sigBytes == null) {
                //               Fluttertoast.showToast(
                //                 msg: "Failed to capture signature.",
                //               );
                //               setDialogState(() => isProcessing = false);
                //               return;
                //             }

                //             // Create final image with signature + name
                //             final combinedBytes = await addNameToSignature(
                //               sigBytes,
                //               technicianName,
                //             );

                //             // Show the image in a new dialog
                //             showDialog(
                //               context: context,
                //               builder: (_) => AlertDialog(
                //                 title: const Text("Preview Signature"),
                //                 content: Image.memory(
                //                   combinedBytes,
                //                   width: double.maxFinite,
                //                 ),
                //                 actions: [
                //                   TextButton(
                //                     onPressed: () => Navigator.pop(context),
                //                     child: const Text("Close"),
                //                   ),
                //                 ],
                //               ),
                //             );

                //             setDialogState(() => isProcessing = false);
                //           } catch (e) {
                //             Fluttertoast.showToast(
                //               msg: "Error: $e",
                //               backgroundColor: Colors.red,
                //             );
                //             setDialogState(() => isProcessing = false);
                //           }
                //         },
                //   // style: ElevatedButton.styleFrom(
                //   //   backgroundColor: const Color(0xFF003E70),
                //   //   foregroundColor: Colors.white,
                //   // ),
                //   child: isProcessing
                //       ? const SizedBox(
                //           width: 20,
                //           height: 20,
                //           child: CircularProgressIndicator(
                //             strokeWidth: 2,
                //             color: Colors.white,
                //           ),
                //         )
                //       : const Text('Preview'),
                // ),
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
                            final technicianId =
                                widget.technicianId; // always string

                            //Displays technician name
                            final technicianName =
                                widget.technician?['name'] ?? "Technician";

                            if (technicianId == null) {
                              Fluttertoast.showToast(
                                msg: "Technician ID missing!",
                              );
                              setDialogState(() => isSaving = false);
                              return;
                            }

                            // Get signature PNG
                            final sigBytes = await _signatureController
                                .toPngBytes();
                            if (sigBytes == null) {
                              Fluttertoast.showToast(
                                msg: "Failed to capture signature.",
                              );
                              setDialogState(() => isSaving = false);
                              return;
                            }

                            // 🔥 Create final image with signature + name
                            final combinedBytes = await addNameToSignature(
                              sigBytes,
                              technicianName,
                            );

                            final fileName =
                                "signature_${technicianId}_${DateTime.now().millisecondsSinceEpoch}.png";

                            // Upload combined PNG to Supabase
                            await _supabase.storage
                                .from('technician_signatures')
                                .uploadBinary(fileName, combinedBytes);

                            // Get public URL
                            final publicUrl = _supabase.storage
                                .from('technician_signatures')
                                .getPublicUrl(fileName);

                            // Save URL to technicians table
                            await _supabase
                                .from('technicians')
                                .update({'e_signature': publicUrl})
                                .eq('id', technicianId);

                            // Close dialog
                            Navigator.pop(context);

                            // Refresh UI
                            setState(() {
                              widget.technician?['e_signature'] = publicUrl;
                            });

                            // Fluttertoast.showToast(
                            //   msg: "Signature saved!",
                            //   backgroundColor: Colors.green,
                            // );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                //saved to database
                                content: Text('Signature saved.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            Fluttertoast.showToast(
                              msg: "Error: $e",
                              backgroundColor: Colors.red,
                            );
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
    final technicianId = widget.technicianId; // always string

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

  Future<bool?> _showSaveChangesDialog() {
    //Save changes before leaving the page
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Do you want to save before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Don't leave, don't save
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(false); // Stay, let user save manually
                _saveChanges(); // trigger save
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Leave without saving
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRemarks() async {
    // if (_remarksController.text.isEmpty) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text("Please enter a remark")));
    //   return;
    // }

    setState(() => _loading = true);

    try {
      // 1️⃣ Check if a remark already exists
      final existing = await _supabase
          .from('technician_remarks')
          .select()
          .eq('technician_id', widget.technicianId) //get ID
          .maybeSingle();

      if (existing == null) {
        // 2️⃣ Insert new remark if none exists
        await _supabase.from('technician_remarks').insert({
          'technician_id': widget.technicianId,
          'remarks': _remarksController.text,
        });

        setState(() {
          _loading = false;
          _existingRemark = _remarksController.text;
          _isEditingRemark = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Remark added.")));
      } else {
        // 3️⃣ Update existing remark
        await _supabase
            .from('technician_remarks')
            .update({'remarks': _remarksController.text})
            .eq('id', existing['id']);

        setState(() {
          _loading = false;
          _existingRemark = _remarksController.text;
          _isEditingRemark = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Remark updated")));
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _loadRemarks() async {
    final res = await _supabase
        .from('technician_remarks')
        .select('remarks')
        .eq('technician_id', widget.technicianId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    setState(() {
      _existingRemark = res?['remarks'];
      _remarksController.text = _existingRemark ?? '';
    });
  }

  Future<void> _clearAllStatuses() async {
    final technicianId = widget.technicianId;

    if (technicianId.isEmpty) return;

    try {
      await _supabase
          .from('technician_tools')
          .update({'status': 'None'})
          .eq('technician_id', technicianId);

      // Update UI side
      setState(() {
        for (var tool in _tools) {
          tool['status'] = 'None';
        }
        _checkForChanges();
      });

      Fluttertoast.showToast(msg: "All tools reset to None");
    } catch (e) {
      print("Error on _clearAllStatuses: $e");

      // Fluttertoast.showToast(
      //   msg: "Error resetting: $e",
      //   backgroundColor: Colors.red,
      // );
    }
  }

  Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = "Confirm",
    String cancelText = "Cancel",
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
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
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
                style: TextStyle(fontSize: 12),
                _expandedCategories.values.isNotEmpty &&
                        _expandedCategories.values.every((e) => e)
                    ? 'Hide All'
                    : 'Show All',
              ),
            ),

            TextButton.icon(
              // ----------------------------------------------------- Clear All Button ------------------------------------
              onPressed: () async {
                bool confirmed = await showConfirmationDialog(
                  context: context,
                  title: "Clear All Tools",
                  message:
                      "Are you sure you want to reset all tool statuses to None?",
                  confirmText: "Clear All",
                  cancelText: "Cancel",
                );

                if (confirmed) {
                  _clearAllStatuses();
                  await _saveChanges();
                  // Fluttertoast.showToast(msg: "All statuses cleared");
                }
              },
              label: const Text("Clear All", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),

        // 🔥 Dynamically display ALL categories from Supabase
        ..._categories.map((cat) => _buildCategoryTools(cat)).toList(),

        const SizedBox(height: 5),

        if (_imageFile != null) _buildCapturedPhoto(),
        // Only show signature if it exists AND changes have been saved
        if (widget.technician?['e_signature'] != null && !_hasChanges)
          _showSignature(),

        const SizedBox(height: 10),

        //Text("Note:"),
        if ((_existingRemark ?? "").isNotEmpty && !_isEditingRemark) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _existingRemark!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _isEditingRemark = true);
                  },
                  child: const Text("Edit"),
                ),
              ],
            ),
          ),
        ]
        /// 🔥 Editing Mode (TextFormField + Save)
        else ...[
          TextFormField(
            controller: _remarksController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your remark here',
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 10),

          _loading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _saveRemarks,
                  child: const Text('Save'),
                ),
        ],
        SizedBox(height: 150),
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
                  //Share icon function
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: _sharePhoto,
                  tooltip: 'Share Photo',
                ),
                IconButton(
                  //Refresh icon function
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _takePicture, //opens camera
                  tooltip: 'Retake picture',
                ),
                IconButton(
                  //Close icon
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                    });
                  },
                  tooltip: 'Close',
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
    final signatureUrl = widget.technician?['e_signature'];

    // Don't show the card if URL is null or empty
    if (signatureUrl == null || signatureUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF003E70),
            child: Row(
              children: [
                const Icon(Icons.edit, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'E-signature',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _openSignaturePad,
                  tooltip: 'Add Signature',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      widget.technician?['e_signature'] = null;
                    });
                  },
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Signature image
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                signatureUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.contain,
                // Log error and hide card if image fails
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading signature image: $error");
                  // Remove the signature so card disappears on next build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        widget.technician?['e_signature'] = null;
                      });
                    }
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Optional helper to pre-check if the image URL exists
  Future<bool> _checkImageExists(String url) async {
    try {
      final response = await Uri.parse(
        url,
      ).resolve('').toFilePath(); // Just test URL format
      // Or implement an actual HEAD request if needed
      return true;
    } catch (e) {
      print("Invalid image URL: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    //main
    final technicianName = widget.technician?['name'] ?? 'Technician';

    return WillPopScope(
      onWillPop: () async {
        // Check for unsaved changes
        if (_hasChanges) {
          final shouldLeave = await _showSaveChangesDialog();
          return shouldLeave ?? false; // true = allow pop, false = prevent
        }
        return true; // no unsaved changes, allow pop
      },
      child: Scaffold(
        appBar: AppBar(title: Text("$technicianName's tools")),
        body: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchTechnicianTools,
                    child: _buildToolsList(),
                  ),
            // 🔼 Scroll-to-top button (LEFT SIDE)
            if (_showScrollToTop)
              Positioned(
                left: 16,
                bottom: _hasChanges ? 96 : 16, // avoid overlap with save FAB
                child: FloatingActionButton(
                  heroTag: 'scrollUpLeft',
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
              ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // if (_showScrollToTop) ...[
            //   FloatingActionButton(
            //     heroTag: 'scrollUp',
            //     mini: true,
            //     onPressed: () {
            //       _scrollController.animateTo(
            //         0,
            //         duration: const Duration(milliseconds: 400),
            //         curve: Curves.easeOut,
            //       );
            //     },
            //     backgroundColor: Colors.grey.shade900,
            //     child: const Icon(Icons.arrow_upward, color: Colors.white),
            //   ),
            //   const SizedBox(height: 5),
            // ],

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
                // Save changes button, pag mag change ang technician sa tools status
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
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
