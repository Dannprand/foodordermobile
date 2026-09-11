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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "Orders",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "Foods"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
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

  int selectedStatus = 2;
  List orders = [];
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
      prefs.setBool('isFirstTime', false); // Set flag agar tidak reset lagi
    }
  }

  Future<void> _loadTenantIdAndFetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    tenantId = prefs.getInt('tenant_id');
    if (tenantId != null) {
      fetchOrders();
    }
  }

  // Start polling for new orders every 5 seconds
  Future<void> fetchOrders({
    bool silent = false,
    bool showNotification = true,
    String query = '',
  }) async {
    if (!silent) setState(() => isLoading = true);

    try {

      if(selectedStatus == 2) {
        query = 'tenant_id=$tenantId&status=$selectedStatus&filter_type=all';
      } else if(selectedStatus == 3) {
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

      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_orders.php?$query'),
      );

      if (response.statusCode == 200) {
        final newOrders = jsonDecode(response.body);
        if (mounted && jsonEncode(orders) != jsonEncode(newOrders)) {
          setState(() {
            orders = newOrders;
            if (!silent) isLoading = false;
          });
        } else {
          if (!silent) setState(() => isLoading = false);
        }
      } else {
        if (!silent) {
          setState(() {
            orders = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          orders = [];
          isLoading = false;
        });
      }
      print("Error fetching orders: $e");
    }
  }


  void changeStatus(int status) {
    setState(() {
      selectedStatus = status;
      isLoading = true; // ini boleh, karena user aktif ganti status
    });
    fetchOrders();
    print(selectedStatus);
  }

  void _startPolling() {
    // Set timer polling hanya setelah data pertama selesai dimuat
    Timer(Duration(seconds: 1), () {
      _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
        await fetchOrders(
          silent: true,
          showNotification: false,
        ); // Tanpa notifikasi
      });
    });
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
    // int selectedYear = initialYear ?? DateTime.now().year;
    int selectedMonth = initialMonth ?? DateTime.now().month;
    DateTime? fromDate = initialFromDate;
    DateTime? toDate = initialToDate;
    DateTime selectedDate = initialDate ?? DateTime.now();
    String filterType = initialFilterType;

    @override
    void initState() {
      super.initState();
      final now = DateTime.now();
      fromDate = now.subtract(const Duration(days: 7));
      toDate = now;
    }


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
                backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                foregroundColor: isSelected ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(label),
            );
          }

          // Year Picker

          // Widget buildYearPicker() {
          //   int baseYear = (selectedYearForPicker ~/ 12) * 12;
          //   List<int> yearRange = List.generate(12, (i) => baseYear + i);
          //
          //   return Column(
          //     children: [
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //         children: [
          //           IconButton(
          //             icon: const Icon(Icons.chevron_left),
          //             onPressed: () {
          //               setState(() => selectedYearForPicker -= 12);
          //             },
          //           ),
          //           Text(
          //             '${yearRange.first} - ${yearRange.last}',
          //             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          //           ),
          //           IconButton(
          //             icon: const Icon(Icons.chevron_right),
          //             onPressed: () {
          //               setState(() => selectedYearForPicker += 12);
          //             },
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 8),
          //       SizedBox(
          //         height: 180,
          //         child: GridView.builder(
          //           itemCount: yearRange.length,
          //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          //             crossAxisCount: 3,
          //             mainAxisSpacing: 8,
          //             crossAxisSpacing: 8,
          //             childAspectRatio: 2.5,
          //           ),
          //           itemBuilder: (context, index) {
          //             final year = yearRange[index];
          //             final isSelected = year == selectedYearForPicker;
          //
          //             return GestureDetector(
          //               onTap: () {
          //                 setState(() {
          //                   selectedYearForPicker = year;
          //                   selectedYear = year; // hasil final
          //                 });
          //               },
          //               child: Container(
          //                 alignment: Alignment.center,
          //                 decoration: BoxDecoration(
          //                   color: isSelected ? Colors.blue : Colors.white,
          //                   borderRadius: BorderRadius.circular(12),
          //                 ),
          //                 child: Text(
          //                   '$year',
          //                   style: TextStyle(
          //                     color: isSelected ? Colors.white : Colors.black,
          //                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          //                   ),
          //                 ),
          //               ),
          //             );
          //           },
          //         ),
          //       ),
          //     ],
          //   );
          // }

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
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$selectedMonthYear',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => setState(() => selectedMonthYear++),
                      icon: const Icon(Icons.chevron_right),
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
                            color: isSelected ? Colors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                                : [],
                          ),
                          child: Text(
                            monthNames[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
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
            dayWidgets.addAll(days.map((d) => Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))));

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
                      color: isSelected ? Colors.blue : Colors.transparent,
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
                      icon: const Icon(Icons.arrow_left),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
                        });
                      },
                    ),
                    Text(
                      '${getMonthName(selectedDate.month)} ${selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right),
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
              child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        // Reset selection
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
                          ? Colors.blue
                          : isInRange
                          ? Colors.blue.withOpacity(0.3)
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
                      icon: const Icon(Icons.arrow_left),
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime(selectedDate.year, selectedDate.month - 1);
                        });
                      },
                    ),
                    Text(
                      '${getMonthName(selectedDate.month)} ${selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right),
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
                    Text('From: ${fromDate != null ? "${fromDate!.day}/${fromDate!.month}/${fromDate!.year}" : "-"}'),
                    Text('To: ${toDate != null ? "${toDate!.day}/${toDate!.month}/${toDate!.year}" : "-"}'),
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
                        // _buildFilterButton('year', 'Year'),
                        _buildFilterButton('month', 'Month'),
                        _buildFilterButton('day', 'Day'),
                        _buildFilterButton('custom', 'Custom')
                      ],
                    ),
                    const SizedBox(height: 12),
                    // if (filterType == 'year') buildYearPicker(),
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
                          child: const Text("Reset", style: TextStyle(color: Colors.red)),
                        ),

                        TextButton(
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
                          child: const Text("Confirm", style: TextStyle(color: Colors.blue)),
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
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: Color(0xFF075E9C),
            padding: EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Orders',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              ChoiceChip(
                label: Text("On Process"),
                selected: selectedStatus == 2,
                onSelected: (_) => changeStatus(2),
                selectedColor: Colors.blue,
                backgroundColor: Colors.white, // Warna latar belakang saat tidak dipilih
                labelStyle: TextStyle(
                  color: selectedStatus == 2 ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(width: 10),
              ChoiceChip(
                label: Text("Completed"),
                selected: selectedStatus == 3,
                onSelected: (_) => changeStatus(3),
                selectedColor: Colors.blue,
                backgroundColor: Colors.white, // Warna latar belakang saat tidak dipilih
                labelStyle: TextStyle(
                  color: selectedStatus == 3 ? Colors.white : Colors.black,
                ),
              ),
              Spacer(),

              if (selectedStatus == 3) ... [
                //Filter
                IconButton(
                  icon: Icon(Icons.filter_alt_outlined, color: Colors.blue),
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

                        // Set controller (kalau kamu pakai di UI)
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

                //download
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: Colors.white,
                      textStyle: TextStyle(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.file_download_outlined, color: Colors.blue),
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
                            params['year'] = yearController.text;
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
                            SnackBar(content: Text('Gagal mengekspor data')),
                          );
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Export PDF'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'excel',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Export Excel'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ]




            ],
          )

          ),

          Expanded(
            child: Container(
              color: Colors.white, // Ini bikin background belakang card putih
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : orders.isEmpty
                      ? Center(child: Text("No orders found."))
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final orderDate = DateTime.parse(order['order_date']);
                            final formattedTime = DateFormat.Hm().format(orderDate); // Hm = 24-hour, mm

                            return Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                title: Text(order['patient_name']),
                                subtitle: Text("${order['total_menus']} Menu - $formattedTime "),
                                trailing: ElevatedButton(
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
                                  child: Text("View order"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                      ),
            ),
          )

        ],
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: Container(
          color: Color(0xFF075E9C),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 12,
                  ), // Sesuaikan padding untuk menurunkan tombol
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 12,
                    ), // Sesuaikan padding untuk menurunkan teks
                    child: Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder(
        future: fetchOrderDetail(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("No data found."));
          } else {
            final List<dynamic> orders = snapshot.data!;
            final order = orders[0]; // Info umum diambil dari data pertama

            return ListView(
              padding: EdgeInsets.all(16),
              children: [
                Text(
                 "Ordered by: ${order['patient_name'] ?? 'N/A'} (${order['patient_role'] == 'patient_guardian' ? 'Companion' : order['patient_role'] == 'patient' ? 'Patient' : order['patient_role'] ?? 'N/A'})",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text("Order ID: ${order['order_number'] ?? 'N/A'}"),
                Text("Room: ${order['patient_room'] ?? 'N/A'}"),
                Text("MRN: ${order['patient_mrm'] ?? 'N/A'}"),
                Text("Date: ${order['order_date'] ?? 'N/A'}"),
                SizedBox(height: 16),
                Divider(),
                Text(
                  "List of Orders:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                ...orders.map((item) {
                  final variations = item['variations'] as List<dynamic>?;

                  final basePrice =
                      int.tryParse(item['food_price'].toString()) ?? 0;
                  final quantity =
                      int.tryParse(item['quantity'].toString()) ?? 1;
                  final variationTotal =
                      variations?.fold<int>(
                        0,
                        (sum, v) =>
                            sum +
                            (int.tryParse(v['variation_price'].toString()) ??
                                0),
                      ) ??
                      0;
                  final subtotal = (basePrice + variationTotal) * quantity;

                  return Card(
                    color: Colors.white,
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${item['quantity']} x ${item['food_name']}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("Harga: Rp ${NumberFormat('#,###', 'id_ID').format(basePrice)}"),
                          if (variations != null && variations.isNotEmpty)
                            ...variations.map(
                              (v) => Text(
                                "- ${v['food_variation_type_name']} : ${v['food_variation_name']} (+Rp ${v['variation_price']})",
                              ),
                            ),
                          if (item['notes'] != null &&
                              item['notes'].toString().isNotEmpty)
                            Text("- Notes: ${item['notes']}"),
                          SizedBox(height: 4),
                          Text(
                            "Subtotal: Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                Divider(),
                SizedBox(height: 8),
                Text(
                 "Total Price: Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['total_price'].toString()) ?? 0)}",
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  "Service Charge: Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['service_charge'].toString()) ?? 0)}",
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  "Tax: Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['order_tax'].toString()) ?? 0)}",
                  style: TextStyle(fontSize: 16),
                ),
                (int.tryParse(order['insurance_discount']?.toString() ?? '0') ?? 0) > 0
                    ? Text(
                  "Discount Benefit Asuransi: - Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['insurance_discount'].toString()) ?? 0)}",
                  style: TextStyle(fontSize: 16),
                )
                    : SizedBox.shrink(),
                SizedBox(height: 4),
                Text(
                 "Grand Total: Rp ${NumberFormat('#,###', 'id_ID').format(int.tryParse(order['grand_total'].toString()) ?? 0)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 16),

                if (order['order_status_id'] == 2) ... [
                  ElevatedButton(
                    onPressed: () {
                      completeOrder(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF075E9C),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    child: Text("Complete the order"),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      String rejectReason = "";
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            title: Text("Reject Order"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Are you sure you want to cancel this order? Please provide a reason why you want to cancel it.",
                                  textAlign: TextAlign.justify,),
                                SizedBox(height: 12),
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: "Enter reason...",
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  maxLines: 4,
                                  onChanged: (value) {
                                    rejectReason = value;
                                  },
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Cancel"),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  rejectOrder(context, orderId, rejectReason);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text("Reject"),
                              ),


                            ],
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    child: Text("Reject the order"),
                  )
                ]

              ],
            );
          }
        },
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
      } else {
        throw Exception('Expected List but got something else');
      }
    } else {
      throw Exception('Failed to load order details');
    }
  }
}
