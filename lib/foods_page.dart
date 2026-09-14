import 'package:flutter/material.dart';
import 'package:food_order_cihos/add_food_page.dart';
import 'package:food_order_cihos/edit_food_page.dart';
import 'package:food_order_cihos/food_detail_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class FoodsPage extends StatefulWidget {
  final int tenantId;
  const FoodsPage({Key? key, required this.tenantId}) : super(key: key);

  @override
  _FoodsPageState createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  List categories = [];
  List foods = [];
  bool isLoading = true;
  int? selectedCategoryId;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedCategoryId = -1; // Default kategori "All"
    fetchCategories().then((_) {
      setState(() {
        selectedCategoryId = -1;
      });
      fetchAllFoods();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_categories.php?tenant_id=${widget.tenantId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            categories = data['categories'] ?? [];
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load categories");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      print("Error fetching categories: $e");
    }
  }

  Future<void> fetchAllFoods() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_all_foods.php?tenant_id=${widget.tenantId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            foods = data['foods'] ?? [];
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load foods");
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching foods: $e");
    }
  }

  Future<void> fetchFoods(int categoryId) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_foods.php?category_id=$categoryId&tenant_id=${widget.tenantId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            foods = data['foods'] ?? [];
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load foods");
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching foods: $e");
    }
  }

  String formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(price);
  }

  void showAddCategoryDialog() {
    TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Add Food Category",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          content: TextField(
            controller: categoryController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: "Enter category name",
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                await addCategory(categoryController.text);
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
          if (selectedCategoryId == categoryId) {
            setState(() {
              selectedCategoryId = -1;
            });
            await fetchCategories();
            await fetchAllFoods();
          } else {
            await fetchCategories();
          }
        } else {
          _showErrorSnackBar(responseData['message'] ?? "Gagal menghapus kategori");
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar("File delete_category.php belum tersedia di server (404)");
      } else {
        _showErrorSnackBar("Gagal menghapus kategori (Status: ${response.statusCode})");
      }
    } catch (e) {
      _showErrorSnackBar("Kesalahan koneksi: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void confirmDeleteCategory(int categoryId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Hapus Kategori?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black),
                ),
              ),
            ],
          ),
          content: Text(
            "Apakah Anda yakin ingin menghapus kategori \"$categoryName\"?\n\nMenu yang menggunakan kategori ini tidak akan terhapus, namun status kategorinya akan dilepas.",
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Hapus Kategori", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void showManageCategoriesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Kelola Kategori Menu",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Text(
                    "Pilih kategori untuk menghapus atau tambah kategori baru",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      showAddCategoryDialog();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5BB0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E5BB0).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1E5BB0), size: 20),
                          SizedBox(width: 10),
                          Text(
                            "Tambah Kategori Baru",
                            style: TextStyle(
                              color: Color(0xFF1E5BB0),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: categories.isEmpty
                        ? const Center(
                            child: Text(
                              "Belum ada kategori",
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final catId = cat['food_category_id'] is int
                                  ? cat['food_category_id']
                                  : int.tryParse(cat['food_category_id'].toString()) ?? 0;
                              final catName = cat['food_category_name']?.toString() ?? '';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.category_outlined, color: Color(0xFF1E5BB0), size: 20),
                                ),
                                title: Text(
                                  catName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
                                  tooltip: "Hapus Kategori",
                                  onPressed: () {
                                    Navigator.pop(context);
                                    confirmDeleteCategory(catId, catName);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> increaseStock(int foodId) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/increase_stock.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_id': foodId,
          'tenant_id': widget.tenantId,
          'increment': 1,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['success'] == true) {
        if (selectedCategoryId == -1) {
          fetchAllFoods();
        } else {
          fetchFoods(selectedCategoryId!);
        }
      } else {
        print("Failed to increase stock: ${responseData['message']}");
      }
    } catch (e) {
      print("Error increasing stock: $e");
    }
  }

  Future<void> decreaseStock(int foodId) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/decrease_stock.php'),
        body: {
          'food_id': foodId.toString(),
          'tenant_id': widget.tenantId.toString(),
        },
      );

      final data = jsonDecode(response.body);
      if (data['success']) {
        if (selectedCategoryId == -1) {
          fetchAllFoods();
        } else {
          fetchFoods(selectedCategoryId!);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to decrease stock')),
          );
        }
      }
    } catch (e) {
      print("Error decreasing stock: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = foods.where((item) {
      if (searchQuery.isEmpty) return true;
      final name = (item['food_name'] ?? '').toString().toLowerCase();
      final desc = (item['food_description'] ?? '').toString().toLowerCase();
      final q = searchQuery.toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar dengan Logo & Icon Notifikasi (Konsisten dengan Orders)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/icon/logoapp.png',
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      "CIPUTRA HOSPITAL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Date & Title Header + Add Item Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.8,
                        ),
                      ),
                      // Add Item Button (Warna Biru Primary)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddFoodPage(
                                tenantId: widget.tenantId,
                              ),
                            ),
                          ).then((value) async {
                            await fetchCategories();
                            if (selectedCategoryId == -1) {
                              fetchAllFoods();
                            } else if (selectedCategoryId != null) {
                              fetchFoods(selectedCategoryId!);
                            }
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          "Add Item",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E5BB0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar & Filter Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search menu items...",
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status Indicator Info (misal: "X Items Total • Y Active")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${foods.length} Items Total",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Categories Horizontal Pill Tabs (Warna Biru Primary & Putih)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Tab All Items
                  _buildCategoryPill(
                    label: "All Items",
                    isSelected: selectedCategoryId == -1,
                    onTap: () {
                      setState(() {
                        selectedCategoryId = -1;
                      });
                      fetchAllFoods();
                    },
                  ),
                  // Kategori dari database
                  ...categories.map(
                    (cat) {
                      final catId = cat['food_category_id'] is int
                          ? cat['food_category_id']
                          : int.tryParse(cat['food_category_id'].toString()) ?? 0;
                      final catName = cat['food_category_name']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: _buildCategoryPill(
                          label: catName,
                          isSelected: selectedCategoryId == catId,
                          onTap: () {
                            setState(() {
                              selectedCategoryId = catId;
                            });
                            fetchFoods(selectedCategoryId!);
                          },
                          onLongPress: () => confirmDeleteCategory(catId, catName),
                          onDelete: () => confirmDeleteCategory(catId, catName),
                        ),
                      );
                    },
                  ),
                  // Tombol Tambah Kategori
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: showAddCategoryDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16, color: Color(0xFF1E5BB0)),
                            SizedBox(width: 2),
                            Text(
                              "Add Category",
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
                  // Tombol Kelola Kategori (Manage/Hapus)
                  if (categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: GestureDetector(
                        onTap: showManageCategoriesDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 15, color: Color(0xFF64748B)),
                              SizedBox(width: 4),
                              Text(
                                "Kelola",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Menu List Items
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E5BB0)),
                    )
                  : filteredFoods.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 56,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No menu items found.",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          itemCount: filteredFoods.length,
                          itemBuilder: (context, index) {
                            final food = filteredFoods[index];
                            final double foodPrice =
                                double.tryParse(food['food_price'].toString()) ?? 0.0;
                            final int foodStock =
                                int.tryParse(food['food_stock'].toString()) ?? 0;
                            final bool isAvailable = foodStock > 0;
                            final String foodImageUrl = food['food_image'] ?? '';
                            final String fullImageUrl = foodImageUrl.isNotEmpty
                                ? "http://172.19.10.208/cihosFoodOrder/public/storage/$foodImageUrl"
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris Atas: Image Thumbnail + Nama + Harga + Kategori Tag (Clickable to open FoodDetailPage)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FoodDetailPage(
                                            tenantId: widget.tenantId,
                                            foodId: food['food_id'],
                                            initialFood: food,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        if (selectedCategoryId == -1) {
                                          fetchAllFoods();
                                        } else {
                                          fetchFoods(selectedCategoryId!);
                                        }
                                      }
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Image / Placeholder Makanan
                                        Container(
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            color: const Color(0xFFFEF9C3).withValues(alpha: 0.6),
                                            border: Border.all(color: Colors.grey.shade200),
                                            image: fullImageUrl.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(fullImageUrl),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: fullImageUrl.isEmpty
                                              ? const Center(
                                                  child: Icon(
                                                    Icons.restaurant_rounded,
                                                    color: Color(0xFF1E5BB0),
                                                    size: 28,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),

                                        // Detail Nama, Harga, Tag
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              Text(
                                                food['food_name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Rp ${formatPrice(foodPrice)}",
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E5BB0),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Padding(
                                          padding: EdgeInsets.only(top: 18),
                                          child: Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: Colors.grey.shade100),
                                  const SizedBox(height: 10),

                                  // Baris Bawah: Status Switch / Stock Control + Action Buttons (Edit, Stock)
                                  Row(
                                    children: [
                                      // Status Pill (Available / Sold Out)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                              : const Color(0xFFE11D48).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isAvailable
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFE11D48),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isAvailable ? "Available" : "Sold Out",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFE11D48),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),

                                      // Stock Control (+ -)
                                      Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              icon: const Icon(
                                                Icons.remove_rounded,
                                                size: 16,
                                                color: Colors.black87,
                                              ),
                                              onPressed: foodStock > 0
                                                  ? () => decreaseStock(food['food_id'])
                                                  : null,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                "$foodStock",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                size: 16,
                                                color: Color(0xFF1E5BB0),
                                              ),
                                              onPressed: () => increaseStock(food['food_id']),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Edit Button
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () async {
                                          final categoryId = food['food_category_id'];
                                          if (categoryId != null) {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditFoodPage(
                                                  foodName: food['food_name'],
                                                  foodPrice: food['food_price'].toString(),
                                                  foodStock: food['food_stock'].toString(),
                                                  foodImage: food['food_image'],
                                                  foodDescription: food['food_description'],
                                                  tenantId: widget.tenantId,
                                                  foodCategoryId: categoryId,
                                                  foodId: food['food_id'],
                                                ),
                                              ),
                                            );
                                            if (result == true) {
                                              await Future.delayed(const Duration(milliseconds: 300));
                                              await fetchCategories();
                                              if (selectedCategoryId == -1) {
                                                fetchAllFoods();
                                              } else {
                                                fetchFoods(selectedCategoryId!);
                                              }
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit_outlined, size: 14, color: Colors.black87),
                                              SizedBox(width: 4),
                                              Text(
                                                "Edit",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: onDelete != null && isSelected ? 12 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E5BB0) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E5BB0) : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E5BB0).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            if (onDelete != null && isSelected) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
