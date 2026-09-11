import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

class EditFoodPage extends StatefulWidget {
  final int tenantId;
  final int foodId;
  final String foodName;
  final String foodPrice;
  final String foodStock;
  final String foodDescription;
  final int foodCategoryId;
  final String? foodImage; // Tambahkan field untuk gambar makanan

  const EditFoodPage({
    Key? key,
    required this.tenantId,
    required this.foodId,
    required this.foodName,
    required this.foodPrice,
    required this.foodStock,
    required this.foodDescription,
    required this.foodCategoryId,
    this.foodImage, // Tambahkan field gambar
  }) : super(key: key);

  @override
  _EditFoodPageState createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController stockController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  List categories = [];
  int? selectedCategoryId;
  bool isLoading = true; // Tambahkan indikator loading
  String errorMessage = '';
  File? _imageFile;
   List<Map<String, dynamic>> variations = [];
   List<Map<String, dynamic>> variationTypes = [];
 int? selectedVariationTypeId;
TextEditingController variationTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.foodName;
    priceController.text = widget.foodPrice;
    stockController.text = widget.foodStock;
    descriptionController.text = widget.foodDescription;
    selectedCategoryId = widget.foodCategoryId != -1 ? widget.foodCategoryId : null;
  
  print("Selected Category ID after init: $selectedCategoryId");

    
    fetchCategories();
    fetchVariations();
    fetchVariationTypes();
  }

Future<void> fetchVariationTypes() async {
  final response = await http.get(Uri.parse('http://172.19.10.208/food_order_api/get_variation_types_edit.php?tenant_id=${widget.tenantId}'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    setState(() {
      variationTypes = List<Map<String, dynamic>>.from(data['types']);
    });
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

          // Cek apakah kategori yang dipilih masih ada di daftar
          if (!categories.any((c) => c['food_category_id'] == selectedCategoryId)) {
            selectedCategoryId = null; // Set ke null jika tidak ada
            print("Kategori yang ada: ${categories.map((c) => c['food_category_id'])}");
          print("Kategori makanan ini: $selectedCategoryId");
          print("Categories loaded: $categories");
print("Selected Category ID from widget: ${widget.foodCategoryId}");


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

Future<void> fetchVariations() async {
  try {
    final response = await http.get(
      Uri.parse('http://172.19.10.208/food_order_api/get_food_variations.php?food_id=${widget.foodId}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Pastikan struktur JSON-nya ada key 'variations'
      if (data is Map && data.containsKey('variations')) {
        setState(() {
          variations = List<Map<String, dynamic>>.from(data['variations']);
        });
      } else {
        setState(() {
          errorMessage = 'Data variasi tidak ditemukan di response.';
        });
      }
    } else {
      setState(() {
        errorMessage = 'Gagal memuat variasi makanan';
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Terjadi kesalahan saat mengambil variasi: $e';
    });
  }
}


  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

void _addVariationField() {
    setState(() {
      variations.add({"name": "", "price": "", "stock": ""});
    });
  }

  void _removeVariationField(int index) {
    setState(() {
      variations.removeAt(index);
    });
  }

Future<void> addVariationType() async {
  if (variationTypeController.text.isEmpty) {
    print("Variation type name cannot be empty");
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('http://172.19.10.208/food_order_api/add_variation_type.php'),
      body: {
        'food_variation_type_name': variationTypeController.text,
        'tenant_id': widget.tenantId.toString(),  // Kirim tenant_id ke backend
      },
    );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    final jsonData = jsonDecode(response.body);
    if (jsonData['success'] == true) {
      print("Successfully added variation type: ${jsonData['food_variation_type_id']}");
      await fetchVariationTypes();
      setState(() {
        selectedVariationTypeId = jsonData['food_variation_type_id'];
      });
      variationTypeController.clear();
    } else {
      print("Failed to add variation type: ${jsonData['message']}");
    }
  } catch (e) {
    print("Error in addVariationType: $e");
  }
}

Future<void> updateFood() async {
    var uri = Uri.parse('http://172.19.10.208/food_order_api/update_food.php');
    var request = http.MultipartRequest('POST', uri);

    request.fields['food_id'] = widget.foodId.toString();
    request.fields['food_name'] = nameController.text;
    request.fields['food_price'] = priceController.text;
    request.fields['food_stock'] = stockController.text;
    request.fields['food_description'] = descriptionController.text;
    request.fields['food_category_id'] = selectedCategoryId.toString();
   List<Map<String, dynamic>> processedVariations = variations.map((variation) {
  return {
    'food_variation_id': variation['food_variation_id']?.toString(),
    'food_variation_name': variation['name'] ?? variation['food_variation_name'] ?? '',
    'food_variation_price': variation['price'] ?? variation['food_variation_price'] ?? '',
    'food_variation_stock': variation['stock'] ?? variation['food_variation_stock'] ?? '',
    'food_variation_type_id': variation['food_variation_type_id']?.toString() ??
        variation['type_id']?.toString() ?? '',
  };
}).toList();

// ⬇️ Ini debug print-nya, untuk ngecek isi sebelum dikirim ke backend
print("Processed Variations: ${jsonEncode(processedVariations)}");

// ⬇️ Kirim ke backend
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

      if (response.statusCode == 200) {

        final responseData = json.decode(response.body);
        if (responseData['success']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Makanan berhasil diperbarui.")));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['message'])));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memperbarui makanan.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Food")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Food Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a food name" : null,
              ),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? "Please enter a price" : null,
              ),
              TextFormField(
                controller: stockController,
                decoration: InputDecoration(labelText: "Stock"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? "Please enter stock amount" : null,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
              SizedBox(height: 10),

              // Tampilkan pesan error jika kategori gagal di-load
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                ),


              // Dropdown hanya ditampilkan jika kategori sudah dimuat
              isLoading
                  ? Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
  value: selectedCategoryId,
  onChanged: (newValue) {
    setState(() {
      selectedCategoryId = newValue; // Harusnya ini mengubah nilai
    });
    print("New Selected Category: $selectedCategoryId"); // Debugging
  },
  items: categories.map<DropdownMenuItem<int>>((category) {
    return DropdownMenuItem<int>(
      value: category['food_category_id'],
      child: Text(category['food_category_name']),
    );
  }).toList(),
  decoration: InputDecoration(labelText: "Category"),
),

 SizedBox(height: 10),
                Text("Food Image"),
                GestureDetector(
                  onTap: pickImage,
                  child: _imageFile != null
    ? Image.file(_imageFile!, height: 100)
    : (widget.foodImage != null && widget.foodImage!.isNotEmpty
        ? Image.network(
            widget.foodImage!.startsWith("http")
                ? widget.foodImage!
                : "http://172.19.10.208/cihosFoodOrder/public/storage/${widget.foodImage!}",
            height: 100,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.broken_image, size: 50);
            },
          )


        : Container(
            height: 100,
            color: Colors.grey[300],
            child: Icon(Icons.image, size: 50),
          )),

                ),
              SizedBox(height: 20),

              const Text("Food Variations", style: TextStyle(fontWeight: FontWeight.bold)),
...variations.asMap().entries.map((entry) {
  int index = entry.key;
  var variation = entry.value;

  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: variation['food_variation_type_id'] is String
                  ? int.tryParse(variation['food_variation_type_id'])
                  : variation['food_variation_type_id'],
              decoration: const InputDecoration(labelText: 'Variation Type'),
              items: variationTypes.map((type) {
                return DropdownMenuItem<int>(
                  value: int.tryParse(type['food_variation_type_id'].toString()),
                  child: Text(type['food_variation_type_name'].toString()),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  variations[index]['type_id'] = val;
                  variations[index]['food_variation_type_id'] = val;
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Add New Variation Type",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Add New Variation Type"),
                    content: TextField(
                      controller: variationTypeController,
                      decoration: const InputDecoration(labelText: "Variation Type Name"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await addVariationType(); // Pastikan fungsi ini tambah ke DB
                          Navigator.pop(context);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),

                    TextFormField(
                      initialValue: variation['food_variation_name'] ?? '',
                      decoration: const InputDecoration(labelText: 'Variation Name'),
                      onChanged: (val) => variations[index]['name'] = val,
                    ),
                    TextFormField(
                      initialValue: variation['food_variation_price']?.toString() ??'',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Variation Price'),
                      validator: (value) =>
                          value!.isEmpty ? "Write 0 if this variation is free" : null,
                      onChanged: (val) => variations[index]['price'] = val,
                    ),
                    TextFormField(
                      initialValue: variation['food_variation_stock']?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Variation Stock'),
                      onChanged: (val) => variations[index]['stock'] = val,
                    ),
                    TextButton(
                      onPressed: () => _removeVariationField(index),
                      child: const Text("Hapus Variasi"),
                    ),
                    const Divider(),
                  ],
                );
              }).toList(),
              TextButton.icon(
                onPressed: _addVariationField,
                icon: const Icon(Icons.add),
                label: const Text("Tambah Variasi"),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: updateFood,
                  child: Text("Update Food"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//    Future<void> updateFood() async {
//   if (!_formKey.currentState!.validate()) return;

//   print("Selected Category ID: $selectedCategoryId"); // Debugging ✅

//   try {
//     final response = await http.post(
//       Uri.parse('http://172.19.10.208/food_order_api/update_food.php'),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         'food_id': widget.foodId,
//         'tenant_id': widget.tenantId,
//         'food_name': nameController.text,
//         'food_price': priceController.text,
//         'food_stock': stockController.text,
//         'food_description': descriptionController.text,
//         'food_category_id': selectedCategoryId,
//       }),
//     );

//     print("Response Body: ${response.body}"); // Debugging ✅

//     var responseData = jsonDecode(response.body);
//     if (response.statusCode == 200 && responseData['success'] == true) {
//       Navigator.pop(context, true);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(responseData['message'] ?? "Update failed")),
//       );
//     }
//   } catch (e) {
//     print("Error updating food: $e");
//   }
// }
