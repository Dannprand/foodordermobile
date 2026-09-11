import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import untuk format angka
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
// import 'package:image_cropper/image_cropper.dart';

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
  TextEditingController nameController = TextEditingController();
  TextEditingController stockController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController variationTypeController = TextEditingController();

  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchCategories();
     fetchVariationTypes();
  }

  Future<void> fetchCategories() async {
    final response = await http.get(Uri.parse(
        'http://172.19.12.73/food_order_api/get_categories.php?tenant_id=${widget.tenantId}'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        categories = data['categories'] ?? [];
        if (categories.isNotEmpty) {
          selectedCategoryId = categories[0]['food_category_id'];
        }
      });
    }
  }

  Future<void> fetchVariationTypes() async {
  final response = await http.get(Uri.parse(
      'http://172.19.12.73/food_order_api/get_variation_types.php?tenant_id=${widget.tenantId}'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    setState(() {
      variationTypes = data['variation_types'] ?? [];
    });
  }
}


  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

//   Future<void> pickImage() async {
//   final pickedFile = await picker.pickImage(source: ImageSource.gallery);

//   if (pickedFile != null) {
//     final croppedFile = await ImageCropper().cropImage(
//       sourcePath: pickedFile.path,
//       aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
//       compressFormat: ImageCompressFormat.jpg,
//       compressQuality: 100,
//       uiSettings: [
//         AndroidUiSettings(
//           toolbarTitle: 'Crop Image',
//           toolbarColor: Colors.deepOrange,
//           toolbarWidgetColor: Colors.white,
//           initAspectRatio: CropAspectRatioPreset.square,
//           lockAspectRatio: true,
//         ),
//         IOSUiSettings(
//           title: 'Crop Image',
//           aspectRatioLockEnabled: true,
//         ),
//       ],
//     );

//     if (croppedFile != null) {
//       setState(() {
//         _image = File(croppedFile.path);
//       });
//     }
//   }
// }


Future<void> addVariationType() async {
  if (variationTypeController.text.isEmpty) {
    print("Variation type name cannot be empty");
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('http://172.19.12.73/food_order_api/add_variation_type.php'),
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



  void formatCurrency(String value) {
    // Hapus koma dan titik biar tidak error saat parsing
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
        priceController.clear(); // Kosongkan jika tidak ada input
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
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
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
  // Validasi input
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
    showError("Please select an image.");
    return;
  }

  // Jika variasi aktif, validasi variasinya juga
  // if (isVariationEnabled) {
  //   if (selectedVariationTypeId == null) {
  //     showError("Please select a variation type.");
  //     return;
  //   }

  //   for (int i = 0; i < variations.length; i++) {
  //     var v = variations[i];
  //     if (v['name'].text.trim().isEmpty ||
  //         v['price'].text.trim().isEmpty ||
  //         v['stock'].text.trim().isEmpty) {
  //       showError("Please complete all fields for Variation ${i + 1}.");
  //       return;
  //     }
  //   }
  // }

if (isVariationEnabled) {
  for (int i = 0; i < variationSets.length; i++) {
    var set = variationSets[i];
    if (set['typeId'] == null) {
      showError("Please select variation type for set ${i + 1}.");
      return;
    }

    for (int j = 0; j < set['variations'].length; j++) {
      var v = set['variations'][j];
      if (v['name'].text.trim().isEmpty ||
          v['price'].text.trim().isEmpty ||
          v['stock'].text.trim().isEmpty) {
        showError("Please complete all fields in variation ${j + 1} of set ${i + 1}.");
        return;
      }
    }
  }
}


  // Kirim data ke server
  print("Attempting to add food...");

  var request = http.MultipartRequest(
    'POST', Uri.parse('http://172.19.12.73/food_order_api/add_food.php'),
  );

  request.fields['food_category_id'] = selectedCategoryId.toString();
  request.fields['food_name'] = nameController.text;
  request.fields['food_price'] = priceController.text.replaceAll(',', '');
  request.fields['food_stock'] = stockController.text;
  request.fields['food_description'] = descriptionController.text;
  request.fields['tenant_id'] = widget.tenantId.toString();

  // if (isVariationEnabled && selectedVariationTypeId != null) {
  //   request.fields['food_variation_type_id'] =
  //       selectedVariationTypeId.toString();

  //   for (int i = 0; i < variations.length; i++) {
  //     request.fields['food_variation_name[$i]'] =
  //         variations[i]['name'].text;
  //     request.fields['food_variation_price[$i]'] =
  //         variations[i]['price'].text.replaceAll(',', '');
  //     request.fields['food_variation_stock[$i]'] =
  //         variations[i]['stock'].text;
  //   }
  // }
 if (isVariationEnabled) {
  List<Map<String, dynamic>> sets = [];

  for (int i = 0; i < variationSets.length; i++) {
    var set = variationSets[i];
    List<Map<String, dynamic>> variations = [];

    for (int j = 0; j < set['variations'].length; j++) {
      var v = set['variations'][j];
      variations.add({
        'name': v['name'].text,
        'price': v['price'].text.replaceAll(',', ''),
        'stock': v['stock'].text,
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
    request.files
        .add(await http.MultipartFile.fromPath('food_image', _image!.path));
  }

  try {
    print("Sending request to server...");
    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    print("Response received: $responseData");
    var jsonData = jsonDecode(responseData);

    if (jsonData['success'] == true) {
      Navigator.pop(context, true);
    } else {
      showError("Failed to add food: ${jsonData['message']}");
    }
  } catch (e) {
    print("Error during addFood request: $e");
    showError("An error occurred while adding food.");
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add New Menu")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
           Card(
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.symmetric(vertical: 0),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Food Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        DropdownButtonFormField(
          value: selectedCategoryId,
          items: categories.map((cat) {
            return DropdownMenuItem(
              value: cat['food_category_id'],
              child: Text(cat['food_category_name']),
            );
          }).toList(),
          onChanged: (value) =>
              setState(() => selectedCategoryId = value as int),
          decoration: InputDecoration(labelText: "Select Category"),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: "Food Name"),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: priceController,
          decoration: InputDecoration(labelText: "Price"),
          keyboardType: TextInputType.number,
          onChanged: formatCurrency,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: stockController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: "Stock",
            hintText: "Enter stock amount",
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: descriptionController,
          decoration: InputDecoration(labelText: "Description"),
        ),
        const SizedBox(height: 16),

        _image == null
            ? Text("No image selected")
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _image!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: pickImage,
          child: Text("Pick Image"),
        ),
      ],
    ),
  ),
),

SizedBox(height: 16),
  Card(
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.symmetric(vertical: 8,),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
    child: CheckboxListTile(
      title: Text(
        "Add Food Variation?",
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        "You can input variations such as size, flavor, etc.",
      style: TextStyle(color: const Color.fromARGB(255, 59, 59, 59), fontSize: 13),
      ),
      value: isVariationEnabled,
      onChanged: (value) {
        setState(() {
          isVariationEnabled = value ?? false;
          if (isVariationEnabled) {
  variationSets = [];
  addVariationSet();
} else {
  variationSets = [];
}
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    ),
  ),
),


            // Dropdown untuk memilih tipe variasi
          if (isVariationEnabled)
  ...variationSets.asMap().entries.map((entry) {
    int setIndex = entry.key;
    var set = entry.value;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Variation Set ${setIndex + 1}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: set['typeId'],
                    items: variationTypes.map((type) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(type['food_variation_type_id'].toString()) ?? 0,
                        child: Text(type['food_variation_type_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        variationSets[setIndex]['typeId'] = value;
                      });
                    },
                    decoration: InputDecoration(labelText: "Select Variation Type"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Add New Variation Type"),
                          content: TextField(
                            controller: set['typeController'],
                            decoration: InputDecoration(labelText: "Variation Type Name"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                variationTypeController = set['typeController'];
                                await addVariationType();
                                variationSets[setIndex]['typeId'] = selectedVariationTypeId;
                                Navigator.pop(context);
                              },
                              child: Text("Save"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...set['variations'].asMap().entries.map((v) {
              int vIndex = v.key;
              var variation = v.value;
              return Container(
                margin: const EdgeInsets.only(top: 12.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: variation['name'],
                      decoration: InputDecoration(labelText: "Variation Name"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: variation['price'],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) => formatVariationCurrency(variation['price'], val),
                      decoration: InputDecoration(
                        labelText: "Variation Price",
                        hintText: "Write 0 if this variation is free",),
                      
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: variation['stock'],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: "Variation Stock"),
                    ),
                    if (vIndex != 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text("Remove", style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            setState(() {
                              variationSets[setIndex]['variations'].removeAt(vIndex);
                            });
                          },
                        ),
                      )
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.add),
                label: Text("Add another variation"),
                onPressed: () {
                  setState(() {
                    variationSets[setIndex]['variations'].add({
                      'name': TextEditingController(),
                      'price': TextEditingController(),
                      'stock': TextEditingController(),
                    });
                  });
                },
              ),
            ),

            if (setIndex != 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      variationSets.removeAt(setIndex);
                    });
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text('Remove Variation Set', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  ).toList(),

  // Tombol Tambah Set
  if (isVariationEnabled)
  ...[
    const SizedBox(height: 16),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: Icon(Icons.add),
        label: Text("Add Variation Set"),
        onPressed: addVariationSet,
      ),
    ),
  ],


SizedBox(height: 16),
            ElevatedButton(onPressed: addFood, child: Text("Add Food")),
          ],
        ),
      ),
    );
  }
}