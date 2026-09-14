import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'edit_food_page.dart';
import 'add_food_page.dart';

class FoodDetailPage extends StatefulWidget {
  final int tenantId;
  final int foodId;
  final Map<String, dynamic>? initialFood;

  const FoodDetailPage({
    Key? key,
    required this.tenantId,
    required this.foodId,
    this.initialFood,
  }) : super(key: key);

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  Map<String, dynamic>? foodData;
  List<Map<String, dynamic>> variations = [];
  List<dynamic> categories = [];
  String categoryName = '';

  bool isLoading = true;
  bool isStockUpdating = false;
  bool hasModified = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFood != null) {
      foodData = Map<String, dynamic>.from(widget.initialFood!);
    }
    loadAllData();
  }

  Future<void> loadAllData() async {
    setState(() {
      isLoading = foodData == null;
    });

    await Future.wait([
      fetchFoodDetail(),
      fetchVariations(),
      fetchCategories(),
    ]);

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchFoodDetail() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_all_foods.php?tenant_id=${widget.tenantId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['foods'] != null) {
          final List foodsList = data['foods'];
          final found = foodsList.firstWhere(
            (item) => item['food_id'] == widget.foodId,
            orElse: () => null,
          );
          if (found != null && mounted) {
            setState(() {
              foodData = Map<String, dynamic>.from(found);
            });
            _updateCategoryName();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching food detail: $e");
    }
  }

  Future<void> fetchVariations() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_food_variations.php?food_id=${widget.foodId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('variations') && mounted) {
          setState(() {
            variations = List<Map<String, dynamic>>.from(data['variations'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching variations: $e");
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_categories.php?tenant_id=${widget.tenantId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            categories = data['categories'] ?? [];
          });
          _updateCategoryName();
        }
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  void _updateCategoryName() {
    if (foodData != null && categories.isNotEmpty) {
      final catId = foodData!['food_category_id'];
      final cat = categories.firstWhere(
        (c) => c['food_category_id'] == catId,
        orElse: () => null,
      );
      if (cat != null && mounted) {
        setState(() {
          categoryName = cat['food_category_name'] ?? '';
        });
      }
    }
  }

  Future<void> increaseStock() async {
    if (isStockUpdating) return;
    setState(() {
      isStockUpdating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/increase_stock.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_id': widget.foodId,
          'tenant_id': widget.tenantId,
          'increment': 1,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        hasModified = true;
        setState(() {
          final currentStock = int.tryParse(foodData?['food_stock']?.toString() ?? '0') ?? 0;
          foodData?['food_stock'] = currentStock + 1;
        });
        _showSnackBar("Stock increased (+1)");
      } else {
        _showSnackBar(responseData['message'] ?? "Failed to increase stock", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error increasing stock: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isStockUpdating = false;
        });
      }
    }
  }

  Future<void> decreaseStock() async {
    final currentStock = int.tryParse(foodData?['food_stock']?.toString() ?? '0') ?? 0;
    if (currentStock <= 0 || isStockUpdating) return;

    setState(() {
      isStockUpdating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/decrease_stock.php'),
        body: {
          'food_id': widget.foodId.toString(),
          'tenant_id': widget.tenantId.toString(),
        },
      );

      final responseData = jsonDecode(response.body);
      if (responseData['success'] == true) {
        hasModified = true;
        setState(() {
          foodData?['food_stock'] = currentStock - 1;
        });
        _showSnackBar("Stock decreased (-1)");
      } else {
        _showSnackBar(responseData['message'] ?? "Failed to decrease stock", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error decreasing stock: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isStockUpdating = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF1E5BB0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  String formatPrice(dynamic price) {
    if (price == null) return "0";
    String raw = price.toString().replaceAll(',', '').replaceAll('.', '');
    int? val = int.tryParse(raw);
    if (val == null) return price.toString();
    return NumberFormat("#,###", "en_US").format(val);
  }

  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith("http")) return imagePath;
    return "http://172.19.10.208/cihosFoodOrder/public/storage/$imagePath";
  }

  Future<void> _navigateToEdit() async {
    if (foodData == null) return;
    final catId = foodData!['food_category_id'] ?? -1;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditFoodPage(
          tenantId: widget.tenantId,
          foodId: widget.foodId,
          foodName: foodData!['food_name'] ?? '',
          foodPrice: (foodData!['food_price'] ?? '').toString(),
          foodStock: (foodData!['food_stock'] ?? '').toString(),
          foodDescription: foodData!['food_description'] ?? '',
          foodCategoryId: catId is int ? catId : int.tryParse(catId.toString()) ?? -1,
          foodImage: foodData!['food_image'],
        ),
      ),
    );

    if (result == true) {
      hasModified = true;
      loadAllData();
    }
  }

  Future<void> _navigateToAddFood() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFoodPage(tenantId: widget.tenantId),
      ),
    );

    if (result == true) {
      hasModified = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStock = int.tryParse(foodData?['food_stock']?.toString() ?? '0') ?? 0;
    final isAvailable = currentStock > 0;
    final imageUrl = _getImageUrl(foodData?['food_image']);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, hasModified);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context, hasModified),
          ),
          title: const Text(
            "Menu Details",
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
        body: isLoading && foodData == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E5BB0),
                  strokeWidth: 2.5,
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big Hero Food Image
                    Container(
                      width: double.infinity,
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFFFEF9C3).withValues(alpha: 0.5),
                                      child: const Center(
                                        child: Icon(
                                          Icons.restaurant_rounded,
                                          size: 54,
                                          color: Color(0xFF1E5BB0),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFFFEF9C3).withValues(alpha: 0.5),
                                    child: const Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        size: 54,
                                        color: Color(0xFF1E5BB0),
                                      ),
                                    ),
                                  ),

                            // Top gradient shadow for badge readability
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.45),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Top Left: Category Badge
                            if (categoryName.isNotEmpty)
                              Positioned(
                                top: 14,
                                left: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.category_outlined, size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Top Right: Availability Pill
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isAvailable ? const Color(0xFF16A34A) : const Color(0xFFE11D48))
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isAvailable ? "Available" : "Sold Out",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Main Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foodData?['food_name'] ?? 'Menu Name',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "Rp ${formatPrice(foodData?['food_price'])}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E5BB0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E5BB0).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Base Price",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E5BB0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 14),

                          // Description
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E5BB0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Description",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (foodData?['food_description'] != null &&
                                    foodData!['food_description'].toString().trim().isNotEmpty)
                                ? foodData!['food_description']
                                : "No description provided for this menu.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: (foodData?['food_description'] != null &&
                                      foodData!['food_description'].toString().trim().isNotEmpty)
                                  ? const Color(0xFF475569)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stock Management Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF1E5BB0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Inventory Stock",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // + / - Stock Stepper Button
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, size: 20, color: Colors.black87),
                                  onPressed: (currentStock > 0 && !isStockUpdating) ? decreaseStock : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: isStockUpdating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1E5BB0),
                                          ),
                                        )
                                      : Text(
                                          "$currentStock",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF1E5BB0)),
                                  onPressed: isStockUpdating ? null : increaseStock,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Food Variations Card (if any)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
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
                                    width: 4,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E5BB0),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Variations / Add-ons",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${variations.length} option${variations.length == 1 ? '' : 's'}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (variations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                "No variations registered for this menu.",
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            )
                          else
                            ...variations.map((v) {
                              final vName = v['food_variation_name'] ?? v['name'] ?? '-';
                              final vPrice = v['food_variation_price'] ?? v['price'] ?? 0;
                              final vStock = v['food_variation_stock'] ?? v['stock'] ?? 0;
                              final vTypeName = v['food_variation_type_name'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (vTypeName.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              vTypeName,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          vPrice.toString() == '0' || vPrice.toString().isEmpty
                                              ? "Free"
                                              : "+Rp ${formatPrice(vPrice)}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E5BB0),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Stock: $vStock",
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Buttons (Edit Food & Add New Item)
                    Row(
                      children: [
                        // Edit Food Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: foodData == null ? null : _navigateToEdit,
                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF1E5BB0), size: 18),
                            label: const Text(
                              "Edit Menu",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5BB0),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1E5BB0), width: 1.5),
                              backgroundColor: const Color(0xFF1E5BB0).withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Add New Item Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToAddFood,
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              "Add Item",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E5BB0),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: const Color(0xFF1E5BB0).withValues(alpha: 0.3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
