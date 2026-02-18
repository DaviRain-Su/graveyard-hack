import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_loading.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/kyd_service.dart';

class KydEventsPage extends StatefulWidget {
  const KydEventsPage({Key? key}) : super(key: key);

  @override
  State<KydEventsPage> createState() => _KydEventsPageState();
}

class _KydEventsPageState extends State<KydEventsPage> {
  List<KydEvent> _events = [];
  KydEvent? _selectedEvent;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _events = await KydService.instance
          .getRecommendedEvents(forceRefresh: force);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEventDetail(KydEvent event) async {
    OXLoading.show();
    try {
      final detail = await KydService.instance.getEventDetail(event.id);
      OXLoading.dismiss();
      if (detail != null && mounted) {
        setState(() => _selectedEvent = detail);
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) CommonToast.instance.show(context, 'Failed to load: $e');
    }
  }

  Future<void> _openInBrowser(String eventId) async {
    final url = KydService.instance.getEventWebUrl(eventId);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) CommonToast.instance.show(context, 'Cannot open browser');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: AppBar(
        backgroundColor: ThemeColor.color190,
        elevation: 0,
        leading: _selectedEvent != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: ThemeColor.color0),
                onPressed: () => setState(() => _selectedEvent = null),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: ThemeColor.color0),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _selectedEvent != null ? 'Event Details' : '🎫 KYD Events',
          style: TextStyle(
            color: ThemeColor.color0,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: _selectedEvent == null
            ? [
                IconButton(
                  icon: Icon(Icons.refresh, color: ThemeColor.color0),
                  onPressed: () => _loadEvents(force: true),
                ),
              ]
            : null,
      ),
      body: _selectedEvent != null
          ? _buildDetailView(_selectedEvent!)
          : _buildEventsList(),
    );
  }

  Widget _buildEventsList() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ThemeColor.gradientMainStart),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: ThemeColor.color110),
            SizedBox(height: 12),
            Text('Failed to load events',
                style: TextStyle(color: ThemeColor.color110, fontSize: 16)),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => _loadEvents(force: true),
              child: Text('Retry',
                  style: TextStyle(color: ThemeColor.gradientMainStart)),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Text('No events available',
            style: TextStyle(color: ThemeColor.color110)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadEvents(force: true),
      child: ListView.builder(
        padding: EdgeInsets.all(16.px),
        itemCount: _events.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildHeader();
          return _buildEventCard(_events[i - 1]);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.px),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KYD branding
          Container(
            padding: EdgeInsets.all(16.px),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFA1FFFF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.px,
                  height: 48.px,
                  decoration: BoxDecoration(
                    color: Color(0xFFA1FFFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('🎫',
                        style: TextStyle(fontSize: 24)),
                  ),
                ),
                SizedBox(width: 12.px),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KYD Labs',
                        style: TextStyle(
                          color: Color(0xFFA1FFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Solana-powered live event tickets • NFT ticketing',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.px),
          Text(
            '🔥 Recommended Events',
            style: TextStyle(
              color: ThemeColor.color0,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${_events.length} events • Tap for details',
            style: TextStyle(color: ThemeColor.color110, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(KydEvent event) {
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openEventDetail(event),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.px),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: event.isSoldOut
                ? Colors.red.withOpacity(0.3)
                : event.isLowTickets
                    ? Colors.orange.withOpacity(0.3)
                    : ThemeColor.color160,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            if (hasImage)
              Stack(
                children: [
                  Image.network(
                    event.imageUrl!,
                    height: 160.px,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160.px,
                      color: ThemeColor.color170,
                      child: Center(
                        child: Icon(Icons.music_note,
                            size: 48, color: ThemeColor.color110),
                      ),
                    ),
                  ),
                  // Status badge
                  if (event.isSoldOut || event.isLowTickets)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.isSoldOut
                              ? Colors.red.withOpacity(0.9)
                              : Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.isSoldOut ? 'SOLD OUT' : 'LOW TICKETS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Solana badge
                  if (event.solanaData?.collectionMintAddress != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('◎',
                                style: TextStyle(
                                    color: Color(0xFF9945FF), fontSize: 12)),
                            SizedBox(width: 4),
                            Text('NFT Ticket',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            // Event info
            Padding(
              padding: EdgeInsets.all(14.px),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event name
                  Text(
                    _cleanEventName(event.name),
                    style: TextStyle(
                      color: ThemeColor.color0,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (event.subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      event.subtitle!,
                      style: TextStyle(
                          color: ThemeColor.color100, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  SizedBox(height: 8.px),

                  // Date + Venue row
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: ThemeColor.color110),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.displayStartAt ?? _formatDate(event.startAt),
                          style: TextStyle(
                              color: ThemeColor.color100, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  if (event.venue != null) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: ThemeColor.color110),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.venue!.name,
                            style: TextStyle(
                                color: ThemeColor.color100, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 8.px),

                  // Price + Org row
                  Row(
                    children: [
                      if (event.lowestPrice != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFFA1FFFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'From ${event.lowestPrice}',
                            style: TextStyle(
                              color: Color(0xFFA1FFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (event.lowestPrice != null) SizedBox(width: 8),
                      if (event.genres.isNotEmpty)
                        ...event.genres.take(2).map((g) => Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThemeColor.color170,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  g,
                                  style: TextStyle(
                                      color: ThemeColor.color110,
                                      fontSize: 10),
                                ),
                              ),
                            )),
                      Spacer(),
                      if (event.organization != null &&
                          event.organization!.logoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            event.organization!.logoUrl!,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(KydEvent event) {
    final hasImage = event.imageUrl != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          if (hasImage)
            Stack(
              children: [
                Image.network(
                  event.imageUrl!,
                  height: 250.px,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250.px,
                    color: ThemeColor.color170,
                  ),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          ThemeColor.color190,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          Padding(
            padding: EdgeInsets.all(16.px),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name
                Text(
                  _cleanEventName(event.name),
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (event.subtitle != null) ...[
                  SizedBox(height: 4),
                  Text(event.subtitle!,
                      style:
                          TextStyle(color: ThemeColor.color100, fontSize: 15)),
                ],

                SizedBox(height: 16.px),

                // Info cards
                _buildInfoRow(
                    Icons.calendar_today,
                    'Date',
                    event.displayStartAt ?? _formatDate(event.startAt)),
                if (event.displayDoorsAt != null)
                  _buildInfoRow(
                      Icons.door_front_door, 'Doors', event.displayDoorsAt!),
                if (event.venue != null)
                  _buildInfoRow(
                      Icons.location_on, 'Venue', event.venue!.name),
                if (event.venue?.address != null)
                  _buildInfoRow(
                      Icons.map, 'Address', event.venue!.address!),
                if (event.organization != null)
                  _buildInfoRow(Icons.business, 'Presented by',
                      event.organization!.name),

                SizedBox(height: 20.px),

                // Performers
                if (event.performers.isNotEmpty) ...[
                  Text('🎤 Performers',
                      style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  ...event.performers.map((p) => _buildPerformerRow(p)),
                  SizedBox(height: 20.px),
                ],

                // Ticket types
                if (event.ticketTypes.isNotEmpty) ...[
                  Text('🎫 Tickets',
                      style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  ...event.ticketTypes.map((t) => _buildTicketRow(t)),
                  SizedBox(height: 20.px),
                ],

                // Solana NFT info
                if (event.solanaData?.collectionMintAddress != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF9945FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Color(0xFF9945FF).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text('◎', style: TextStyle(fontSize: 20, color: Color(0xFF9945FF))),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Solana NFT Ticket',
                                  style: TextStyle(
                                      color: Color(0xFF9945FF),
                                      fontWeight: FontWeight.w600)),
                              Text(
                                'Collection: ${event.solanaData!.collectionMintAddress!.substring(0, 8)}...',
                                style: TextStyle(
                                    color: ThemeColor.color110, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.px),
                ],

                // Description
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  Text('📝 About',
                      style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    event.description!,
                    style:
                        TextStyle(color: ThemeColor.color100, fontSize: 14, height: 1.5),
                  ),
                  SizedBox(height: 20.px),
                ],

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52.px,
                  child: ElevatedButton(
                    onPressed: () => _openInBrowser(event.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: event.isSoldOut
                          ? ThemeColor.color160
                          : Color(0xFFA1FFFF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      event.isSoldOut
                          ? 'Join Waitlist'
                          : 'Get Tickets on KYD',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                SizedBox(height: 40.px),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.px),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ThemeColor.color110),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(color: ThemeColor.color110, fontSize: 11)),
              Text(value,
                  style: TextStyle(color: ThemeColor.color0, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformerRow(KydPerformer performer) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (performer.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                performer.imageUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  color: ThemeColor.color170,
                  child: Icon(Icons.person, size: 20, color: ThemeColor.color110),
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ThemeColor.color170,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, size: 20, color: ThemeColor.color110),
            ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  performer.name ?? 'Unknown',
                  style: TextStyle(
                      color: ThemeColor.color0, fontWeight: FontWeight.w500),
                ),
                if (performer.headliner)
                  Text('⭐ Headliner',
                      style: TextStyle(
                          color: Colors.amber, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(KydTicketType ticket) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(10),
        border: ticket.soldOut
            ? Border.all(color: Colors.red.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.name,
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (ticket.limit != null)
                  Text(
                    'Limit: ${ticket.limit} per person',
                    style: TextStyle(color: ThemeColor.color110, fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ticket.displayPrice ?? 'N/A',
                style: TextStyle(
                  color: ticket.soldOut ? ThemeColor.color110 : Color(0xFFA1FFFF),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  decoration: ticket.soldOut ? TextDecoration.lineThrough : null,
                ),
              ),
              if (ticket.soldOut)
                Text('Sold Out',
                    style: TextStyle(color: Colors.red, fontSize: 11)),
              if (ticket.waitlistStatus == 'OPEN' && ticket.soldOut)
                Text('Waitlist Open',
                    style: TextStyle(color: Colors.orange, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _cleanEventName(String name) {
    return name
        .replaceAll(' (Sold Out)', '')
        .replaceAll(' (Low Tickets)', '')
        .trim();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'TBA';
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day}';
  }
}
