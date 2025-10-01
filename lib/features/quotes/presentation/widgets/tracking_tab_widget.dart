// lib/features/quotes/presentation/widgets/tracking_tab_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/shipment_tracking.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/responsive_helper.dart';

// Provider for tracking service
final trackingServiceProvider = Provider<TrackingService>((ref) {
  return TrackingService();
});

// Provider for all trackings stream
final trackingsStreamProvider = StreamProvider.autoDispose<List<ShipmentTracking>>((ref) {
  final service = ref.watch(trackingServiceProvider);
  return service.getTrackingsStream();
});

// Provider for tracking statistics
final trackingStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.watch(trackingServiceProvider);
  return await service.getTrackingStats();
});

/// Tracking tab widget to display in quotes screen
class TrackingTabWidget extends ConsumerStatefulWidget {
  const TrackingTabWidget({super.key});

  @override
  ConsumerState<TrackingTabWidget> createState() => _TrackingTabWidgetState();
}

class _TrackingTabWidgetState extends ConsumerState<TrackingTabWidget> {
  String _searchQuery = '';
  String _filterStatus = 'all';
  bool _showDelayedOnly = false;

  @override
  Widget build(BuildContext context) {
    final trackingsAsync = ref.watch(trackingsStreamProvider);
    final statsAsync = ref.watch(trackingStatsProvider);
    final theme = Theme.of(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Column(
      children: [
        // Statistics cards
        statsAsync.when(
          data: (stats) => _buildStatsCards(stats, theme, isMobile),
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),

        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.cardColor,
          child: Column(
            children: [
              // Search field
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by tracking #, quote #, customer...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', theme),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Transit', 'in_transit', theme),
                    const SizedBox(width: 8),
                    _buildFilterChip('Delivered', 'delivered', theme),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending', theme),
                    const SizedBox(width: 16),
                    // Delayed toggle
                    FilterChip(
                      label: const Text('Delayed Only'),
                      selected: _showDelayedOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showDelayedOnly = selected;
                        });
                      },
                      backgroundColor: theme.chipTheme.backgroundColor,
                      selectedColor: Colors.red.withOpacity(0.2),
                      checkmarkColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Trackings list
        Expanded(
          child: trackingsAsync.when(
            data: (trackings) {
              // Apply filters
              var filteredTrackings = trackings;

              if (_filterStatus != 'all') {
                filteredTrackings = filteredTrackings.where((t) {
                  final status = t.status.toLowerCase().replaceAll(' ', '_');
                  return status == _filterStatus;
                }).toList();
              }

              if (_showDelayedOnly) {
                filteredTrackings = filteredTrackings.where((t) => t.isDelayed).toList();
              }

              if (_searchQuery.isNotEmpty) {
                filteredTrackings = filteredTrackings.where((t) {
                  return t.trackingNumber.toLowerCase().contains(_searchQuery) ||
                         (t.quoteNumber?.toLowerCase().contains(_searchQuery) ?? false) ||
                         (t.customerName?.toLowerCase().contains(_searchQuery) ?? false) ||
                         (t.orderReference?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();
              }

              if (filteredTrackings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 80,
                        color: theme.iconTheme.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No shipments found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty || _filterStatus != 'all'
                            ? 'Try adjusting your filters'
                            : 'Shipment tracking data will appear here',
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(isMobile ? 8 : 16),
                itemCount: filteredTrackings.length,
                itemBuilder: (context, index) {
                  return _buildTrackingCard(filteredTrackings[index], theme, isMobile);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading tracking data'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(trackingsStreamProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats, ThemeData theme, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Total', stats['total'], Icons.inventory_2, Colors.blue, theme)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('In Transit', stats['inTransit'], Icons.local_shipping, Colors.orange, theme)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Delivered', stats['delivered'], Icons.check_circle, Colors.green, theme)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('Delayed', stats['delayed'], Icons.warning, Colors.red, theme)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildStatCard('Total', stats['total'], Icons.inventory_2, Colors.blue, theme)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('In Transit', stats['inTransit'], Icons.local_shipping, Colors.orange, theme)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Delivered', stats['delivered'], Icons.check_circle, Colors.green, theme)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Pending', stats['pending'], Icons.schedule, Colors.grey, theme)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Delayed', stats['delayed'], Icons.warning, Colors.red, theme)),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ThemeData theme) {
    final isSelected = _filterStatus == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: theme.chipTheme.backgroundColor,
      selectedColor: theme.primaryColor.withOpacity(0.2),
      checkmarkColor: theme.primaryColor,
    );
  }

  Widget _buildTrackingCard(ShipmentTracking tracking, ThemeData theme, bool isMobile) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(tracking.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTrackingDetails(tracking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracking: ${tracking.trackingNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tracking.quoteNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Quote: #${tracking.quoteNumber}',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                      vertical: isMobile ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      tracking.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer info
              if (tracking.customerName != null) ...[
                Row(
                  children: [
                    Icon(Icons.person, size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tracking.customerName!,
                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Carrier info
              if (tracking.carrier != null) ...[
                Row(
                  children: [
                    Icon(Icons.local_shipping, size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Text(
                      tracking.carrier!,
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Current location
              if (tracking.currentLocation != null) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tracking.currentLocation!,
                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Dates
              Row(
                children: [
                  if (tracking.shipmentDate != null) ...[
                    Icon(Icons.calendar_today, size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Text(
                      'Shipped: ${dateFormat.format(tracking.shipmentDate!)}',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                  ],
                  if (tracking.estimatedDeliveryDate != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.event_available, size: isMobile ? 14 : 16,
                      color: tracking.isDelayed ? Colors.red : theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Text(
                      'ETA: ${dateFormat.format(tracking.estimatedDeliveryDate!)}',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: tracking.isDelayed ? Colors.red : null,
                        fontWeight: tracking.isDelayed ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ],
              ),

              // Delayed warning
              if (tracking.isDelayed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shipment is delayed',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('delivered')) return Colors.green;
    if (normalized.contains('transit') || normalized.contains('shipping')) return Colors.orange;
    if (normalized.contains('pending')) return Colors.grey;
    if (normalized.contains('cancel')) return Colors.red;
    if (normalized.contains('delay')) return Colors.red;
    return Colors.blue;
  }

  void _showTrackingDetails(ShipmentTracking tracking) {
    showDialog(
      context: context,
      builder: (context) => TrackingDetailsDialog(tracking: tracking),
    );
  }
}

/// Dialog to show detailed tracking information
class TrackingDetailsDialog extends StatelessWidget {
  final ShipmentTracking tracking;

  const TrackingDetailsDialog({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tracking Details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Tracking number
                  _buildDetailRow('Tracking Number', tracking.trackingNumber, Icons.qr_code),
                  if (tracking.quoteNumber != null)
                    _buildDetailRow('Quote Number', tracking.quoteNumber!, Icons.receipt),
                  if (tracking.orderReference != null)
                    _buildDetailRow('Order Reference', tracking.orderReference!, Icons.confirmation_number),
                  if (tracking.customerName != null)
                    _buildDetailRow('Customer', tracking.customerName!, Icons.person),
                  if (tracking.carrier != null)
                    _buildDetailRow('Carrier', tracking.carrier!, Icons.local_shipping),
                  if (tracking.origin != null)
                    _buildDetailRow('Origin', tracking.origin!, Icons.flight_takeoff),
                  if (tracking.destination != null)
                    _buildDetailRow('Destination', tracking.destination!, Icons.flight_land),
                  if (tracking.currentLocation != null)
                    _buildDetailRow('Current Location', tracking.currentLocation!, Icons.location_on),

                  const Divider(height: 32),

                  // Dates
                  if (tracking.shipmentDate != null)
                    _buildDetailRow('Shipment Date', dateFormat.format(tracking.shipmentDate!), Icons.calendar_today),
                  if (tracking.estimatedDeliveryDate != null)
                    _buildDetailRow('Estimated Delivery', dateFormat.format(tracking.estimatedDeliveryDate!), Icons.event_available),
                  if (tracking.actualDeliveryDate != null)
                    _buildDetailRow('Actual Delivery', dateFormat.format(tracking.actualDeliveryDate!), Icons.check_circle),

                  if (tracking.numberOfPackages != null)
                    _buildDetailRow('Packages', tracking.numberOfPackages.toString(), Icons.inventory_2),
                  if (tracking.weight != null)
                    _buildDetailRow('Weight', '${tracking.weight} ${tracking.weightUnit ?? 'kg'}', Icons.scale),

                  if (tracking.notes != null) ...[
                    const Divider(height: 32),
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(tracking.notes!),
                  ],

                  // Tracking events
                  if (tracking.events.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text(
                      'Tracking History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...tracking.events.map((event) => _buildEventItem(event, dateFormat)),
                  ],
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(TrackingEvent event, DateFormat dateFormat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.status,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.location,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(event.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
