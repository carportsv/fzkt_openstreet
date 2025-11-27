import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_management_screen.dart';
import 'bookings/bookings_new_ride.dart';
import 'bookings/bookings_new_screen.dart';
import 'bookings/bookings_pending.dart';
import 'bookings/bookings_future.dart';
import 'bookings/bookings_assigned.dart';
import 'bookings/bookings_accepted.dart';
import 'bookings/bookings_completed.dart';
import 'bookings/bookings_payment_pending.dart';
import 'bookings/bookings_cancelled.dart';
import 'bookings/bookings_rejected.dart';
import 'bookings/bookings_deleted.dart';
import 'bookings/bookings_all_screen.dart';
import 'drivers_admin/drivers_admin_index.dart';
import 'drivers_admin/drivers_list_screen.dart';
import 'customers/customers_admin_index.dart';
import 'customers/customers_list_screen.dart';
import 'pricing/general_pricing_screen.dart';
import 'pricing/vehicle_pricing_screen.dart';
import 'pricing/hourly_packages_screen.dart';
import 'pricing/location_category_screen.dart';
import 'pricing/fixed_pricing_screen.dart';
import 'pricing/distance_slab_screen.dart';
import 'pricing/congestion_charges_screen.dart';
import 'pricing/discounts_date_screen.dart';
import 'pricing/discounts_surcharge_location_screen.dart';
import 'pricing/vouchers_screen.dart';
import '../../auth/login_screen.dart';
import '../../auth/supabase_service.dart';
import 'package:flutter/foundation.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isDrawerExpanded = true;
  Widget _selectedContent = const _HomeDashboardContent();
  final SupabaseService _supabaseService = SupabaseService();

  // Contadores de bookings
  int _bookingsNewCount = 0;
  int _bookingsPendingCount = 0;
  int _bookingsFutureCount = 0;
  int _bookingsAssignedCount = 0;
  int _bookingsAcceptedCount = 0;
  int _bookingsCompletedCount = 0;
  int _bookingsPaymentPendingCount = 0;
  int _bookingsCancelledCount = 0;
  int _bookingsRejectedCount = 0;
  int _bookingsDeletedCount = 0;
  int _bookingsAllCount = 0;

  void _toggleDrawer() => setState(() => _isDrawerExpanded = !_isDrawerExpanded);

  @override
  void initState() {
    super.initState();
    _loadBookingCounts();
  }

  Future<void> _loadBookingCounts() async {
    try {
      final supabaseClient = _supabaseService.client;

      // Contar bookings por status - usar select y contar la longitud
      final startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      final newData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'requested')
          .gte('created_at', startOfToday.toIso8601String());

      final pendingData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'requested')
          .isFilter('driver_id', null);

      final futureData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('is_scheduled', true);

      final assignedData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .or('status.eq.accepted,status.eq.assigned')
          .not('driver_id', 'is', null);

      final acceptedData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'accepted');

      final completedData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'completed');

      final paymentPendingData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'completed')
          .or('payment_method.eq.card,payment_method.eq.transfer');

      final cancelledData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'cancelled');

      final rejectedData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'rejected');

      final deletedData = await supabaseClient
          .from('ride_requests')
          .select('id')
          .eq('status', 'deleted');

      final allData = await supabaseClient.from('ride_requests').select('id');

      if (mounted) {
        setState(() {
          _bookingsNewCount = (newData as List).length;
          _bookingsPendingCount = (pendingData as List).length;
          _bookingsFutureCount = (futureData as List).length;
          _bookingsAssignedCount = (assignedData as List).length;
          _bookingsAcceptedCount = (acceptedData as List).length;
          _bookingsCompletedCount = (completedData as List).length;
          _bookingsPaymentPendingCount = (paymentPendingData as List).length;
          _bookingsCancelledCount = (cancelledData as List).length;
          _bookingsRejectedCount = (rejectedData as List).length;
          _bookingsDeletedCount = (deletedData as List).length;
          _bookingsAllCount = (allData as List).length;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando contadores de bookings: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      debugPrint('[AdminHomeScreen] Iniciando cierre de sesión...');

      // 1. Cerrar sesión de Firebase primero
      await FirebaseAuth.instance.signOut();
      debugPrint('[AdminHomeScreen] ✅ Sesión de Firebase cerrada');

      // 2. Esperar un momento para que Firebase procese el logout
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Cerrar sesión de Google Sign-In también
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        await googleSignIn.signOut();
        debugPrint('[AdminHomeScreen] ✅ Sesión de Google Sign-In cerrada');
      } catch (e) {
        debugPrint('[AdminHomeScreen] ⚠️ Error al cerrar sesión de Google: $e');
        // Continuar aunque falle Google Sign-In
      }

      // 4. Esperar un momento adicional para asegurar que todo se limpie
      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Navegar a la pantalla de login y limpiar el stack de navegación
      if (mounted) {
        debugPrint('[AdminHomeScreen] 🚀 Navegando a LoginScreen...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSelectItem(String key) {
    final isWideScreen = MediaQuery.of(context).size.width > 768;
    Widget content;

    switch (key) {
      case 'users':
        content = const UserManagementScreen();
        break;
      case 'new_booking':
        content = const NewBookingScreen();
        break;
      case 'bookings_new':
        content = const BookingsNewScreen();
        break;
      case 'bookings_pending':
        content = const BookingsPendingScreen();
        break;
      case 'bookings_future':
        content = const BookingsFutureScreen();
        break;
      case 'bookings_assigned':
        content = const BookingsAssignedScreen();
        break;
      case 'bookings_accepted':
        content = const BookingsAcceptedScreen();
        break;
      case 'bookings_completed':
        content = const BookingsCompletedScreen();
        break;
      case 'bookings_payment_pending':
        content = const BookingsPaymentPendingScreen();
        break;
      case 'bookings_cancelled':
        content = const BookingsCancelledScreen();
        break;
      case 'bookings_rejected':
        content = const BookingsRejectedScreen();
        break;
      case 'bookings_deleted':
        content = const BookingsDeletedScreen();
        break;
      case 'bookings_all':
        content = const BookingsAllScreen();
        break;
      case 'drivers':
        content = const DriversAdminIndex();
        break;
      case 'drivers_active':
        content = const DriversListScreen(status: 'active');
        break;
      case 'drivers_suspended':
        content = const DriversListScreen(status: 'suspended');
        break;
      case 'drivers_pending':
        content = const DriversListScreen(status: 'pending');
        break;
      case 'drivers_deleted':
        content = const DriversListScreen(status: 'deleted');
        break;
      case 'customers':
        content = const CustomersAdminIndex();
        break;
      case 'customers_active':
        content = const CustomersListScreen(status: 'active');
        break;
      case 'customers_suspended':
        content = const CustomersListScreen(status: 'suspended');
        break;
      case 'customers_pending':
        content = const CustomersListScreen(status: 'pending');
        break;
      case 'customers_deleted':
        content = const CustomersListScreen(status: 'deleted');
        break;
      case 'customers_deletion_requests':
        content = const CustomersListScreen(status: 'deletion_requests');
        break;
      case 'pricing_general':
        content = const GeneralPricingScreen();
        break;
      case 'pricing_vehicle':
        content = const VehiclePricingScreen();
        break;
      case 'pricing_hourly':
        content = const HourlyPackagesScreen();
        break;
      case 'pricing_location':
        content = const LocationCategoryScreen();
        break;
      case 'pricing_fixed':
        content = const FixedPricingScreen();
        break;
      case 'pricing_distance':
        content = const DistanceSlabScreen();
        break;
      case 'pricing_congestion':
        content = const CongestionChargesScreen();
        break;
      case 'pricing_discounts_date':
        content = const DiscountsDateScreen();
        break;
      case 'pricing_discounts_location':
        content = const DiscountsSurchargeLocationScreen();
        break;
      case 'pricing_vouchers':
        content = const VouchersScreen();
        break;
      case 'home':
      default:
        content = const _HomeDashboardContent();
        break;
    }

    if (isWideScreen) {
      setState(() => _selectedContent = content);
    } else {
      // En móvil, cerrar el drawer primero
      Navigator.pop(context);

      // Si es "home", no navegar porque ya estamos en el home
      if (key == 'home') {
        // Ya estamos en el home, solo cerrar el drawer
        return;
      }

      // Para otras pantallas, envolver en Scaffold con AppBar y drawer para móvil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _AdminScreenWrapper(
            title: _getScreenTitle(key),
            content: content,
            onSelectItem: _onSelectItem,
            onLogout: _handleLogout,
            bookingCounts: {
              'new': _bookingsNewCount,
              'pending': _bookingsPendingCount,
              'future': _bookingsFutureCount,
              'assigned': _bookingsAssignedCount,
              'accepted': _bookingsAcceptedCount,
              'completed': _bookingsCompletedCount,
              'payment_pending': _bookingsPaymentPendingCount,
              'cancelled': _bookingsCancelledCount,
              'rejected': _bookingsRejectedCount,
              'deleted': _bookingsDeletedCount,
              'all': _bookingsAllCount,
            },
          ),
        ),
      );
    }
  }

  String _getScreenTitle(String key) {
    switch (key) {
      case 'users':
        return 'Users';
      case 'new_booking':
        return 'New Booking';
      case 'bookings_new':
        return 'Bookings - New';
      case 'bookings_pending':
        return 'Bookings - Pending';
      case 'bookings_future':
        return 'Bookings - Future';
      case 'bookings_assigned':
        return 'Bookings - Assigned';
      case 'bookings_accepted':
        return 'Bookings - Accepted';
      case 'bookings_completed':
        return 'Bookings - Completed';
      case 'bookings_payment_pending':
        return 'Bookings - Payment Pending';
      case 'bookings_cancelled':
        return 'Bookings - Cancelled';
      case 'bookings_rejected':
        return 'Bookings - Rejected';
      case 'bookings_deleted':
        return 'Bookings - Deleted';
      case 'bookings_all':
        return 'Bookings - All';
      case 'drivers':
        return 'Drivers';
      case 'drivers_active':
        return 'Drivers - Active';
      case 'drivers_suspended':
        return 'Drivers - Suspended';
      case 'drivers_pending':
        return 'Drivers - Pending';
      case 'drivers_deleted':
        return 'Drivers - Deleted';
      case 'customers':
        return 'Customers';
      case 'customers_active':
        return 'Customers - Active';
      case 'customers_suspended':
        return 'Customers - Suspended';
      case 'customers_pending':
        return 'Customers - Pending';
      case 'customers_deleted':
        return 'Customers - Deleted';
      case 'customers_deletion_requests':
        return 'Customers - Deletion Requests';
      case 'pricing_general':
        return 'General Pricing';
      case 'pricing_vehicle':
        return 'Vehicle Pricing';
      case 'pricing_hourly':
        return 'Hourly Packages';
      case 'pricing_location':
        return 'Location Category';
      case 'pricing_fixed':
        return 'Fixed Pricing';
      case 'pricing_distance':
        return 'Distance Slab';
      case 'pricing_congestion':
        return 'Congestion Charges';
      case 'pricing_discounts_date':
        return 'Discounts / Surcharge - Date';
      case 'pricing_discounts_location':
        return 'Discounts / Surcharge - Location';
      case 'pricing_vouchers':
        return 'Vouchers';
      default:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).size.width > 768 ? _buildWideLayout() : _buildNarrowLayout();
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: AppBar(title: const Text('cuzcatlansv.ride')),
      drawer: _buildAdminDrawer(isExpanded: true),
      body: const _HomeDashboardContent(),
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF1D4ED8),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isDrawerExpanded ? 260 : 80,
            child: _buildAdminDrawer(isExpanded: _isDrawerExpanded),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: _toggleDrawer,
                        tooltip: 'Toggle Menu',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    child: Container(color: Colors.white, child: _selectedContent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDrawer({required bool isExpanded}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
                child: isExpanded
                    ? const Text(
                        'cuzcatlansv.ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.directions_car, color: Colors.white, size: 30),
              ),
              _buildMenuItem(
                text: 'Home',
                icon: Icons.home,
                onTap: () => _onSelectItem('home'),
                isExpanded: isExpanded,
              ),
              _buildMenuItem(
                text: 'Users',
                icon: Icons.people,
                onTap: () => _onSelectItem('users'),
                isExpanded: isExpanded,
              ),
              _buildExpansionTile(
                title: 'Bookings',
                icon: Icons.calendar_today,
                isExpanded: isExpanded,
                children: [
                  // vvvv 3. CONNECTED THE BUTTON ACTION vvvv
                  _buildBookingStatusMenuItem(
                    text: 'New',
                    count: _bookingsNewCount,
                    onTap: () => _onSelectItem('new_booking'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Pending',
                    count: _bookingsPendingCount,
                    onTap: () => _onSelectItem('bookings_pending'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Future',
                    count: _bookingsFutureCount,
                    onTap: () => _onSelectItem('bookings_future'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Assigned',
                    count: _bookingsAssignedCount,
                    onTap: () => _onSelectItem('bookings_assigned'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Accepted',
                    count: _bookingsAcceptedCount,
                    onTap: () => _onSelectItem('bookings_accepted'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Completed',
                    count: _bookingsCompletedCount,
                    onTap: () => _onSelectItem('bookings_completed'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Payment Pending',
                    count: _bookingsPaymentPendingCount,
                    onTap: () => _onSelectItem('bookings_payment_pending'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Cancelled',
                    count: _bookingsCancelledCount,
                    onTap: () => _onSelectItem('bookings_cancelled'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Rejected',
                    count: _bookingsRejectedCount,
                    onTap: () => _onSelectItem('bookings_rejected'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Deleted',
                    count: _bookingsDeletedCount,
                    onTap: () => _onSelectItem('bookings_deleted'),
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'All',
                    count: _bookingsAllCount,
                    onTap: () => _onSelectItem('bookings_all'),
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Drivers',
                icon: Icons.local_taxi,
                isExpanded: isExpanded,
                children: [
                  _buildDriverStatusMenuItem(
                    text: 'Active',
                    onTap: () => _onSelectItem('drivers_active'),
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Suspended',
                    onTap: () => _onSelectItem('drivers_suspended'),
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Pending',
                    onTap: () => _onSelectItem('drivers_pending'),
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Deleted',
                    onTap: () => _onSelectItem('drivers_deleted'),
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Customers',
                icon: Icons.person_search,
                isExpanded: isExpanded,
                children: [
                  _buildCustomerStatusMenuItem(
                    text: 'Active',
                    onTap: () => _onSelectItem('customers_active'),
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Suspended',
                    onTap: () => _onSelectItem('customers_suspended'),
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Pending',
                    onTap: () => _onSelectItem('customers_pending'),
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Deleted',
                    onTap: () => _onSelectItem('customers_deleted'),
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Deletion Requests',
                    onTap: () => _onSelectItem('customers_deletion_requests'),
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Pricing',
                icon: Icons.price_change,
                isExpanded: isExpanded,
                children: [
                  _buildPricingMenuItem(
                    text: 'General',
                    onTap: () => _onSelectItem('pricing_general'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Vehicle Pricing',
                    onTap: () => _onSelectItem('pricing_vehicle'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Hourly Packages',
                    onTap: () => _onSelectItem('pricing_hourly'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Location Category',
                    onTap: () => _onSelectItem('pricing_location'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Fixed Pricing',
                    onTap: () => _onSelectItem('pricing_fixed'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Distance Slab',
                    onTap: () => _onSelectItem('pricing_distance'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Congestion Charges',
                    onTap: () => _onSelectItem('pricing_congestion'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Discounts - Date',
                    onTap: () => _onSelectItem('pricing_discounts_date'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Discounts - Location',
                    onTap: () => _onSelectItem('pricing_discounts_location'),
                  ),
                  _buildPricingMenuItem(
                    text: 'Vouchers',
                    onTap: () => _onSelectItem('pricing_vouchers'),
                  ),
                ],
              ),
              _buildMenuItem(
                text: 'Settings',
                icon: Icons.settings,
                onTap: () {},
                isExpanded: isExpanded,
              ),
              const Divider(color: Colors.white24, indent: 16, endIndent: 16),
              _buildMenuItem(
                text: 'Cerrar Sesión',
                icon: Icons.logout,
                onTap: _handleLogout,
                isExpanded: isExpanded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required bool isExpanded,
  }) {
    return Tooltip(
      message: isExpanded ? '' : text,
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: isExpanded ? Text(text, style: const TextStyle(color: Colors.white70)) : null,
        onTap: onTap,
        hoverColor: Colors.black.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildBookingStatusMenuItem({
    required String text,
    required int count,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
            const Spacer(),
            Text('($count)', style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildDriverStatusMenuItem({required String text, required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildCustomerStatusMenuItem({required String text, required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildPricingMenuItem({required String text, required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isExpanded,
  }) {
    if (!isExpanded) {
      return Tooltip(
        message: title,
        child: ListTile(
          leading: Icon(icon, color: Colors.white70),
          onTap: _toggleDrawer,
        ),
      );
    }
    return ExpansionTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}

/// Widget wrapper para pantallas navegadas en móvil
/// Proporciona el drawer y maneja la navegación correctamente
class _AdminScreenWrapper extends StatelessWidget {
  final String title;
  final Widget content;
  final Function(String) onSelectItem;
  final VoidCallback onLogout;
  final Map<String, int> bookingCounts;

  const _AdminScreenWrapper({
    required this.title,
    required this.content,
    required this.onSelectItem,
    required this.onLogout,
    this.bookingCounts = const {},
  });

  Widget _buildAdminDrawer({required bool isExpanded, required BuildContext context}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(right: BorderSide(color: Colors.white24)),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'cuzcatlansv.ride',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              _buildMenuItem(
                text: 'Home',
                icon: Icons.home,
                onTap: () {
                  // Navegar de vuelta al AdminHomeScreen principal
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                isExpanded: isExpanded,
                context: context,
              ),
              _buildMenuItem(
                text: 'Users',
                icon: Icons.people,
                onTap: () {
                  // Si ya estamos en Users, solo cerrar el drawer
                  Navigator.of(context).pop();
                },
                isExpanded: isExpanded,
                context: context,
              ),
              _buildExpansionTile(
                title: 'Bookings',
                icon: Icons.calendar_today,
                isExpanded: isExpanded,
                context: context,
                children: [
                  _buildBookingStatusMenuItem(
                    text: 'New',
                    count: bookingCounts['new'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'New Booking',
                            content: const NewBookingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Pending',
                    count: bookingCounts['pending'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Pending',
                            content: const BookingsPendingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Future',
                    count: bookingCounts['future'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Future',
                            content: const BookingsFutureScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Assigned',
                    count: bookingCounts['assigned'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Assigned',
                            content: const BookingsAssignedScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Accepted',
                    count: bookingCounts['accepted'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Accepted',
                            content: const BookingsAcceptedScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Completed',
                    count: bookingCounts['completed'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Completed',
                            content: const BookingsCompletedScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Payment Pending',
                    count: bookingCounts['payment_pending'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Payment Pending',
                            content: const BookingsPaymentPendingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Cancelled',
                    count: bookingCounts['cancelled'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Cancelled',
                            content: const BookingsCancelledScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Rejected',
                    count: bookingCounts['rejected'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Rejected',
                            content: const BookingsRejectedScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'Deleted',
                    count: bookingCounts['deleted'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - Deleted',
                            content: const BookingsDeletedScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                            bookingCounts: bookingCounts,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildBookingStatusMenuItem(
                    text: 'All',
                    count: bookingCounts['all'] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Bookings - All',
                            content: const BookingsAllScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Drivers',
                icon: Icons.local_taxi,
                isExpanded: isExpanded,
                context: context,
                children: [
                  _buildDriverStatusMenuItem(
                    text: 'Active',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Drivers - Active',
                            content: const DriversListScreen(status: 'active'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Suspended',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Drivers - Suspended',
                            content: const DriversListScreen(status: 'suspended'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Pending',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Drivers - Pending',
                            content: const DriversListScreen(status: 'pending'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildDriverStatusMenuItem(
                    text: 'Deleted',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Drivers - Deleted',
                            content: const DriversListScreen(status: 'deleted'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Customers',
                icon: Icons.person_search,
                isExpanded: isExpanded,
                context: context,
                children: [
                  _buildCustomerStatusMenuItem(
                    text: 'Active',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Customers - Active',
                            content: const CustomersListScreen(status: 'active'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Suspended',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Customers - Suspended',
                            content: const CustomersListScreen(status: 'suspended'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Pending',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Customers - Pending',
                            content: const CustomersListScreen(status: 'pending'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Deleted',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Customers - Deleted',
                            content: const CustomersListScreen(status: 'deleted'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildCustomerStatusMenuItem(
                    text: 'Deletion Requests',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Customers - Deletion Requests',
                            content: const CustomersListScreen(status: 'deletion_requests'),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                ],
              ),
              _buildExpansionTile(
                title: 'Pricing',
                icon: Icons.price_change,
                isExpanded: isExpanded,
                context: context,
                children: [
                  _buildPricingMenuItem(
                    text: 'General',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'General Pricing',
                            content: const GeneralPricingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Vehicle Pricing',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Vehicle Pricing',
                            content: const VehiclePricingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Hourly Packages',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Hourly Packages',
                            content: const HourlyPackagesScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Location Category',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Location Category',
                            content: const LocationCategoryScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Fixed Pricing',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Fixed Pricing',
                            content: const FixedPricingScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Distance Slab',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Distance Slab',
                            content: const DistanceSlabScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Congestion Charges',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Congestion Charges',
                            content: const CongestionChargesScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Discounts - Date',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Discounts / Surcharge - Date',
                            content: const DiscountsDateScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Discounts - Location',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Discounts / Surcharge - Location',
                            content: const DiscountsSurchargeLocationScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                  _buildPricingMenuItem(
                    text: 'Vouchers',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _AdminScreenWrapper(
                            title: 'Vouchers',
                            content: const VouchersScreen(),
                            onSelectItem: (key) {},
                            onLogout: onLogout,
                          ),
                        ),
                      );
                    },
                    context: context,
                  ),
                ],
              ),
              _buildMenuItem(
                text: 'Settings',
                icon: Icons.settings,
                onTap: () {},
                isExpanded: isExpanded,
                context: context,
              ),
              const Divider(color: Colors.white24, indent: 16, endIndent: 16),
              _buildMenuItem(
                text: 'Cerrar Sesión',
                icon: Icons.logout,
                onTap: onLogout,
                isExpanded: isExpanded,
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required bool isExpanded,
    required BuildContext context,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(text, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.of(context).pop(); // Cerrar drawer primero
        onTap();
      },
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildBookingStatusMenuItem({
    required String text,
    required int count,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
            const Spacer(),
            Text('($count)', style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildDriverStatusMenuItem({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildCustomerStatusMenuItem({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildPricingMenuItem({
    required String text,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return ListTile(
      dense: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.white38),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      hoverColor: Colors.black.withValues(alpha: 0.2),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required List<Widget> children,
    required BuildContext context,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false, // Deshabilitar la flecha automática
        leading: Builder(
          builder: (BuildContext scaffoldContext) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(scaffoldContext).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: _buildAdminDrawer(isExpanded: true, context: context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Si el contenido tiene un Expanded, no envolver en SingleChildScrollView
          // De lo contrario, envolver para permitir scroll
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        },
      ),
    );
  }
}

class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;

    // Calcular número de columnas según el ancho de pantalla
    int crossAxisCount;
    if (screenWidth < 400) {
      crossAxisCount = 1; // Móvil pequeño: 1 columna
    } else if (screenWidth < 600) {
      crossAxisCount = 2; // Móvil grande: 2 columnas
    } else if (screenWidth < 1200) {
      crossAxisCount = 2; // Tablet: 2 columnas
    } else {
      crossAxisCount = 4; // Desktop: 4 columnas
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, Admin!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A202C),
              fontSize: isTablet ? null : 24,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isTablet ? 16 : 12,
            mainAxisSpacing: isTablet ? 16 : 12,
            childAspectRatio: isDesktop ? 2.5 : (isTablet ? 2.2 : 2.0),
            children: [
              _buildSummaryCard(context, 'Total Users', '1', Icons.people_outline, Colors.blue),
              _buildSummaryCard(
                context,
                'Total Drivers',
                '0',
                Icons.local_taxi_outlined,
                Colors.orange,
              ),
              _buildSummaryCard(
                context,
                'Completed Rides',
                '0',
                Icons.check_circle_outline,
                Colors.green,
              ),
              _buildSummaryCard(
                context,
                'Pending Bookings',
                '0',
                Icons.pending_actions_outlined,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmall = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isTablet ? 32 : (isSmall ? 24 : 28)),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 22 : (isSmall ? 18 : 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isTablet ? 14 : (isSmall ? 11 : 12),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
