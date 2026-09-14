import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'food_detail_page.dart';

class NotificationItem {
  final String id;
  final String type; // 'order', 'low_stock', 'out_of_stock', 'store_hours'
  final String title;
  final String message;
  final String time;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  bool isRead;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.isRead = false,
    this.data,
  });
}

class NotificationsPage extends StatefulWidget {
  final dynamic tenantId;
  const NotificationsPage({Key? key, required this.tenantId}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> allNotifications = [];
  bool isLoading = true;
  String selectedFilter = 'Semua';

  final List<String> filterCategories = [
    'Semua',
    'Orderan Masuk',
    'Peringatan Stok',
    'Jam Buka',
  ];

  @override
  void initState() {
    super.initState();
    loadAllNotifications();
  }

  int get tenantIdInt => int.tryParse(widget.tenantId.toString()) ?? 5;

  Future<void> loadAllNotifications() async {
    setState(() {
      isLoading = true;
    });

    List<NotificationItem> items = [];

    await Future.wait([
      _fetchOrderNotifications(items),
      _fetchStockNotifications(items),
      _fetchStoreHoursNotifications(items),
    ]);

    if (mounted) {
      setState(() {
        allNotifications = items;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchOrderNotifications(List<NotificationItem> list) async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_orders.php?tenant_id=$tenantIdInt&status=2&filter_type=all'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['orders'] != null && data['orders'] is List) {
          final List orders = data['orders'];
          for (var o in orders) {
            final orderId = o['order_id']?.toString() ?? '-';
            final patientName = o['patient_name'] ?? 'Pasien';
            final roomNumber = o['room_number'] ?? '-';
            final orderTime = o['order_time'] ?? o['created_at'] ?? 'Baru saja';
            final totalPrice = o['total_price'] != null ? formatCurrency(o['total_price']) : '0';

            list.add(
              NotificationItem(
                id: 'order_$orderId',
                type: 'order',
                title: "Pesanan Baru Masuk #$orderId",
                message: "$patientName (Kamar $roomNumber) memesan makanan. Total: Rp $totalPrice.",
                time: orderTime.toString(),
                badgeText: "Order Masuk",
                badgeColor: const Color(0xFF1E5BB0),
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF1E5BB0),
                iconBgColor: const Color(0xFFEEF2FF),
                data: o,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching order notifications: $e");
    }
  }

  Future<void> _fetchStockNotifications(List<NotificationItem> list) async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_all_foods.php?tenant_id=$tenantIdInt'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['foods'] is List) {
          final List foods = data['foods'];
          for (var f in foods) {
            final foodId = f['food_id'];
            final foodName = f['food_name'] ?? 'Menu';
            final stock = int.tryParse((f['food_stock'] ?? '0').toString()) ?? 0;

            if (stock == 0) {
              // Stok Habis
              list.add(
                NotificationItem(
                  id: 'out_stock_$foodId',
                  type: 'out_of_stock',
                  title: "Stok Habis: $foodName",
                  message: "Menu '$foodName' telah habis (0 porsi). Status menu saat ini otomatis Sold Out.",
                  time: "Perlu Tindakan",
                  badgeText: "Stok Habis",
                  badgeColor: const Color(0xFFE11D48),
                  icon: Icons.remove_shopping_cart_outlined,
                  iconColor: const Color(0xFFE11D48),
                  iconBgColor: const Color(0xFFFEE2E2),
                  data: f,
                ),
              );
            } else if (stock <= 5) {
              // Stok Hampir Habis
              list.add(
                NotificationItem(
                  id: 'low_stock_$foodId',
                  type: 'low_stock',
                  title: "Stok Menipis: $foodName",
                  message: "Tersisa $stock porsi lagi untuk '$foodName'. Segera tambah stok sebelum kehabisan!",
                  time: "Peringatan",
                  badgeText: "Sisa $stock Porsi",
                  badgeColor: const Color(0xFFD97706),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEF3C7),
                  data: f,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching stock notifications: $e");
    }
  }

  Future<void> _fetchStoreHoursNotifications(List<NotificationItem> list) async {
    try {
      final response = await http.get(
        Uri.parse('http://172.19.10.208/food_order_api/get_tenant_profile.php?tenant_id=$tenantIdInt'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final openingHours = data['opening_hours'];
        if (openingHours is List && openingHours.isNotEmpty) {
          final now = DateTime.now();
          final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          final currentDayName = days[now.weekday - 1];

          final todaySchedule = openingHours.firstWhere(
            (item) => (item['opening_day'] ?? '').toString().toLowerCase() == currentDayName.toLowerCase(),
            orElse: () => openingHours.first,
          );

          final openHour = todaySchedule['open_hour'] ?? '08:00';
          final closeHour = todaySchedule['close_hour'] ?? '20:00';

          list.add(
            NotificationItem(
              id: 'store_hours_today',
              type: 'store_hours',
              title: "Jam Operasional Dapur Aktif",
              message: "Dapur Anda dijadwalkan buka hari ini ($currentDayName: $openHour - $closeHour). Dapur siap melayani pesanan pasien.",
              time: "Hari Ini",
              badgeText: "Jam Buka",
              badgeColor: const Color(0xFF16A34A),
              icon: Icons.storefront_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching store hours notification: $e");
    }
  }

  String formatCurrency(dynamic price) {
    if (price == null) return "0";
    String clean = price.toString().replaceAll(',', '').replaceAll('.', '');
    int? parsed = int.tryParse(clean);
    if (parsed == null) return price.toString();
    return NumberFormat("#,###", "en_US").format(parsed);
  }

  List<NotificationItem> get filteredNotifications {
    if (selectedFilter == 'Semua') {
      return allNotifications;
    } else if (selectedFilter == 'Orderan Masuk') {
      return allNotifications.where((n) => n.type == 'order').toList();
    } else if (selectedFilter == 'Peringatan Stok') {
      return allNotifications.where((n) => n.type == 'low_stock' || n.type == 'out_of_stock').toList();
    } else if (selectedFilter == 'Jam Buka') {
      return allNotifications.where((n) => n.type == 'store_hours').toList();
    }
    return allNotifications;
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in allNotifications) {
        item.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Semua notifikasi telah ditandai dibaca."),
        backgroundColor: const Color(0xFF1E5BB0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleNotificationTap(NotificationItem item) async {
    setState(() {
      item.isRead = true;
    });

    if (item.type == 'low_stock' || item.type == 'out_of_stock') {
      final food = item.data;
      if (food != null && food['food_id'] != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodDetailPage(
              tenantId: tenantIdInt,
              foodId: food['food_id'],
              initialFood: food,
            ),
          ),
        );
        if (result == true) {
          loadAllNotifications();
        }
      }
    } else if (item.type == 'order') {
      _showOrderQuickDialog(item);
    }
  }

  void _showOrderQuickDialog(NotificationItem item) {
    final order = item.data ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E5BB0), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              "Pesanan #${order['order_id'] ?? ''}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow("Pasien:", order['patient_name'] ?? '-'),
            _buildDialogRow("Kamar:", order['room_number'] ?? '-'),
            _buildDialogRow("Waktu Order:", order['order_time'] ?? '-'),
            _buildDialogRow("Total Bayar:", "Rp ${formatCurrency(order['total_price'])}", isBold: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1E5BB0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Silakan buka tab 'Orders' untuk memproses atau menyelesaikan pesanan ini.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5BB0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
              color: isBold ? const Color(0xFF1E5BB0) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCount = allNotifications.where((n) => n.type == 'order').length;
    final stockAlertCount = allNotifications.where((n) => n.type == 'low_stock' || n.type == 'out_of_stock').length;
    final unreadCount = allNotifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifikasi",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF1E5BB0)),
              label: const Text(
                "Baca Semua",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E5BB0)),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1E5BB0),
        onRefresh: loadAllNotifications,
        child: Column(
          children: [
            // Top Summary Overview Banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Order Card
                      Expanded(
                        child: _buildSummaryCard(
                          title: "Pesanan Masuk",
                          value: "$orderCount",
                          color: const Color(0xFF1E5BB0),
                          bgColor: const Color(0xFFEEF2FF),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Stock Card
                      Expanded(
                        child: _buildSummaryCard(
                          title: "Peringatan Stok",
                          value: "$stockAlertCount",
                          color: stockAlertCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                          bgColor: stockAlertCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          icon: stockAlertCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Filter Pills
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filterCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = filterCategories[index];
                        final isSelected = selectedFilter == cat;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilter = cat;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1E5BB0) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF1E5BB0) : Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
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
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Notifications List
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E5BB0), strokeWidth: 2.5),
                    )
                  : filteredNotifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredNotifications[index];
                            return _buildNotificationCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    return InkWell(
      onTap: () => _handleNotificationTap(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: !item.isRead ? const Color(0xFF1E5BB0).withValues(alpha: 0.3) : Colors.grey.shade200,
            width: !item.isRead ? 1.4 : 1,
          ),
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
            // Top Row: Category Badge & Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.badgeColor,
                        ),
                      ),
                    ),
                    if (!item.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E5BB0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.time,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Row: Icon + Title & Message
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Action Link (if applicable)
            if (item.type == 'low_stock' || item.type == 'out_of_stock') ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    "Kelola Stok Menu",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5BB0),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E5BB0)),
                ],
              ),
            ] else if (item.type == 'order') ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    "Rincian Order",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5BB0),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E5BB0)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E5BB0).withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 36, color: Color(0xFF1E5BB0)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Tidak Ada Notifikasi",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              "Semua aktivitas dapur dan pesanan dalam kondisi terpantau baik.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: loadAllNotifications,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF1E5BB0)),
              label: const Text(
                "Muat Ulang",
                style: TextStyle(color: Color(0xFF1E5BB0), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E5BB0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
