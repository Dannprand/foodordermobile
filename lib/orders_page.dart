import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'foods_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'profile_page.dart';
import 'package:intl/intl.dart';
import 'notifications_page.dart';

import 'generate_report.dart';
import 'pdf_preview_page.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'excel_preview_page.dart';

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _currentIndex = 0;
  int? tenantId;

  @override
  void initState() {
    super.initState();
    _loadTenantId();
    getFCMToken();
  }

  Future<void> getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenant_fcm_token', token ?? '');

    // Kamu juga bisa kirim ke backend di sini kalau mau simpan ke database
  }

  Future<void> _loadTenantId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      tenantId = prefs.getInt('tenant_id');
    });
  }

  List<Widget> getPages() {
    return [
      OrdersTab(),
      FoodsPage(tenantId: tenantId!), // Ensure tenantId is not null
      ProfilePage(
        tenantId: tenantId!.toString(),
      ), // Ensure tenantId is not null
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          tenantId == null
              ? Center(
                child: CircularProgressIndicator(),
              ) // Wait until tenantId is loaded
              : getPages()[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xFF1E5BB0),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: "Orders",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fastfood_outlined),
              activeIcon: Icon(Icons.fastfood_rounded),
              label: "Foods",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersTab extends StatefulWidget {
  @override
  _OrdersTabState createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {

  final List<String> filterTypes = ['all', 'year', 'month', 'day', 'custom'];

  String selectedFilterType = 'all';
  int selectedFilterYear = DateTime.now().year;
  int selectedYearForPicker = DateTime.now().year;
  int selectedFilterMonth = DateTime.now().month;
  int selectedMonthYear = DateTime.now().year;
  DateTime selectedFilterDate = DateTime.now();
  DateTime? selectedFromDate;
  DateTime? selectedToDate;


  final yearController = TextEditingController();
  final monthController = TextEditingController();
  final dayController = TextEditingController();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();

  final searchController = TextEditingController();
  String searchQuery = '';

  int selectedStatus = 2;
  List<dynamic> orders = [];
  bool isLoading = true;
  int? tenantId;
  late Timer _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int previousOrderCount = 0;
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(); // Inisialisasi instance
    _notificationService.init(); // Panggil init()

    _resetNotificationFlag().then((_) {
      _loadTenantIdAndFetchOrders(); // fetchOrders() akan jalan setelah flag sudah di-reset
    });
    _startPolling();
  }

  Future<void> _resetNotificationFlag() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Reset hanya sekali pada aplikasi pertama kali dibuka
    bool? isFirstTime = prefs.getBool('isFirstTime');
    if (isFirstTime == null || isFirstTime) {
      prefs.setBool('isNotificationShown', false);
      prefs.setBool('isFirstTime', false);
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (tenantId != null) {
        fetchOrders();
      }
    });
  }

  Future<void> _loadTenantIdAndFetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? savedTenantId = prefs.getInt('tenant_id');

    if (savedTenantId != null) {
      setState(() {
        tenantId = savedTenantId;
      });
      fetchOrders();
    } else {
      print("Tenant ID tidak ditemukan!");
    }
  }

  Future<void> fetchOrders() async {
    if (tenantId == null) {
      print("Tenant ID belum tersedia, batal fetch.");
      return;
    }

    try {
      String query = '';
      if (selectedStatus == 2) {
        query = 'tenant_id=$tenantId&status=$selectedStatus&filter_type=all';
      } else if (selectedStatus == 3) {
        query = 'tenant_id=$tenantId&status=$selectedStatus&filter_type=$selectedFilterType';

        switch (selectedFilterType) {
          case 'year':
            query += '&year=${yearController.text}';
            break;
          case 'month':
            query += '&year=${yearController.text}&month=${monthController.text}';
            break;
          case 'day':
            query += '&date=${dayController.text}';
            break;
          case 'custom':
            query += '&start_date=${startDateController.text}&end_date=${endDateController.text}';
            break;
        }
      }

      final url = 'http://172.19.10.208/food_order_api/get_orders.php?$query';
      print("[fetchOrders] Requesting: $url");
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> fetchedOrders = [];

        if (decoded is List) {
          fetchedOrders = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            fetchedOrders = decoded['data'];
          } else if (decoded['orders'] is List) {
            fetchedOrders = decoded['orders'];
          } else if (decoded['result'] is List) {
            fetchedOrders = decoded['result'];
          } else {
            print("API returned Map without recognised list: $decoded");
          }
        }

        if (selectedStatus == 2) {
          int currentOrderCount = fetchedOrders.length;
          print("Current Order Count: $currentOrderCount");
          print("Previous Order Count: $previousOrderCount");

          if (currentOrderCount > previousOrderCount) {
            print("Order count increased, playing sound and showing notification");
            _playNotificationSound();
            _showOrderNotification();
          }

          previousOrderCount = currentOrderCount;
        }

        setState(() {
          orders = fetchedOrders;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print("Gagal mengambil data pesanan: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching orders: $e");
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/kachingsound.mp3'));
      print("[Sound] Playing kachingsound.mp3");
    } catch (e) {
      print("[Sound] Error playing sound: $e");
    }
  }

  Future<void> _showOrderNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isNotificationShown = prefs.getBool('isNotificationShown') ?? false;

    if (!isNotificationShown) {
      print("[Notification] Menampilkan notifikasi lokal");
      _notificationService.showNotification(
        "Pesanan Baru!",
        "Ada pesanan masuk, segera proses!",
      );

      prefs.setBool('isNotificationShown', true);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    searchController.dispose();
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  void changeStatus(int newStatus) {
    setState(() {
      selectedStatus = newStatus;
      isLoading = true;
      orders = [];
    });
    fetchOrders();
  }

  String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<Map<String, dynamic>?> showFilterDialog(
      BuildContext context, {
        String initialFilterType = 'month',
        int? initialYear,
        int? initialMonth,
        DateTime? initialDate,
        DateTime? initialFromDate,
        DateTime? initialToDate,
      }) {
    int selectedMonth = initialMonth ?? DateTime.now().month;
    DateTime? fromDate = initialFromDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime? toDate = initialToDate ?? DateTime.now();
    DateTime selectedDate = initialDate ?? DateTime.now();
    String filterType = initialFilterType;


    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {

          Widget _buildFilterButton(String type, String label) {
            final isSelected = filterType == type;
            return ElevatedButton(
              onPressed: () => setState(() => filterType = type),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: isSelected ? const Color(0xFF1E5BB0) : const Color(0xFFF1F5F9),
                foregroundColor: isSelected ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF1E5BB0) : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            );
          }

          // Month Picker
          Widget buildMonthPicker() {
            final List<String> monthNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Des'
            ];

            return Column(
              children: [
                // Navigasi Tahun
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => selectedMonthYear--),
                      icon: const Icon(Icons.chevron_left, color: Colors.black),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$selectedMonthYear',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => setState(() => selectedMonthYear++),
                      icon: const Icon(Icons.chevron_right, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: GridView.builder(
                    itemCount: 12,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.5,
                    ),
                    itemBuilder: (context, index) {
                      final isSelected = (index + 1) == selectedMonth;
                      return GestureDetector(
                        onTap: () => setState(() => selectedMonth = index + 1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E5BB0) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1E5BB0) : Colors.grey.shade300,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                : [],
                          ),
                          child: Text(
                            monthNames[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          // Date Picker
          Widget buildDatePicker() {
            // Hitung tanggal awal dan akhir bulan
            final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
            final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
            final daysInMonth = lastDay.day;
            final startWeekday = firstDay.weekday;

            final List<Widget> dayWidgets = [];

            // Header hari
            const List<String> days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
            dayWidgets.addAll(days.map((d) => Center(
              child: Text(
                d,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            )));

            // Spacer awal bulan
            for (int i = 1; i < startWeekday; i++) {
              dayWidgets.add(const SizedBox());
            }

            // Tanggal
            for (int i = 1; i <= daysInMonth; i++) {
              final date = DateTime(selectedDate.year, selectedDate.month, i);
              final isSelected = date.day == selectedDate.day;

              dayWidgets.add(
                GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E5BB0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
                        });
                      },
                    ),
                    Text(
                      '${getMonthName(selectedDate.month)} ${selectedDate.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, selectedDate.day);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: dayWidgets,
                ),
              ],
            );
          }

          // Picker Custom
          Widget buildCustomRangePicker() {
            final firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
            final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
            final daysInMonth = lastDay.day;
            final startWeekday = firstDay.weekday;

            List<Widget> dayWidgets = [];

            const List<String> days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
            dayWidgets.addAll(days.map((d) => Center(
              child: Text(
                d,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            )));

            for (int i = 1; i < startWeekday; i++) {
              dayWidgets.add(const SizedBox());
            }

            for (int i = 1; i <= daysInMonth; i++) {
              final current = DateTime(selectedDate.year, selectedDate.month, i);
              final bool isInRange = fromDate != null &&
                  toDate != null &&
                  !current.isBefore(fromDate!) &&
                  !current.isAfter(toDate!);

              final bool isFrom = fromDate != null && current.isAtSameMomentAs(fromDate!);
              final bool isTo = toDate != null && current.isAtSameMomentAs(toDate!);

              dayWidgets.add(
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (fromDate != null && toDate != null) {
                        fromDate = current;
                        toDate = null;
                      } else if (fromDate == null || current.isBefore(fromDate!)) {
                        fromDate = current;
                        toDate = null;
                      } else {
                        toDate = current;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isFrom || isTo
                          ? const Color(0xFF1E5BB0)
                          : isInRange
                          ? const Color(0xFF1E5BB0).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: isFrom || isTo ? Colors.white : Colors.black,
                        fontWeight: isFrom || isTo ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Header bulan dan tahun
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month - 1);
                        });
                      },
                    ),
                    Text(
                      '${getMonthName(selectedDate.month)} ${selectedDate.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month + 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: dayWidgets,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'From: ${fromDate != null ? "${fromDate!.day}/${fromDate!.month}/${fromDate!.year}" : "-"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'To: ${toDate != null ? "${toDate!.day}/${toDate!.month}/${toDate!.year}" : "-"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(16),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterButton('month', 'Month'),
                        _buildFilterButton('day', 'Day'),
                        _buildFilterButton('custom', 'Custom')
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filterType == 'month') buildMonthPicker(),
                    if (filterType == 'day') buildDatePicker(),
                    if (filterType == 'custom') buildCustomRangePicker(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'type': 'all',
                              'year': DateTime.now().year,
                              'month': DateTime.now().month,
                              'date': DateTime.now(),
                              'fromDate': null,
                              'toDate': null,
                            });
                          },
                          child: const Text(
                            "Reset",
                            style: TextStyle(
                              color: Color(0xFFE11D48),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'type': filterType,
                              'year': filterType == 'month' ? selectedMonthYear : null,
                              'month': selectedMonth,
                              'date': selectedDate,
                              'fromDate': fromDate,
                              'toDate': toDate,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5BB0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          ),
                          child: const Text(
                            "Confirm",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = orders.where((item) {
      if (searchQuery.isEmpty) return true;
      final patientName = (item['patient_name'] ?? '').toString().toLowerCase();
      final orderNumber = (item['order_number'] ?? item['order_id'] ?? '').toString().toLowerCase();
      final room = (item['patient_room'] ?? '').toString().toLowerCase();
      final q = searchQuery.toLowerCase();
      return patientName.contains(q) || orderNumber.contains(q) || room.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar dengan Logo & Icon Notifikasi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/icon/logoapp.png',
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text(
                          "CIPUTRA HOSPITAL",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1.2,
                          ),
                        ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsPage(tenantId: tenantId ?? 5),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
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
                        if (orders.isNotEmpty && selectedStatus == 2)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE11D48),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${orders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Date & Title Header
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
                  const Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status Tabs (On Process & Completed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatusPill(
                    label: "On Process",
                    isSelected: selectedStatus == 2,
                    count: selectedStatus == 2 ? orders.length : null,
                    onTap: () => changeStatus(2),
                  ),
                  const SizedBox(width: 10),
                  _buildStatusPill(
                    label: "Completed",
                    isSelected: selectedStatus == 3,
                    count: selectedStatus == 3 ? orders.length : null,
                    onTap: () => changeStatus(3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar & Filter/Export Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
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
                        decoration: const InputDecoration(
                          hintText: "Search patient name, room, or order #...",
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  if (selectedStatus == 3) ...[
                    const SizedBox(width: 10),
                    // Filter Button
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onPressed: () async {
                          final result = await showFilterDialog(
                            context,
                            initialFilterType: 'month',
                            initialYear: selectedFilterType == 'month' ? selectedMonthYear : selectedFilterYear,
                            initialMonth: selectedFilterMonth,
                            initialDate: selectedFilterDate,
                            initialFromDate: selectedFromDate,
                            initialToDate: selectedToDate,
                          );

                          if (result != null) {
                            String filterType = result['type'];
                            int year = result['year'] ?? DateTime.now().year;
                            int month = result['month'] ?? DateTime.now().month;
                            DateTime date = result['date'] ?? DateTime.now();

                            setState(() {
                              selectedFilterType = filterType;

                              if (filterType == 'year') {
                                selectedFilterYear = year;
                              } else if (filterType == 'month') {
                                selectedMonthYear = year;
                                selectedFilterMonth = month;
                              } else if (filterType == 'day') {
                                selectedFilterDate = date;
                              } else if (filterType == 'custom') {
                                selectedFromDate = result['fromDate'];
                                selectedToDate = result['toDate'];
                              }

                              yearController.text = selectedFilterYear.toString();
                              monthController.text = selectedFilterMonth.toString();
                              dayController.text = DateFormat('yyyy-MM-dd').format(selectedFilterDate);
                              if (filterType == 'custom') {
                                startDateController.text = DateFormat('yyyy-MM-dd').format(selectedFromDate!);
                                endDateController.text = DateFormat('yyyy-MM-dd').format(selectedToDate!);
                              }
                            });

                            fetchOrders();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Export Button
                    Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: Colors.white,
                          textStyle: const TextStyle(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      child: Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Colors.black87,
                            size: 20,
                          ),
                          onSelected: (String value) async {
                            if (tenantId == null) return;

                            try {
                              String title = 'Sales Report';
                              Map<String, String> params = {'tenant_id': tenantId.toString()};

                              switch (selectedFilterType) {
                                case 'year':
                                  params['year'] = yearController.text;
                                  break;
                                case 'month':
                                  params['month'] = monthController.text;
                                  break;
                                case 'day':
                                  params['day'] = dayController.text;
                                  break;
                                case 'custom':
                                  params['from'] = startDateController.text;
                                  params['to'] = endDateController.text;
                                  break;
                                case 'all':
                                  break;
                              }

                              if (value == 'pdf') {
                                final pdfBytes = await generatePdfReport(title, params);
                                final dir = await getApplicationDocumentsDirectory();
                                final file = File('${dir.path}/sales_report.pdf');
                                await file.writeAsBytes(pdfBytes);

                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PdfPreviewPage(filePath: file.path)),
                                  );
                                }
                              } else if (value == 'excel') {
                                final filePath = await generateExcelReport(params);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ExcelPreviewPage(filePath: filePath)),
                                  );
                                }
                              }
                            } catch (e, st) {
                              debugPrint('Export error: $e\n$st');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gagal mengekspor data')),
                                );
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Color(0xFFE11D48), size: 20),
                                  SizedBox(width: 8),
                                  Text('Export PDF', style: TextStyle(color: Colors.black)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'excel',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, color: Color(0xFF16A34A), size: 20),
                                  SizedBox(width: 8),
                                  Text('Export Excel', style: TextStyle(color: Colors.black)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selectedStatus == 3) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5BB0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E5BB0).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: Color(0xFF1E5BB0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedFilterType == 'month'
                              ? "Filter: Bulan ${getMonthName(selectedFilterMonth)} $selectedMonthYear"
                              : selectedFilterType == 'day'
                                  ? "Filter: ${DateFormat('dd MMMM yyyy').format(selectedFilterDate)}"
                                  : selectedFilterType == 'year'
                                      ? "Filter: Tahun $selectedFilterYear"
                                      : selectedFilterType == 'custom' && selectedFromDate != null && selectedToDate != null
                                          ? "Filter: ${DateFormat('dd/MM/yy').format(selectedFromDate!)} - ${DateFormat('dd/MM/yy').format(selectedToDate!)}"
                                          : "Filter: Semua Riwayat (All)",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E5BB0),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedFilterType != 'all')
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilterType = 'all';
                              selectedFromDate = null;
                              selectedToDate = null;
                            });
                            fetchOrders();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF1E5BB0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Order List Section
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E5BB0)),
                    )
                  : filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No orders found.",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            DateTime? orderDate;
                            try {
                              orderDate = DateTime.parse(order['order_date']);
                            } catch (_) {}

                            final formattedTime = orderDate != null
                                ? DateFormat.Hm().format(orderDate)
                                : '';

                            final patientName = order['patient_name'] ?? 'Guest';
                            final orderNumber = order['order_number'] ?? '#ORD-${order['order_id']}';
                            final totalMenus = order['total_menus'] ?? '1';
                            final patientRoom = order['patient_room'];
                            final grandTotal = order['grand_total'] != null
                                ? int.tryParse(order['grand_total'].toString()) ?? 0
                                : null;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OrderDetailPage(
                                          orderId: order['order_id'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Baris: Patient Name & Order Number
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                patientName,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              orderNumber.toString().startsWith('#')
                                                  ? orderNumber.toString()
                                                  : '#$orderNumber',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Lokasi Kamar Pasien jika ada
                                        if (patientRoom != null && patientRoom.toString().isNotEmpty) ...[
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 14,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Room $patientRoom",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        // Badge Menu & Jam Order
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.restaurant_menu_rounded,
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "$totalMenus Menu",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (formattedTime.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time_rounded,
                                                      size: 13,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      formattedTime,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(height: 14),
                                        const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 12),

                                        // Footer Baris: Total Price & Tombol View Detail
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Total Order",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  grandTotal != null
                                                      ? "Rp ${NumberFormat('#,###', 'id_ID').format(grandTotal)}"
                                                      : "Detail pesanan",
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => OrderDetailPage(
                                                      orderId: order['order_id'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E5BB0),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "View Order",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    size: 12,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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

  Widget _buildStatusPill({
    required String label,
    required bool isSelected,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
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

class OrderDetailPage extends StatelessWidget {
  final int orderId;

  OrderDetailPage({required this.orderId});

  Future<void> completeOrder(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? tenantId = prefs.getInt('tenant_id');

    if (tenantId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Tenant ID not found")));
      return;
    }

    try {
      // Update order status to 4 and move order to history
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/complete_order.php'),
        body: {
          'order_id': orderId.toString(),
          'tenant_id': tenantId.toString(),
        },
      );

      if (response.statusCode == 200) {
        print("RESPONSE BODY: ${response.body}");
        final responseData = jsonDecode(response.body);
        if (responseData['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order completed successfully!")),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => OrdersPage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to complete the order")),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error completing order")));
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An error occurred")));
    }
  }

  Future<void> rejectOrder(BuildContext context, int orderId, String rejectReason) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? tenantId = prefs.getInt('tenant_id');

    if (tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tenant ID not found")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://172.19.10.208/food_order_api/reject_order.php'), // Ganti sesuai IP-mu
        body: {
          'order_id': orderId.toString(),
          'tenant_id': tenantId.toString(),
          'rejection_reason': rejectReason,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order rejected successfully!")),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => OrdersPage()),
                (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? "Failed to reject the order")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to reject order: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
    }
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
          'Order Details',
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
      body: FutureBuilder(
        future: fetchOrderDetail(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5BB0)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Color(0xFFE11D48)),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "No data found.",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          } else {
            final List<dynamic> orders = snapshot.data!;
            final order = orders[0]; // Info umum diambil dari data pertama

            final patientRole = order['patient_role'] == 'patient_guardian'
                ? 'Companion'
                : order['patient_role'] == 'patient'
                    ? 'Patient'
                    : order['patient_role'] ?? 'Patient';

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                // Info Pasien & Order Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              order['patient_name'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3), // Soft yellow background
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFACC15)), // Yellow border
                            ),
                            child: Text(
                              patientRole,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309), // Amber / warm golden yellow text for readable contrast
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 12),
                      _buildDetailRow("Order ID", "#${order['order_number'] ?? orderId}"),
                      _buildDetailRow("Room", order['patient_room'] ?? 'N/A'),
                      _buildDetailRow("MRN", order['patient_mrm'] ?? 'N/A'),
                      _buildDetailRow("Date", order['order_date'] ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section List of Orders
                const Text(
                  "Ordered Items",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                ...orders.map((item) {
                  final variations = item['variations'] as List<dynamic>?;
                  final basePrice = int.tryParse(item['food_price'].toString()) ?? 0;
                  final quantity = int.tryParse(item['quantity'].toString()) ?? 1;
                  final variationTotal = variations?.fold<int>(
                        0,
                        (sum, v) => sum + (int.tryParse(v['variation_price'].toString()) ?? 0),
                      ) ??
                      0;
                  final subtotal = (basePrice + variationTotal) * quantity;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. Quantity di depan kiri
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E5BB0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF1E5BB0).withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                "${item['quantity']}x",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E5BB0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. Gambar / Placeholder Makanan
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: Color(0xFF1E5BB0),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 3. Nama Barang & bawahnya Harga
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['food_name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E5BB0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (variations != null && variations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: variations.map((v) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  "• ${v['food_variation_type_name']}: ${v['food_variation_name']} (+Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(v['variation_price'].toString()) ?? 0)})",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                        if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF1E5BB0)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Notes: ${item['notes']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 10),

                // Ringkasan Pembayaran
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        "Total Price",
                        "Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['total_price'].toString()) ?? 0)}",
                      ),
                      _buildSummaryRow(
                        "Service Charge",
                        "Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['service_charge'].toString()) ?? 0)}",
                      ),
                      _buildSummaryRow(
                        "Tax",
                        "Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['order_tax'].toString()) ?? 0)}",
                      ),
                      if ((int.tryParse(order['insurance_discount']?.toString() ?? '0') ?? 0) > 0)
                        _buildSummaryRow(
                          "Discount Benefit Asuransi",
                          "- Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['insurance_discount'].toString()) ?? 0)}",
                          isDiscount: true,
                        ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Grand Total",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['grand_total'].toString()) ?? 0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Aksi jika status On Process (2)
                if (order['order_status_id'] == 2) ...[
                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              String rejectReason = "";
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text(
                                      "Reject Order",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          "Are you sure you want to cancel this order? Please provide a reason.",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          decoration: InputDecoration(
                                            hintText: "Enter reason...",
                                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            focusedBorder: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(Radius.circular(10)),
                                              borderSide: BorderSide(color: Color(0xFFE11D48)),
                                            ),
                                          ),
                                          style: const TextStyle(color: Colors.black),
                                          maxLines: 3,
                                          onChanged: (value) {
                                            rejectReason = value;
                                          },
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          rejectOrder(context, orderId, rejectReason);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE11D48),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text("Reject"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                              backgroundColor: const Color(0xFFE11D48).withValues(alpha: 0.06),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded, size: 18, color: Color(0xFFE11D48)),
                                SizedBox(width: 4),
                                Text(
                                  "Reject",
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Complete Order Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => completeOrder(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  "Complete Order",
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDiscount ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFF16A34A) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>?> fetchOrderDetail(int orderId) async {
    final response = await http.get(
      Uri.parse(
        'http://172.19.10.208/food_order_api/get_order_details.php?order_id=$orderId',
      ),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody is List) {
        return responseBody;
      } else if (responseBody is Map<String, dynamic>) {
        if (responseBody['data'] is List) {
          return responseBody['data'];
        } else if (responseBody['order_details'] is List) {
          return responseBody['order_details'];
        }
      }
      throw Exception('Expected List but got ${responseBody.runtimeType}');
    } else {
      throw Exception('Failed to load order details');
    }
  }
}
