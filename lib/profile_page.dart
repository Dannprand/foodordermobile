import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications_page.dart';

class ProfilePage extends StatefulWidget {
  final String tenantId;
  const ProfilePage({super.key, required this.tenantId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> tenant = {};
  List<dynamic> openingHours = [];
  List<Map<String, dynamic>> tenantPhones = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTenantProfile();
    fetchTenantPhones();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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
        if (data['tenant'] != null && mounted) {
          setState(() {
            tenant = data['tenant'];
            openingHours = data['opening_hours'] ?? [];
          });
          await fetchTenantPhones();
        }
      }
    } catch (e) {
      debugPrint("Error fetching tenant profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchTenantPhones() async {
    try {
      final tenantId = tenant['tenant_id']?.toString() ?? widget.tenantId;
      final response = await http.get(
        Uri.parse(
          'http://172.19.10.208/food_order_api/get_tenant_phones.php?tenant_id=$tenantId',
        ),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success' && mounted) {
          setState(() {
            tenantPhones = List<Map<String, dynamic>>.from(result['phones'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching phones: $e');
    }
  }

  Future<void> updateTenantEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/update_tenant_email.php'),
        body: {'tenant_id': (tenant['tenant_id'] ?? widget.tenantId).toString(), 'email': email},
      );

      final result = jsonDecode(response.body);
      if (result['status'] == 'success' && mounted) {
        setState(() {
          tenant['tenant_email'] = email;
        });
        _showSnackBar("Email updated successfully.");
      } else {
        _showSnackBar("Failed to update email: ${result['message']}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error updating email: $e", isError: true);
    }
  }

  Future<void> updateTaxOrCharge(String type, String value) async {
    try {
      final url = 'http://172.19.10.208/food_order_api/update_tenant_profile.php';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'tenant_id': widget.tenantId,
          'type': type.toLowerCase(),
          'value': value,
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar("$type rate updated successfully.");
        fetchTenantProfile();
      } else {
        _showSnackBar("Failed to update $type.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error updating $type: $e", isError: true);
    }
  }

  Future<void> updatePhoneNumber(int phoneId, String number) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/update_tenant_phone.php'),
        body: {'tenant_phone_id': phoneId.toString(), 'phone_number': number},
      );

      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        await fetchTenantPhones();
        _showSnackBar("Phone number updated.");
      } else {
        _showSnackBar("Failed to update phone: ${result['message']}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    }
  }

  Future<void> insertPhoneNumber(String number) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/add_tenant_phone.php'),
        body: {
          'tenant_id': (tenant['tenant_id'] ?? widget.tenantId).toString(),
          'phone_number': number,
        },
      );

      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        await fetchTenantPhones();
        _showSnackBar("New phone number added.");
      } else {
        _showSnackBar("Failed to add phone: ${result['message']}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error adding phone: $e", isError: true);
    }
  }

  Future<void> changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.19.10.208/food_order_api/update_tenant_photo.php'),
      );
      request.fields['tenant_id'] = widget.tenantId;
      request.files.add(
        await http.MultipartFile.fromPath('tenant_photo', picked.path),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        _showSnackBar("Profile photo updated.");
        fetchTenantProfile();
      } else {
        _showSnackBar("Failed to upload photo.", isError: true);
      }
    }
  }

  Future<void> updatePassword({required String current, required String newPass}) async {
    final tenantUserId = tenant['tenant_id'] ?? widget.tenantId;
    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/update_user_password.php'),
        body: {
          'tenant_user_id': tenantUserId.toString(),
          'current_password': current,
          'new_password': newPass,
        },
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        _showSnackBar("Password successfully updated.");
      } else {
        _showSnackBar(data['message'] ?? "Failed to change password.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
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
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  // ==================== BOTTOM FLOATING SHEETS ====================

  void _showEditEmailBottomSheet() {
    final controller = TextEditingController(text: tenant['tenant_email']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 14),
              const Text(
                "Account Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                "Update your registered account email address.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(
                  label: "Email Address",
                  hintText: "tenant@ciputrahospital.com",
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E5BB0)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      await updateTenantEmail(controller.text.trim());
                    }
                  },
                  style: _primaryButtonStyle(),
                  child: const Text("Save Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTaxChargeBottomSheet() {
    final taxController = TextEditingController(text: (tenant['service_tax_percent'] ?? '0').toString());
    final chargeController = TextEditingController(text: (tenant['service_charge_percent'] ?? '0').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 14),
              const Text(
                "Tax & Service Charge",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                "Configure default tax and service charge percentages.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: taxController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        label: "Tax Rate",
                        hintText: "10",
                        suffixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Text("%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: chargeController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        label: "Service Charge",
                        hintText: "5",
                        suffixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Text("%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await updateTaxOrCharge("Tax", taxController.text.trim());
                    await updateTaxOrCharge("Charge", chargeController.text.trim());
                  },
                  style: _primaryButtonStyle(),
                  child: const Text("Save Rates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOperatingHoursBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Operating Hours",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                "Set the schedule when your kitchen accepts orders.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: openingHours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = openingHours[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time_rounded, color: Color(0xFF1E5BB0), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['opening_day'] ?? 'Day',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${item['open_hour']} - ${item['close_hour']}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E5BB0), size: 20),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _editOpeningHourDialog(index);
                            },
                          ),
                        ],
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
  }

  Future<void> _editOpeningHourDialog(int index) async {
    final current = openingHours[index];
    TimeOfDay openTime = TimeOfDay(
      hour: int.tryParse(current['open_hour'].split(":")[0]) ?? 8,
      minute: int.tryParse(current['open_hour'].split(":")[1]) ?? 0,
    );

    TimeOfDay closeTime = TimeOfDay(
      hour: int.tryParse(current['close_hour'].split(":")[0]) ?? 20,
      minute: int.tryParse(current['close_hour'].split(":")[1]) ?? 0,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                "Hours for ${current['opening_day']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: const Color(0xFFF8FAFC),
                    title: const Text("Opening Time", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    trailing: const Icon(Icons.access_time_rounded, color: Color(0xFF1E5BB0)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: openTime,
                      );
                      if (picked != null) {
                        setDialogState(() => openTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: const Color(0xFFF8FAFC),
                    title: const Text("Closing Time", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    trailing: const Icon(Icons.access_time_rounded, color: Color(0xFF1E5BB0)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: closeTime,
                      );
                      if (picked != null) {
                        setDialogState(() => closeTime = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BB0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final formattedOpen =
                        "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}";
                    final formattedClose =
                        "${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}";

                    final response = await http.post(
                      Uri.parse('http://172.19.10.208/food_order_api/update_opening_hour.php'),
                      body: {
                        'opening_hour_id': current['opening_hour_id'].toString(),
                        'open_hour': formattedOpen,
                        'close_hour': formattedClose,
                      },
                    );

                    if (response.statusCode == 200) {
                      Navigator.pop(dialogContext);
                      fetchTenantProfile();
                      _showSnackBar("Opening hours updated for ${current['opening_day']}.");
                    } else {
                      _showSnackBar("Failed to update hours.", isError: true);
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPhoneNumbersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Phone Numbers",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                "Registered contact numbers for order coordination (max 2).",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              if (tenantPhones.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text("No phone numbers added yet.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                )
              else
                ...tenantPhones.map((phone) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.phone_rounded, color: Color(0xFF1E5BB0), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            phone['phone_number'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E5BB0), size: 20),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editPhoneDialog(phone['tenant_phone_id'], phone['phone_number']);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),

              const SizedBox(height: 14),

              if (tenantPhones.length < 2)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addPhoneDialog();
                    },
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF1E5BB0), size: 18),
                    label: const Text(
                      "Add Another Phone Number",
                      style: TextStyle(color: Color(0xFF1E5BB0), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E5BB0), width: 1.2),
                      backgroundColor: const Color(0xFF1E5BB0).withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _editPhoneDialog(int phoneId, String oldPhone) {
    final controller = TextEditingController(text: oldPhone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Edit Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: _buildInputDecoration(
            label: "Phone Number",
            hintText: "08xxxxxxxxxx",
            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF1E5BB0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await updatePhoneNumber(phoneId, controller.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5BB0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addPhoneDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Add Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: _buildInputDecoration(
            label: "Phone Number",
            hintText: "08xxxxxxxxxx",
            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF1E5BB0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await insertPhoneNumber(controller.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5BB0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordBottomSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetHandle(),
                    const SizedBox(height: 14),
                    const Text(
                      "Change Password",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Ensure your account is protected with a secure password.",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: _buildInputDecoration(
                        label: "Current Password",
                        hintText: "Enter old password",
                        prefixIcon: const Icon(Icons.lock_clock_outlined, color: Color(0xFF1E5BB0)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: _buildInputDecoration(
                        label: "New Password",
                        hintText: "Enter new password",
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1E5BB0)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: _buildInputDecoration(
                        label: "Confirm New Password",
                        hintText: "Re-enter new password",
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF1E5BB0)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final current = currentPasswordController.text.trim();
                          final newPass = newPasswordController.text.trim();
                          final confirm = confirmPasswordController.text.trim();

                          if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                            _showSnackBar("Please fill in all password fields.", isError: true);
                            return;
                          }
                          if (newPass != confirm) {
                            _showSnackBar("New password and confirmation do not match.", isError: true);
                            return;
                          }

                          await updatePassword(current: current, newPass: newPass);
                        },
                        style: _primaryButtonStyle(),
                        child: const Text("Save New Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 24),
            SizedBox(width: 10),
            Text("Confirm Logout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out from this terminal?",
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  // ==================== UI BUILDERS ====================

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E5BB0), width: 1.6),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E5BB0),
      foregroundColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildProfileAvatar({double radius = 44}) {
    final photoUrl = tenant['tenant_photo'];
    final hasPhoto = photoUrl != null && photoUrl.toString().trim().isNotEmpty;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFED7AA),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                'http://172.19.10.208/cihosFoodOrder/public/storage/$photoUrl',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.restaurant_rounded, color: Color(0xFF9A3412), size: 38),
                ),
              )
            : const Center(
                child: Icon(Icons.restaurant_rounded, color: Color(0xFF9A3412), size: 38),
              ),
      ),
    );
  }

  Widget _buildMenuItemTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1E5BB0), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E5BB0), strokeWidth: 2.5),
        ),
      );
    }

    final tenantName = tenant['tenant_name'] ?? 'Warung Sehat';
    final tenantEmail = tenant['tenant_email'] ?? '-';
    final taxRate = tenant['service_tax_percent'] ?? '0';
    final chargeRate = tenant['service_charge_percent'] ?? '0';

    String operatingHoursSubtitle = "Set opening & closing times";
    if (openingHours.isNotEmpty) {
      final first = openingHours.first;
      operatingHoursSubtitle = "${first['open_hour']} - ${first['close_hour']} (${openingHours.length} Days)";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Ciputra Logo & Notification Bell
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/icon/logoapp.png',
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      "CIPUTRA HOSPITAL",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B6477),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsPage(tenantId: widget.tenantId),
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(Icons.notifications_outlined, size: 20, color: Colors.black87),
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE11D48),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: const Text(
                              "!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Profile Card (Clean without Edit Profile button)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar (tap to change photo) with Camera badge
                          GestureDetector(
                            onTap: changePhoto,
                            child: Stack(
                              children: [
                                _buildProfileAvatar(radius: 46),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E5BB0),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tenant Name
                          Text(
                            tenantName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Location / Subtitle
                          Text(
                            "Ciputra Hospital Surabaya • Tenant #${widget.tenantId}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Status Pill: Open for Orders
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Open for Orders",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // SECTION 1: STORE SETTINGS
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        "STORE SETTINGS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItemTile(
                            icon: Icons.access_time_rounded,
                            title: "Operating Hours",
                            subtitle: operatingHoursSubtitle,
                            onTap: _showOperatingHoursBottomSheet,
                          ),
                          Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                          _buildMenuItemTile(
                            icon: Icons.phone_outlined,
                            title: "Phone Numbers",
                            subtitle: "${tenantPhones.length} registered contact(s)",
                            onTap: _showPhoneNumbersBottomSheet,
                          ),
                          Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                          _buildMenuItemTile(
                            icon: Icons.receipt_long_outlined,
                            title: "Tax & Service Charge",
                            subtitle: "Tax: $taxRate% • Charge: $chargeRate%",
                            onTap: _showTaxChargeBottomSheet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // SECTION 2: ACCOUNT & SECURITY
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        "ACCOUNT & SECURITY",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItemTile(
                            icon: Icons.badge_outlined,
                            title: "Account Information",
                            subtitle: "Email: $tenantEmail",
                            onTap: _showEditEmailBottomSheet,
                          ),
                          Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                          _buildMenuItemTile(
                            icon: Icons.lock_outline_rounded,
                            title: "Change Password",
                            subtitle: "Update your login password",
                            onTap: _showChangePasswordBottomSheet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION 3: LOGOUT BUTTON CARD
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: _showLogoutConfirmDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 20),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Logout",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE11D48),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "End active terminal shift",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer App Info (Mockup Style)
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "FoodOrder Tenant v2.4.0 • Ciputra Hospital Surabaya",
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Connected to Central Hospital Kitchen Gateway",
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
