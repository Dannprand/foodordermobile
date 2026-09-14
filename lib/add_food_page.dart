import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class AddFoodPage extends StatefulWidget {
  final int tenantId;
  const AddFoodPage({Key? key, required this.tenantId}) : super(key: key);

  @override
  _AddFoodPageState createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  List categories = [];
  List variationTypes = [];
  List<Map<String, dynamic>> variationSets = [];

  int? selectedCategoryId;
  int? selectedVariationTypeId;
  bool isVariationEnabled = false;
  bool isSubmitting = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  TextEditingController variationTypeController = TextEditingController();

  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchVariationTypes();
  }

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    variationTypeController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse(
          'http://172.19.10.208/food_order_api/get_categories.php?tenant_id=${widget.tenantId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data['categories'] ?? [];
          if (categories.isNotEmpty && selectedCategoryId == null) {
            selectedCategoryId = categories[0]['food_category_id'];
          }
        });
      }
    } catch (e) {
      print("Error fetching categories: $e");
    }
  }

  Future<void> fetchVariationTypes() async {
    try {
      final response = await http.get(Uri.parse(
          'http://172.19.10.208/food_order_api/get_variation_types.php?tenant_id=${widget.tenantId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          variationTypes = data['variation_types'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching variation types: $e");
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> addVariationType() async {
    if (variationTypeController.text.trim().isEmpty) {
      return;
    }

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
        showError("Failed to add variation type: ${jsonData['message']}");
      }
    } catch (e) {
      print("Error in addVariationType: $e");
    }
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

  void formatVariationCurrency(TextEditingController controller, String value) {
    String cleanValue = value.replaceAll(',', '').replaceAll('.', '');
    if (cleanValue.isNotEmpty) {
      int parsed = int.tryParse(cleanValue) ?? 0;
      String formatted = NumberFormat("#,###", "en_US").format(parsed);

      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      controller.clear();
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void addVariationSet() {
    setState(() {
      variationSets.add({
        'typeId': null,
        'typeName': '',
        'typeController': TextEditingController(),
        'variations': [
          {
            'name': TextEditingController(),
            'price': TextEditingController(),
            'stock': TextEditingController(),
          }
        ],
      });
    });
  }

  Future<void> addFood() async {
    if (selectedCategoryId == null) {
      showError("Please select a food category.");
      return;
    }
    if (nameController.text.trim().isEmpty) {
      showError("Food name is required.");
      return;
    }
    if (priceController.text.trim().isEmpty) {
      showError("Price is required.");
      return;
    }
    if (stockController.text.trim().isEmpty) {
      showError("Stock is required.");
      return;
    }
    if (descriptionController.text.trim().isEmpty) {
      showError("Description is required.");
      return;
    }
    if (_image == null) {
      showError("Please select an image for this food.");
      return;
    }

    if (isVariationEnabled) {
      for (int i = 0; i < variationSets.length; i++) {
        var set = variationSets[i];
        if (set['typeId'] == null) {
          showError("Please select variation type for Set ${i + 1}.");
          return;
        }

        for (int j = 0; j < set['variations'].length; j++) {
          var v = set['variations'][j];
          if (v['name'].text.trim().isEmpty ||
              v['price'].text.trim().isEmpty ||
              v['stock'].text.trim().isEmpty) {
            showError("Please complete all fields in variation ${j + 1} of Set ${i + 1}.");
            return;
          }
        }
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.19.10.208/food_order_api/add_food.php'),
      );

      request.fields['food_category_id'] = selectedCategoryId.toString();
      request.fields['food_name'] = nameController.text.trim();
      request.fields['food_price'] = priceController.text.replaceAll(',', '').trim();
      request.fields['food_stock'] = stockController.text.trim();
      request.fields['food_description'] = descriptionController.text.trim();
      request.fields['tenant_id'] = widget.tenantId.toString();

      if (isVariationEnabled) {
        List<Map<String, dynamic>> sets = [];
        for (int i = 0; i < variationSets.length; i++) {
          var set = variationSets[i];
          List<Map<String, dynamic>> variations = [];
          for (int j = 0; j < set['variations'].length; j++) {
            var v = set['variations'][j];
            variations.add({
              'name': v['name'].text.trim(),
              'price': v['price'].text.replaceAll(',', '').trim(),
              'stock': v['stock'].text.trim(),
            });
          }
          sets.add({
            'type_id': set['typeId'],
            'variations': variations,
          });
        }
        request.fields['variation_sets'] = jsonEncode(sets);
      }

      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('food_image', _image!.path));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseData);

      setState(() {
        isSubmitting = false;
      });

      if (jsonData['success'] == true) {
        Navigator.pop(context, true);
      } else {
        showError("Failed to add food: ${jsonData['message']}");
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      print("Error during addFood request: $e");
      showError("An error occurred while adding food.");
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
          "Add New Menu",
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Upload Section
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
                          color: _image != null ? const Color(0xFF1E5BB0) : Colors.grey.shade300,
                          width: _image != null ? 2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _image == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 38,
                                  color: Color(0xFF1E5BB0),
                                ),
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
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _image!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
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
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _image == null ? "Tap to select food image" : "Tap image to change photo",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card: Food Details
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Food Details",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField(
                    value: selectedCategoryId,
                    borderRadius: BorderRadius.circular(16),
                    isExpanded: true,
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat['food_category_id'],
                        child: Text(
                          cat['food_category_name'],
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedCategoryId = value as int),
                    decoration: _buildInputDecoration(
                      label: "Select Category",
                      prefixIcon: const Icon(Icons.category_outlined, size: 20, color: Color(0xFF1E5BB0)),
                      borderRadius: 16,
                    ),
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
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
                      hintText: "Write a brief description about this menu item...",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card: Variation Switch
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                title: const Text(
                  "Add Food Variations?",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                subtitle: const Text(
                  "Add size, flavor, topping, or other custom options",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                activeTrackColor: const Color(0xFF1E5BB0),
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.grey.shade400;
                }),
                value: isVariationEnabled,
                onChanged: (value) {
                  setState(() {
                    isVariationEnabled = value;
                    if (isVariationEnabled) {
                      variationSets = [];
                      addVariationSet();
                    } else {
                      variationSets = [];
                    }
                  });
                },
              ),
            ),

            // Variation Sets
            if (isVariationEnabled) ...[
              const SizedBox(height: 16),
              ...variationSets.asMap().entries.map((entry) {
                int setIndex = entry.key;
                var set = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E5BB0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Variation Set ${setIndex + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          if (setIndex != 0)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20),
                              onPressed: () {
                                setState(() {
                                  variationSets.removeAt(setIndex);
                                });
                              },
                              tooltip: "Remove Set",
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Variation Type Dropdown & Add Button
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: set['typeId'],
                              borderRadius: BorderRadius.circular(16),
                              isExpanded: true,
                              items: variationTypes.map((type) {
                                return DropdownMenuItem<int>(
                                  value: int.tryParse(type['food_variation_type_id'].toString()) ?? 0,
                                  child: Text(
                                    type['food_variation_type_name'],
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  variationSets[setIndex]['typeId'] = value;
                                });
                              },
                              decoration: _buildInputDecoration(
                                label: "Select Variation Type",
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
                              border: Border.all(color: const Color(0xFF1E5BB0).withValues(alpha: 0.2)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded, color: Color(0xFF1E5BB0)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text(
                                        "Add Variation Type",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      content: TextField(
                                        controller: set['typeController'],
                                        style: const TextStyle(color: Colors.black),
                                        decoration: InputDecoration(
                                          hintText: "e.g. Size, Topping, Ice Level",
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF1E5BB0), width: 1.5),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            variationTypeController = set['typeController'];
                                            await addVariationType();
                                            setState(() {
                                              variationSets[setIndex]['typeId'] = selectedVariationTypeId;
                                            });
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E5BB0),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text("Save"),
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
                      const SizedBox(height: 14),

                      // Variations List Items inside Set
                      ...set['variations'].asMap().entries.map((v) {
                        int vIndex = v.key;
                        var variation = v.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Option ${vIndex + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (vIndex != 0)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          variationSets[setIndex]['variations'].removeAt(vIndex);
                                        });
                                      },
                                      child: const Text(
                                        "Remove",
                                        style: TextStyle(
                                          color: Color(0xFFE11D48),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: variation['name'],
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                decoration: _buildInputDecoration(
                                  label: "Option Name",
                                  hintText: "e.g. Large, Extra Cheese",
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: variation['price'],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (val) => formatVariationCurrency(variation['price'], val),
                                      style: const TextStyle(fontSize: 14, color: Colors.black),
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
                                    child: TextField(
                                      controller: variation['stock'],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      style: const TextStyle(fontSize: 14, color: Colors.black),
                                      decoration: _buildInputDecoration(
                                        label: "Stock",
                                        hintText: "e.g. 50",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Add another option button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            variationSets[setIndex]['variations'].add({
                              'name': TextEditingController(),
                              'price': TextEditingController(),
                              'stock': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1E5BB0)),
                        label: const Text(
                          "Add another option",
                          style: TextStyle(
                            color: Color(0xFF1E5BB0),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Add Variation Set Button
              Center(
                child: OutlinedButton.icon(
                  onPressed: addVariationSet,
                  icon: const Icon(Icons.library_add_rounded, size: 18, color: Color(0xFF1E5BB0)),
                  label: const Text(
                    "Add Another Variation Set",
                    style: TextStyle(
                      color: Color(0xFF1E5BB0),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1E5BB0), width: 1.2),
                    backgroundColor: const Color(0xFF1E5BB0).withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : addFood,
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
                            "Save Menu",
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
    );
  }
}