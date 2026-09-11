import 'package:flutter/material.dart';
import 'package:food_order_cihos/add_food_page.dart';
import 'package:food_order_cihos/edit_food_page.dart';
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

  @override
  void initState() {
    super.initState();
    selectedCategoryId = -1; // Pastikan kategori "All" dipilih pertama kali
    fetchCategories().then((_) {
      setState(() {
        selectedCategoryId = -1; // Jangan set ke kategori tertentu, biarkan All
      });
      fetchAllFoods(); // Pastikan semua makanan dimuat pertama kali
    });
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
        print("Categories Response: $data"); // Debugging
        setState(() {
          categories = data['categories'] ?? [];
          // Jangan set selectedCategoryId ke kategori pertama
          isLoading = false;
        });
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
        print("Foods Response: $data"); // Debugging

        if (mounted) {
          setState(() {
            foods = data['foods'] ?? [];
          });
        }
      } else {
        throw Exception("Failed to load foods");
      }
    } catch (e) {
      print("Error fetching foods: $e");
    }
  }

  Future<void> fetchFoods(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_foods.php?category_id=$categoryId&tenant_id=${widget.tenantId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Foods Response: $data"); // Debugging
        if (mounted) {
          setState(() {
            foods = data['foods'] ?? [];
          });
        }
      } else {
        throw Exception("Failed to load foods");
      }
    } catch (e) {
      print("Error fetching foods: $e");
    }
  }

  String formatPrice(double price) {
    final formatter = NumberFormat('#,###.##', 'en_US');
    return formatter.format(price);
  }

  void showAddCategoryDialog() {
    TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Food Category"),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(hintText: "Enter category name"),
          ),
          actions: [ 
           TextButton(
  onPressed: () => Navigator.pop(context),
  style: TextButton.styleFrom(
    foregroundColor: Colors.black // Teks jadi biru
  ),
  child: Text("Cancel"),
),
             ElevatedButton(
            onPressed: () async {
              await addCategory(categoryController.text);
              setState(() {}); // Update UI setelah kategori ditambahkan
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Warna background tombol Save
              foregroundColor: Colors.white, // Warna teks tombol Save
            ),
            child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> addCategory(String categoryName) async {
    if (categoryName.isEmpty) {
      print("Category name cannot be empty");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/add_category.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_category_name': categoryName,
          'tenant_id': widget.tenantId,
        }),
      );

      final responseData = jsonDecode(response.body);
      print("Add Category Response: $responseData"); // Debugging

      if (response.statusCode == 200 && responseData['success'] == true) {
        fetchCategories(); // Perbarui kategori setelah sukses
      } else {
        print("Failed to add category: ${responseData['message']}");
      }
    } catch (e) {
      print("Error adding category: $e");
    }
  }

  Future<void> increaseStock(int foodId) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/increase_stock.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'food_id': foodId,
          'tenant_id': widget.tenantId,
          'increment': 1, // Tambah stok 1
        }),
      );

      final responseData = jsonDecode(response.body);
      print("Increase Stock Response: $responseData"); // Debugging

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Ambil kembali data terbaru setelah stok bertambah
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
      print("Decrease Stock Response: $data"); // Debugging

      if (data['success']) {
        if (selectedCategoryId == -1) {
          fetchAllFoods();
        } else {
          fetchFoods(selectedCategoryId!);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      print("Error decreasing stock: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom Header
                Container(
                  color: Color(0xFF075E9C),
                  padding: EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  width: double.infinity,
                  child: Text(
                    'Foods',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
  SizedBox(height: 10),

                // Sisanya dibungkus Expanded agar scrollable
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
              categories.isEmpty
                  ? ElevatedButton(
                      onPressed: showAddCategoryDialog,
                       style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue, 
    foregroundColor: Colors.white, 
  ),
                      child: Text("Add Food Category"),
                    )
                  : Column(
                      children: [
                        // Kategori Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Tombol "All"
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedCategoryId = -1;
                                    });
                                    fetchAllFoods();
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        selectedCategoryId == -1 ? Colors.blue : Colors.grey[200]),
                                    foregroundColor: MaterialStateProperty.all(
                                        selectedCategoryId == -1 ? Colors.white : Colors.black),
                                  ),
                                  child: Text("All"),
                                ),
                              ),

                              // Kategori dari database
                              ...categories.map(
                                (cat) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedCategoryId = cat['food_category_id'];
                                      });
                                      fetchFoods(selectedCategoryId!);
                                    },
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all(
                                          selectedCategoryId == cat['food_category_id']
                                              ? Colors.blue
                                              : Colors.grey[200]),
                                      foregroundColor: MaterialStateProperty.all(
                                          selectedCategoryId == cat['food_category_id']
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                    child: Text(cat['food_category_name']),
                                  ),
                                ),
                              ),

                              // Tombol Tambah Kategori
                              IconButton(
                                icon: Icon(Icons.add),
                                onPressed: showAddCategoryDialog,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10),

                        // Tombol Add New Menu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddFoodPage(
                                    tenantId: widget.tenantId,
                                  ),
                                ),
                              ).then((value) {
                                if (selectedCategoryId == -1) {
                                  fetchAllFoods().then((_) => setState(() {}));
                                } else if (selectedCategoryId != null) {
                                  fetchFoods(selectedCategoryId!).then((_) => setState(() {}));
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              "Add New Menu",
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
            
SizedBox(height: 10),
                    Expanded(
                      child:
                          foods.isEmpty
                              ? Center(child: Text("There is no food."))
                              : ListView.builder(
                                 padding: EdgeInsets.zero, 
                                itemCount: foods.length,
                                itemBuilder: (context, index) {
                                  double foodPrice =
                                      double.tryParse(
                                        foods[index]['food_price'].toString(),
                                      ) ??
                                      0.0;
                                  int foodStock =
                                      int.tryParse(
                                        foods[index]['food_stock'].toString(),
                                      ) ??
                                      0;
                                  String baseUrl =
                                      "http://172.19.10.208/cihosFoodOrder/public/storage/";
                                  String foodImageUrl =
                                      foods[index]['food_image'] ?? '';
                                  String fullImageUrl = foodImageUrl;

                                  return Card(
                                     color: Colors.white,
                                    margin: EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 2, 
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Gambar makanan
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color:
                                                  Colors
                                                      .grey[300], // Placeholder jika gambar tidak ada
                                              image:
                                                  foodImageUrl.isNotEmpty
                                                      ? DecorationImage(
                                                        image: NetworkImage(
                                                          fullImageUrl,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                      : null,
                                            ),
                                          ),
                                          SizedBox(width: 12),

                                          // Informasi makanan
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  foods[index]['food_name'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  "Rp ${formatPrice(foodPrice)}",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    final categoryId =
                                                        foods[index]['food_category_id'];
                                                    if (categoryId != null) {
                                                      // Cek apakah categoryId ada
                                                      final result = await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                context,
                                                              ) => EditFoodPage(
                                                                foodName:
                                                                    foods[index]['food_name'],
                                                                foodPrice:
                                                                    foods[index]['food_price']
                                                                        .toString(),
                                                                foodStock:
                                                                    foods[index]['food_stock']
                                                                        .toString(),
                                                                foodImage:
                                                                    foods[index]['food_image'],
                                                                foodDescription:
                                                                    foods[index]['food_description'],
                                                                tenantId:
                                                                    widget
                                                                        .tenantId,
                                                                foodCategoryId:
                                                                    categoryId, // Pindah ke kategori yang benar
                                                                foodId:
                                                                    foods[index]['food_id'], // Pastikan food_id dikirim
                                                              ),
                                                        ),
                                                      );
                                                      if (result == true) {
                                                        await Future.delayed(
                                                          Duration(
                                                            milliseconds: 300,
                                                          ),
                                                        );
                                                        if (selectedCategoryId ==
                                                            -1) {
                                                          fetchAllFoods();
                                                        } else {
                                                          fetchFoods(
                                                            selectedCategoryId!,
                                                          );
                                                        }
                                                      }
                                                    } else {
                                                      // Handle case where categoryId is null
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            "Category ID is missing for this food item.",
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    // final result = await Navigator.push(
                                                    //   context,
                                                    //   MaterialPageRoute(
                                                    //     builder: (context) => EditFoodPage
                                                    //     (
                                                    //       foodName: foods[index]['food_name'],
                                                    //       foodPrice: foods[index]['food_price'].toString(),
                                                    //       foodStock: foods[index]['food_stock'].toString(),
                                                    //       foodImage: foods[index]['food_image'],
                                                    //       foodDescription: foods[index]['food_description'],
                                                    //       tenantId: widget.tenantId,
                                                    //       // foodCategoryId: selectedCategoryId!,
                                                    //       foodCategoryId: categoryId!,
                                                    //       foodId: foods[index]['food_id'], // Pastikan food_id dikirim
                                                    //     ),

                                                    //   ),
                                                    // );

                                                    // // Jika hasilnya true, refresh daftar makanan
                                                    // if (result == true) {
                                                    //   if (selectedCategoryId == -1) {
                                                    //     fetchAllFoods();
                                                    //   } else {
                                                    //     fetchFoods(selectedCategoryId!);
                                                    //   }
                                                    // }
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 4,
                                                            ),
                                                        backgroundColor:
                                                            Colors.blue,
                                                      ),
                                                  child: Text(
                                                    "Edit",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Bagian stock dan tombol tambah
                                          Column(
                                            children: [
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      color: Colors.grey,
                                                    ),
                                                    onPressed:
                                                        foodStock > 0
                                                            ? () => decreaseStock(
                                                              foods[index]['food_id'],
                                                            )
                                                            : null,
                                                  ),
                                                  Text(
                                                    "$foodStock",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),

                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.add_circle_outline,
                                                      color: Colors.blue,
                                                    ),
                                                    onPressed: () {
                                                      // Tambahkan stock di sini
                                                      increaseStock(
                                                        foods[index]['food_id'],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                "Stock",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    ),
               ],
            ),
    ),
  );
}
}
