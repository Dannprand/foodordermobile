import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class EditFoodPage extends StatefulWidget {
  final int tenantId;
  final int foodId;
  final String foodName;
  final String foodPrice;
  final String foodStock;
  final String foodDescription;
  final int foodCategoryId;
  final String? foodImage;

  const EditFoodPage({
    Key? key,
    required this.tenantId,
    required this.foodId,
    required this.foodName,
    required this.foodPrice,
    required this.foodStock,
    required this.foodDescription,
    required this.foodCategoryId,
    this.foodImage,
  }) : super(key: key);

  @override
  _EditFoodPageState createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController variationTypeController = TextEditingController();

  List categories = [];
  int? selectedCategoryId;
  bool isLoading = true;
  bool isSubmitting = false;
  String errorMessage = '';
  File? _imageFile;

  List<Map<String, dynamic>> variations = [];
  List<Map<String, dynamic>> variationTypes = [];
  int? selectedVariationTypeId;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.foodName;

    if (widget.foodPrice.isNotEmpty) {
      int parsed = int.tryParse(widget.foodPrice.replaceAll(',', '').replaceAll('.', '')) ?? 0;
      priceController.text = parsed > 0 ? NumberFormat("#,###", "en_US").format(parsed) : widget.foodPrice;
    } else {
      priceController.text = '';
    }

    stockController.text = widget.foodStock;
    descriptionController.text = widget.foodDescription;
    selectedCategoryId = widget.foodCategoryId != -1 ? widget.foodCategoryId : null;

    fetchCategories();
    fetchVariations();
    fetchVariationTypes();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    variationTypeController.dispose();
    super.dispose();
  }

  void formatCurrency(String value) {
    String cleanValue = value.replaceAll(',', '').replaceAll('.', '');
    if (cleanValue.isNotEmpty) {
      int parsed = int.tryParse(cleanValue) ?? 0;
      String formatted = NumberFormat("#,###", "en_US").format(parsed);
      setState(() {
        priceController.text = formatted;
        priceController.selection = TextSelection.fromPosition(
          TextPosition(offset: formatted.length),
        );
      });
    } else {
      setState(() {
        priceController.clear();
      });
    }
  }

  void formatVariationCurrency(int index, String value) {
    String cleanValue = value.replaceAll(',', '').replaceAll('.', '');
    if (cleanValue.isNotEmpty) {
      int parsed = int.tryParse(cleanValue) ?? 0;
      String formatted = NumberFormat("#,###", "en_US").format(parsed);
      setState(() {
        variations[index]['price'] = formatted;
        variations[index]['food_variation_price'] = formatted;
      });
    } else {
      setState(() {
        variations[index]['price'] = '';
        variations[index]['food_variation_price'] = '';
      });
    }
  }

  Future<void> fetchVariationTypes() async {
    try {
      final response = await http.get(Uri.parse(
          'http://172.19.10.208/food_order_api/get_variation_types_edit.php?tenant_id=${widget.tenantId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          variationTypes = List<Map<String, dynamic>>.from(data['types'] ?? []);
        });
      }
    } catch (e) {
      print("Error fetching variation types: $e");
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse(
          'http://172.19.10.208/food_order_api/get_categories.php?tenant_id=${widget.tenantId}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data['categories'] ?? [];
          isLoading = false;

          if (!categories.any((c) => c['food_category_id'] == selectedCategoryId)) {
            selectedCategoryId = null;
          }
        });
      } else {
        throw Exception("Failed to load categories");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching categories: $e";
      });
    }
  }

  Future<void> addCategory(String categoryName) async {
    final trimmed = categoryName.trim();
    if (trimmed.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/add_category.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_category_name': trimmed,
          'tenant_id': widget.tenantId,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        await fetchCategories();
        final created = categories.firstWhere(
          (c) => c['food_category_name']?.toString().toLowerCase() == trimmed.toLowerCase(),
          orElse: () => null,
        );
        if (created != null && mounted) {
          setState(() {
            selectedCategoryId = created['food_category_id'] is int
                ? created['food_category_id']
                : int.tryParse(created['food_category_id'].toString());
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Kategori '$trimmed' berhasil ditambahkan!"),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? "Gagal menambahkan kategori"),
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> deleteCategory(int categoryId, String categoryName) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/delete_category.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_category_id': categoryId,
          'tenant_id': widget.tenantId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Kategori '$categoryName' berhasil dihapus"),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          await fetchCategories();
          if (selectedCategoryId == categoryId && mounted) {
            setState(() {
              selectedCategoryId = categories.isNotEmpty ? categories[0]['food_category_id'] : null;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? "Gagal menghapus kategori"),
                backgroundColor: const Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("File delete_category.php belum tersedia di server (404)"),
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void showCategoryManagerDialog() {
    final TextEditingController newCategoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category_rounded, color: Color(0xFF1E5BB0), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Kategori Menu",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Buat Kategori Baru",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCategoryController,
                              style: const TextStyle(fontSize: 14, color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "Misal: Minuman Dingin",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF1E5BB0), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final name = newCategoryController.text.trim();
                              if (name.isNotEmpty) {
                                Navigator.pop(dialogContext);
                                await addCategory(name);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E5BB0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Kategori Terdaftar",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            "${categories.length} total",
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      categories.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text("Belum ada kategori", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: categories.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (ctx, index) {
                                  final cat = categories[index];
                                  final catId = cat['food_category_id'] is int
                                      ? cat['food_category_id']
                                      : int.tryParse(cat['food_category_id'].toString()) ?? 0;
                                  final catName = cat['food_category_name']?.toString() ?? '';
                                  final isCurrent = selectedCategoryId == catId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    dense: true,
                                    title: Text(
                                      catName,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        color: isCurrent ? const Color(0xFF1E5BB0) : Colors.black,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isCurrent)
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              "Dipilih",
                                              style: TextStyle(fontSize: 10, color: Color(0xFF1E5BB0), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20),
                                          tooltip: "Hapus Kategori",
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            _confirmDeleteCategoryInForm(catId, catName);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedCategoryId = catId;
                                      });
                                      Navigator.pop(dialogContext);
                                    },
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Tutup", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategoryInForm(int categoryId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            "Hapus Kategori?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
          ),
          content: Text(
            "Apakah Anda yakin ingin menghapus kategori \"$categoryName\"?",
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await deleteCategory(categoryId, categoryName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  Future<void> fetchVariations() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_food_variations.php?food_id=${widget.foodId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('variations')) {
          setState(() {
            variations = List<Map<String, dynamic>>.from(data['variations']);
          });
        }
      }
    } catch (e) {
      print("Error fetching variations: $e");
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _addVariationField() {
    setState(() {
      variations.add({
        "name": "",
        "price": "",
        "stock": "",
        "food_variation_type_id": variationTypes.isNotEmpty
            ? int.tryParse(variationTypes.first['food_variation_type_id'].toString())
            : null,
      });
    });
  }

  void _removeVariationField(int index) {
    setState(() {
      variations.removeAt(index);
    });
  }

  Future<void> addVariationType() async {
    if (variationTypeController.text.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/add_variation_type.php'),
        body: {
          'food_variation_type_name': variationTypeController.text.trim(),
          'tenant_id': widget.tenantId.toString(),
        },
      );

      final jsonData = jsonDecode(response.body);
      if (jsonData['success'] == true) {
        await fetchVariationTypes();
        setState(() {
          selectedVariationTypeId = jsonData['food_variation_type_id'];
        });
        variationTypeController.clear();
      } else {
        _showSnackBar("Failed to add variation type: ${jsonData['message']}", isError: true);
      }
    } catch (e) {
      print("Error in addVariationType: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> updateFood() async {
    if (selectedCategoryId == null) {
      _showSnackBar("Please select a food category.", isError: true);
      return;
    }
    if (nameController.text.trim().isEmpty) {
      _showSnackBar("Food name is required.", isError: true);
      return;
    }
    if (priceController.text.trim().isEmpty) {
      _showSnackBar("Price is required.", isError: true);
      return;
    }
    if (stockController.text.trim().isEmpty) {
      _showSnackBar("Stock is required.", isError: true);
      return;
    }
    if (descriptionController.text.trim().isEmpty) {
      _showSnackBar("Description is required.", isError: true);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    var uri = Uri.parse('http://172.19.10.208/food_order_api/update_food.php');
    var request = http.MultipartRequest('POST', uri);

    request.fields['food_id'] = widget.foodId.toString();
    request.fields['tenant_id'] = widget.tenantId.toString();
    request.fields['food_name'] = nameController.text.trim();
    request.fields['food_price'] = priceController.text.replaceAll(',', '').replaceAll('.', '').trim();
    request.fields['food_stock'] = stockController.text.trim();
    request.fields['food_description'] = descriptionController.text.trim();
    request.fields['food_category_id'] = selectedCategoryId.toString();

    List<Map<String, dynamic>> processedVariations = variations.map((variation) {
      String rawPrice = (variation['price'] ?? variation['food_variation_price'] ?? '').toString();
      String cleanPrice = rawPrice.replaceAll(',', '').replaceAll('.', '').trim();

      return {
        'food_variation_id': variation['food_variation_id']?.toString(),
        'food_variation_name': (variation['name'] ?? variation['food_variation_name'] ?? '').toString().trim(),
        'food_variation_price': cleanPrice,
        'food_variation_stock': (variation['stock'] ?? variation['food_variation_stock'] ?? '').toString().trim(),
        'food_variation_type_id': variation['food_variation_type_id']?.toString() ??
            variation['type_id']?.toString() ?? '',
      };
    }).toList();

    request.fields['variations'] = jsonEncode(processedVariations);

    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'food_image',
        _imageFile!.path,
        contentType: MediaType('image', path.extension(_imageFile!.path).replaceAll('.', '')),
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        isSubmitting = false;
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSnackBar("Makanan berhasil diperbarui.");
          Navigator.pop(context, true);
        } else {
          _showSnackBar(responseData['message'] ?? "Gagal memperbarui makanan.", isError: true);
        }
      } else {
        _showSnackBar("Gagal memperbarui makanan (Status: ${response.statusCode})", isError: true);
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      _showSnackBar("Error: $e", isError: true);
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    BoxConstraints? prefixIconConstraints,
    double borderRadius = 14,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconConstraints: prefixIconConstraints,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFF1E5BB0), width: 1.6),
      ),
    );
  }

  String _getImageUrl(String img) {
    if (img.startsWith("http")) return img;
    return "http://172.19.10.208/cihosFoodOrder/public/storage/$img";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Menu",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (_imageFile != null || (widget.foodImage != null && widget.foodImage!.isNotEmpty))
                                ? const Color(0xFF1E5BB0)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _imageFile != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_imageFile!, fit: BoxFit.cover),
                                    _buildChangeOverlay(),
                                  ],
                                )
                              : (widget.foodImage != null && widget.foodImage!.isNotEmpty)
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          _getImageUrl(widget.foodImage!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                        ),
                                        _buildChangeOverlay(),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add_photo_alternate_outlined, size: 38, color: Color(0xFF1E5BB0)),
                                        SizedBox(height: 6),
                                        Text(
                                          "Upload Photo",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E5BB0),
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap to change food photo",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Food Details Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E5BB0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Food Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedCategoryId,
                              borderRadius: BorderRadius.circular(16),
                              isExpanded: true,
                              items: categories.map<DropdownMenuItem<int>>((cat) {
                                final catId = cat['food_category_id'] is int
                                    ? cat['food_category_id']
                                    : int.tryParse(cat['food_category_id'].toString()) ?? 0;
                                return DropdownMenuItem<int>(
                                  value: catId,
                                  child: Text(
                                    cat['food_category_name']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedCategoryId = value),
                              decoration: _buildInputDecoration(
                                label: "Select Category",
                                prefixIcon: const Icon(Icons.category_outlined, size: 20, color: Color(0xFF1E5BB0)),
                                borderRadius: 16,
                              ),
                              dropdownColor: Colors.white,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1E5BB0).withValues(alpha: 0.2)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded, color: Color(0xFF1E5BB0), size: 24),
                              tooltip: "Tambah / Kelola Kategori",
                              onPressed: showCategoryManagerDialog,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Food Name
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      decoration: _buildInputDecoration(
                        label: "Food Name",
                        hintText: "e.g. Nasi Goreng Spesial",
                        prefixIcon: const Icon(Icons.restaurant_outlined, size: 20, color: Color(0xFF1E5BB0)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Price & Stock in Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            onChanged: formatCurrency,
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                            decoration: _buildInputDecoration(
                              label: "Price",
                              hintText: "25,000",
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 14, right: 8),
                                child: Text(
                                  "Rp",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E5BB0),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                            decoration: _buildInputDecoration(
                              label: "Stock",
                              hintText: "e.g. 50",
                              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF1E5BB0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      decoration: _buildInputDecoration(
                        label: "Description",
                        hintText: "Enter a mouth-watering description of this dish...",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Food Variations Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E5BB0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Food Variations",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ],
                        ),
                        Text(
                          "${variations.length} Option${variations.length == 1 ? '' : 's'}",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (variations.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                        ),
                        child: Center(
                          child: Text(
                            "No variations added for this menu yet.",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ),
                      )
                    else
                      ...variations.asMap().entries.map((entry) {
                        int index = entry.key;
                        var variation = entry.value;

                        var typeValue = variation['food_variation_type_id'] is String
                            ? int.tryParse(variation['food_variation_type_id'])
                            : variation['food_variation_type_id'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Variation Type Selection & Add Button
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: typeValue,
                                      borderRadius: BorderRadius.circular(16),
                                      isExpanded: true,
                                      items: variationTypes.map((type) {
                                        return DropdownMenuItem<int>(
                                          value: int.tryParse(type['food_variation_type_id'].toString()),
                                          child: Text(
                                            type['food_variation_type_name'].toString(),
                                            style: const TextStyle(fontSize: 14, color: Colors.black),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          variations[index]['type_id'] = val;
                                          variations[index]['food_variation_type_id'] = val;
                                        });
                                      },
                                      decoration: _buildInputDecoration(
                                        label: "Variation Type",
                                        borderRadius: 16,
                                      ),
                                      dropdownColor: Colors.white,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add_rounded, color: Color(0xFF1E5BB0), size: 22),
                                      tooltip: "Add New Variation Type",
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                              title: const Text(
                                                "New Variation Type",
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              ),
                                              content: TextField(
                                                controller: variationTypeController,
                                                decoration: _buildInputDecoration(
                                                  label: "Type Name",
                                                  hintText: "e.g. Size, Spicy Level",
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await addVariationType();
                                                    if (selectedVariationTypeId != null) {
                                                      setState(() {
                                                        variations[index]['food_variation_type_id'] = selectedVariationTypeId;
                                                        variations[index]['type_id'] = selectedVariationTypeId;
                                                      });
                                                    }
                                                    Navigator.pop(context);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1E5BB0),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Variation Name
                              TextFormField(
                                initialValue: variation['food_variation_name'] ?? variation['name'] ?? '',
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                decoration: _buildInputDecoration(
                                  label: "Option Name",
                                  hintText: "e.g. Large, Extra Hot",
                                ),
                                onChanged: (val) {
                                  variations[index]['name'] = val;
                                  variations[index]['food_variation_name'] = val;
                                },
                              ),
                              const SizedBox(height: 10),

                              // Price & Stock in Row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: (variation['food_variation_price'] ?? variation['price'] ?? '').toString(),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 14, color: Colors.black),
                                      onChanged: (val) => formatVariationCurrency(index, val),
                                      decoration: _buildInputDecoration(
                                        label: "Extra Price",
                                        hintText: "0",
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.only(left: 14, right: 8),
                                          child: Text(
                                            "Rp",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E5BB0),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: (variation['food_variation_stock'] ?? variation['stock'] ?? '').toString(),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      style: const TextStyle(fontSize: 14, color: Colors.black),
                                      decoration: _buildInputDecoration(
                                        label: "Stock",
                                        hintText: "e.g. 50",
                                      ),
                                      onChanged: (val) {
                                        variations[index]['stock'] = val;
                                        variations[index]['food_variation_stock'] = val;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _removeVariationField(index),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 18),
                                  label: const Text(
                                    "Remove Option",
                                    style: TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 4),

                    // Add Variation Option Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addVariationField,
                        icon: const Icon(Icons.add_rounded, color: Color(0xFF1E5BB0), size: 18),
                        label: const Text(
                          "Add Variation Option",
                          style: TextStyle(
                            color: Color(0xFF1E5BB0),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1E5BB0), width: 1.2),
                          backgroundColor: const Color(0xFF1E5BB0).withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : updateFood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BB0),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF1E5BB0).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Update Menu",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: const Text(
          "Change",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
