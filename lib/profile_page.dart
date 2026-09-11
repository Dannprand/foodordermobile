import 'dart:convert';
// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart'; // pastikan ini di-import

class ProfilePage extends StatefulWidget {
  final String tenantId;
  const ProfilePage({super.key, required this.tenantId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> tenant = {};
  List<dynamic> openingHours = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTenantProfile();
    fetchTenantPhones();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Hapus semua data sesi
    Navigator.pushReplacementNamed(context, '/login'); // Arahkan ke halaman login
  }

  Future<void> fetchTenantProfile() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_tenant_profile.php?tenant_id=${widget.tenantId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['tenant'] != null) {
          setState(() {
            tenant = data['tenant'];
            openingHours = data['opening_hours'];
          });
          await fetchTenantPhones(); // <-- Pindahkan ke sini
        }
      }
    } catch (e) {
      print("Error fetching tenant profile: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> editOpeningHour(int index) async {
    final current = openingHours[index];

    TimeOfDay openTime = TimeOfDay(
      hour: int.parse(current['open_hour'].split(":")[0]),
      minute: int.parse(current['open_hour'].split(":")[1]),
    );

    TimeOfDay closeTime = TimeOfDay(
      hour: int.parse(current['close_hour'].split(":")[0]),
      minute: int.parse(current['close_hour'].split(":")[1]),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Opening Hours for ${current['opening_day']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Select Opening Hour"),
                subtitle: Text(
                  "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}",
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: openTime,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => openTime = picked);
                  }
                },
              ),
              ListTile(
                title: const Text("Select Closing Hour"),
                subtitle: Text(
                  "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}",
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: closeTime,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => closeTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                final formattedOpen =
                    "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}";
                final formattedClose =
                    "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}";

                final response = await http.post(
                  Uri.parse(
                    'http://172.19.10.208/food_order_api/update_opening_hour.php',
                  ),
                  body: {
                    'opening_hour_id': current['opening_hour_id'],
                    'open_hour': formattedOpen,
                    'close_hour': formattedClose,
                  },
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context); // Close dialog
                  fetchTenantProfile(); // Refresh
                } else {
                  print("Failed to update.");
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> editTaxOrCharge(String type, String currentValue) async {
    final controller = TextEditingController(text: currentValue);

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Edit $type"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(suffixText: "%"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url =
                      'http://172.19.10.208/food_order_api/update_tenant_profile.php';
                  final response = await http.post(
                    Uri.parse(url),
                    body: {
                      'tenant_id': widget.tenantId,
                      'type': type.toLowerCase(),
                      'value': controller.text,
                    },
                  );

                  if (response.statusCode == 200) {
                    Navigator.pop(context);
                    fetchTenantProfile();
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  Future<void> updateTenantEmail(String email) async {
    final response = await http.post(
      Uri.parse('http://172.19.10.208/food_order_api/update_tenant_email.php'),
      body: {'tenant_id': tenant['tenant_id'].toString(), 'email': email},
    );

    final result = jsonDecode(response.body);
    if (result['status'] == 'success') {
      setState(() {
        tenant['tenant_email'] = email;
      });
    } else {
      print("Failed to update email: ${result['message']}");
    }
  }

  List<Map<String, dynamic>> tenantPhones = [];

  Future<void> fetchTenantPhones() async {
    try {
      final tenantId = tenant['tenant_id'].toString();
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_tenant_phones.php?tenant_id=$tenantId',
        ),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          setState(() {
            tenantPhones = List<Map<String, dynamic>>.from(result['phones']);
          });
        } else {
          print('Failed to fetch phones: ${result['message']}');
        }
      } else {
        print('Failed to fetch phones: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching phones: $e');
    }
  }

  Future<void> updatePhoneNumber(int phoneId, String number) async {
    final response = await http.post(
      Uri.parse('http://172.19.10.208/food_order_api/update_tenant_phone.php'),
      body: {'tenant_phone_id': phoneId.toString(), 'phone_number': number},
    );

    final result = jsonDecode(response.body);
    if (result['status'] == 'success') {
      await fetchTenantPhones(); // Refresh phone list
    } else {
      print("Failed to update phone: ${result['message']}");
    }
  }

  Future<void> insertPhoneNumber(String number) async {
    final response = await http.post(
      Uri.parse('http://172.19.10.208/food_order_api/add_tenant_phone.php'),
      body: {
        'tenant_id': tenant['tenant_id'].toString(),
        'phone_number': number,
      },
    );

    final result = jsonDecode(response.body);
    if (result['status'] == 'success') {
      await fetchTenantPhones(); // Refresh phone list
    } else {
      print("Failed to add phone: ${result['message']}");
    }
  }

  void editEmail() {
    final controller = TextEditingController(text: tenant['tenant_email']);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Edit Email"),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: "Enter new email"),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await updateTenantEmail(controller.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text("Save"),
              ),
            ],
          ),
    );
  }

  void editPhone(int phoneId, String oldPhone) {
    final controller = TextEditingController(text: oldPhone);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Edit Phone Number"),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: "Enter phone number"),
              keyboardType: TextInputType.phone,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await updatePhoneNumber(phoneId, controller.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text("Save"),
              ),
            ],
          ),
    );
  }

  void addPhone() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Add Phone Number"),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: "Enter new phone number"),
              keyboardType: TextInputType.phone,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await insertPhoneNumber(controller.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: Text("Save"),
              ),
            ],
          ),
    );
  }

  Future<void> changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'http://172.19.10.208/food_order_api/update_tenant_photo.php',
        ),
      );
      request.fields['tenant_id'] = widget.tenantId;
      request.files.add(
        await http.MultipartFile.fromPath('tenant_photo', picked.path),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        fetchTenantProfile();
      }
    }
  }

  void changePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text("Change Password"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      hintText: "Old Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => obscureCurrent = !obscureCurrent);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      hintText: "New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => obscureNew = !obscureNew);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      hintText: "Confirm the New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => obscureConfirm = !obscureConfirm);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel", style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final current = currentPasswordController.text.trim();
                  final newPass = newPasswordController.text.trim();
                  final confirm = confirmPasswordController.text.trim();

                  await updatePassword(
                    current: current,
                    newPass: newPass,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> updatePassword({required String current, required String newPass,}) async {
    final tenantUserId = tenant['tenant_id'];
    final response = await http.post(
      Uri.parse('http://172.19.10.208/food_order_api/update_user_password.php'),
      body: {
        'tenant_user_id': tenantUserId,
        'current_password': current,
        'new_password': newPass,
      },
    );

    final data = jsonDecode(response.body);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['status'] == 'success' ? "Berhasil" : "Gagal"),
        content: Text(data['message']),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (data['status'] == 'success') {
                Navigator.pop(context);
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
           Container(
    color: const Color(0xFF075E9C),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    alignment: Alignment.centerLeft,
    width: double.infinity,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        ElevatedButton.icon(
          onPressed: logout,
          icon: const Icon(Icons.logout),
          label: const Text("Logout"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    ),
  ),
          // Content scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: tenant['tenant_photo'] != null
                              ? NetworkImage(
                                  'http://172.19.10.208/cihosFoodOrder/public/storage/${tenant['tenant_photo']}',
                                )
                              : null,
                          child: tenant['tenant_photo'] == null
                              ? const Icon(Icons.store, size: 48)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: changePhoto,
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      tenant['tenant_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // === EMAIL SECTION ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Email: ${tenant['tenant_email'] ?? '-'}",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editEmail(),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // === TAX & CHARGE SECTION ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Tax: ${tenant['service_tax_percent']}%",
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => editTaxOrCharge(
                          "Tax",
                          tenant['service_tax_percent'],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        "Charge: ${tenant['service_charge_percent']}%",
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => editTaxOrCharge(
                          "Charge",
                          tenant['service_charge_percent'],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: changePasswordDialog,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text("Change Password"),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),


                  // === PHONE SECTION ===
                const Text(
                  "Phone Numbers",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ...tenantPhones.map((phone) {
                  print('DEBUG phone: $phone');
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(phone['phone_number']),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editPhone(
                          phone['tenant_phone_id'],
                          phone['phone_number'],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),

                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      // Check if phone numbers are less than 2
                      if (tenantPhones.length >= 2) {
                        // Show alert if there are already 2 or more phone numbers
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Max Phone Numbers Reached"),
                            content: const Text("You can only have a maximum of 2 phone numbers."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Proceed to add a new phone number
                        addPhone();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Phone Number"),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                  // === OPENING HOURS SECTION ===
                  const Text(
                    "Opening Hours",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...openingHours.map((item) {
                    final index = openingHours.indexOf(item);
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        title: Text(item['opening_day']),
                        subtitle: Text(
                          "Open: ${item['open_hour']} - Close: ${item['close_hour']}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => editOpeningHour(index),
                        ),
                      ),
                    );
                  }).toList(),
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

