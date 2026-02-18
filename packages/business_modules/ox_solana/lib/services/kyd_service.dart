import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// KYD Labs — Solana-powered live event ticketing platform
/// API: AWS API Gateway backed by Cognito + Stripe
/// Events are NFT tickets on Solana
class KydService {
  KydService._();
  static final KydService instance = KydService._();

  static const String _apiBase =
      'https://9h6uhy2li6.execute-api.us-east-1.amazonaws.com/prod';
  static const String _apiKey = 'QStqFNNxwc37O9StBSBZV2Viltc8JPr793GVe1jw';
  static const String _webBase = 'https://kydlabs.com';
  static const String _cacheKey = 'ox_solana_kyd_events_cache';
  static const Duration _cacheTtl = Duration(minutes: 15);

  List<KydEvent> _cachedEvents = [];
  DateTime? _cacheTime;

  Future<void> init() async {
    // Load cached events on startup
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        _cachedEvents = (data['events'] as List)
            .map((e) => KydEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        _cacheTime = DateTime.tryParse(data['time'] ?? '');
      } catch (_) {}
    }
  }

  /// HTTP GET with API key
  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final resp = await http.get(
        Uri.parse('$_apiBase$path'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (_) {}
    return null;
  }

  /// Get recommended events (public, no auth needed)
  Future<List<KydEvent>> getRecommendedEvents({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        _cachedEvents.isNotEmpty &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedEvents;
    }

    final data = await _get('/events/recommended');
    if (data == null) return _cachedEvents;

    final events = (data['response'] as List? ?? [])
        .map<KydEvent>((e) => KydEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    _cachedEvents = events;
    _cacheTime = DateTime.now();

    // Persist cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({
      'events': events.map((e) => e.toJson()).toList(),
      'time': _cacheTime!.toIso8601String(),
    }));

    return events;
  }

  /// Get single event detail with full ticket info
  Future<KydEvent?> getEventDetail(String eventId) async {
    final data = await _get('/events/$eventId');
    if (data == null) return null;

    final eventData = data['response'];
    if (eventData is Map<String, dynamic>) {
      return KydEvent.fromJson(eventData);
    }
    return null;
  }

  /// Web URL for an event (opens in browser for purchase)
  String getEventWebUrl(String eventId) => '$_webBase/e/$eventId';

  /// Short link for sharing
  String getShareUrl(KydEvent event) =>
      event.shortLink ?? getEventWebUrl(event.id);
}

// ── Data Models ──

class KydEvent {
  final String id;
  final String name;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? status; // OPEN, SOLD_OUT, etc.
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? doorsAt;
  final String? displayStartAt;
  final String? displayDoorsAt;
  final String? currency;
  final String? timezone;
  final KydVenue? venue;
  final KydOrganization? organization;
  final List<KydPerformer> performers;
  final List<KydTicketType> ticketTypes;
  final List<String> genres;
  final String? shortLink;
  final String? bioLink;
  final String? faqLink;
  final KydSolanaData? solanaData;

  KydEvent({
    required this.id,
    required this.name,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.status,
    this.startAt,
    this.endAt,
    this.doorsAt,
    this.displayStartAt,
    this.displayDoorsAt,
    this.currency,
    this.timezone,
    this.venue,
    this.organization,
    this.performers = const [],
    this.ticketTypes = const [],
    this.genres = const [],
    this.shortLink,
    this.bioLink,
    this.faqLink,
    this.solanaData,
  });

  bool get isSoldOut =>
      name.toLowerCase().contains('sold out') ||
      ticketTypes.every((t) => t.soldOut);

  bool get isLowTickets => name.toLowerCase().contains('low tickets');

  String? get lowestPrice {
    final available =
        ticketTypes.where((t) => !t.soldOut && t.displayPrice != null).toList();
    if (available.isEmpty) return null;
    return available.first.displayPrice;
  }

  String? get headlinerImage {
    final headliner = performers.where((p) => p.headliner).firstOrNull;
    return headliner?.imageUrl ?? performers.firstOrNull?.imageUrl;
  }

  factory KydEvent.fromJson(Map<String, dynamic> j) {
    // Parse venue from venues list or top-level venue
    KydVenue? venue;
    if (j['venues'] is List && (j['venues'] as List).isNotEmpty) {
      venue = KydVenue.fromJson(j['venues'][0] as Map<String, dynamic>);
    } else if (j['venue'] is Map) {
      venue = KydVenue.fromJson(j['venue'] as Map<String, dynamic>);
    }

    // Parse performers
    final performers = (j['performers'] as List? ?? [])
        .map<KydPerformer>(
            (p) => KydPerformer.fromJson(p as Map<String, dynamic>))
        .toList();

    // Parse ticket types
    final ticketTypes = (j['ticket_types'] as List? ?? [])
        .map<KydTicketType>(
            (t) => KydTicketType.fromJson(t as Map<String, dynamic>))
        .toList();

    // Parse genres
    final genres = (j['genres'] as List? ?? [])
        .map<String>((g) => g is Map ? (g['name'] ?? '') : g.toString())
        .where((g) => g.isNotEmpty)
        .toList();

    return KydEvent(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      subtitle: j['subtitle'],
      description: j['description'],
      imageUrl: j['image'],
      status: j['status'],
      startAt: DateTime.tryParse(j['start_at'] ?? ''),
      endAt: DateTime.tryParse(j['end_at'] ?? ''),
      doorsAt: DateTime.tryParse(j['doors_at'] ?? ''),
      displayStartAt: j['display_start_at'],
      displayDoorsAt: j['display_doors_at'],
      currency: j['currency'],
      timezone: j['timezone'],
      venue: venue,
      organization: j['organization'] is Map
          ? KydOrganization.fromJson(
              j['organization'] as Map<String, dynamic>)
          : null,
      performers: performers,
      ticketTypes: ticketTypes,
      genres: genres,
      shortLink: j['short_link'],
      bioLink: j['bio_link'],
      faqLink: j['faq_link'],
      solanaData: j['solana_data'] is Map
          ? KydSolanaData.fromJson(
              j['solana_data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'image': imageUrl,
        'status': status,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'doors_at': doorsAt?.toIso8601String(),
        'display_start_at': displayStartAt,
        'display_doors_at': displayDoorsAt,
        'currency': currency,
        'timezone': timezone,
        if (venue != null) 'venues': [venue!.toJson()],
        if (organization != null) 'organization': organization!.toJson(),
        'performers': performers.map((p) => p.toJson()).toList(),
        'ticket_types': ticketTypes.map((t) => t.toJson()).toList(),
        'genres': genres.map((g) => {'name': g}).toList(),
        'short_link': shortLink,
        'bio_link': bioLink,
        'faq_link': faqLink,
      };
}

class KydVenue {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? country;

  KydVenue({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.city,
    this.country,
  });

  factory KydVenue.fromJson(Map<String, dynamic> j) {
    double? lat, lng;
    String? addr, city, country;

    // Parse from location object
    final loc = j['location'];
    if (loc is Map) {
      final geo = loc['Geometry'];
      if (geo is Map && geo['Point'] is List) {
        final point = geo['Point'] as List;
        lng = (point[0] as num?)?.toDouble();
        lat = (point[1] as num?)?.toDouble();
      }
      addr = loc['Label'];
      city = loc['SubMunicipality'] ?? loc['Municipality'];
      country = loc['Country'];
    }

    // Fallback to top-level address
    addr ??= j['address'];
    country ??= j['country'];

    return KydVenue(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      address: addr,
      latitude: lat,
      longitude: lng,
      city: city,
      country: country,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'country': country,
      };
}

class KydOrganization {
  final String id;
  final String name;
  final String? slugId;
  final String? logoUrl;
  final String? verifiedFans;

  KydOrganization({
    required this.id,
    required this.name,
    this.slugId,
    this.logoUrl,
    this.verifiedFans,
  });

  factory KydOrganization.fromJson(Map<String, dynamic> j) => KydOrganization(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        slugId: j['slug_id'],
        logoUrl: j['logo_url'],
        verifiedFans: j['display_verified_fans'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug_id': slugId,
        'logo_url': logoUrl,
      };
}

class KydPerformer {
  final String? name;
  final String? imageUrl;
  final bool headliner;
  final String? spotifyId;
  final String? instagramId;

  KydPerformer({
    this.name,
    this.imageUrl,
    this.headliner = false,
    this.spotifyId,
    this.instagramId,
  });

  factory KydPerformer.fromJson(Map<String, dynamic> j) {
    String? name = j['name'];
    // Sometimes name is in spotify or other nested
    if (name == null || name.isEmpty) {
      name = j['spotify']?['name'] ?? j['instagram']?['name'];
    }

    return KydPerformer(
      name: name,
      imageUrl: j['image_url'],
      headliner: j['headliner'] == true,
      spotifyId: j['spotify']?['id'],
      instagramId: j['instagram']?['id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'image_url': imageUrl,
        'headliner': headliner,
      };
}

class KydTicketType {
  final String id;
  final String name;
  final String? description;
  final String? displayPrice;
  final bool soldOut;
  final int? remaining;
  final int? limit;
  final String? waitlistStatus;

  KydTicketType({
    required this.id,
    required this.name,
    this.description,
    this.displayPrice,
    this.soldOut = false,
    this.remaining,
    this.limit,
    this.waitlistStatus,
  });

  factory KydTicketType.fromJson(Map<String, dynamic> j) => KydTicketType(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        description: j['description'],
        displayPrice: j['display_price'],
        soldOut: j['sold_out'] == true,
        remaining: j['remaining'] as int?,
        limit: j['limit'] as int?,
        waitlistStatus: j['waitlist_status'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_price': displayPrice,
        'sold_out': soldOut,
      };
}

class KydSolanaData {
  final String? collectionMintAddress;
  final String? authorityAddress;

  KydSolanaData({this.collectionMintAddress, this.authorityAddress});

  factory KydSolanaData.fromJson(Map<String, dynamic> j) {
    String? collectionMint;
    String? authority;

    final cm = j['collection_mint'];
    if (cm is Map) {
      final wallets = cm['wallets'] as List? ?? [];
      for (final w in wallets) {
        if (w is Map && w['chain'] == 'solana') {
          collectionMint = w['address'];
          break;
        }
      }
    }

    final auth = j['authority'];
    if (auth is Map) {
      final wallets = auth['wallets'] as List? ?? [];
      for (final w in wallets) {
        if (w is Map && w['chain'] == 'solana') {
          authority = w['address'];
          break;
        }
      }
    }

    return KydSolanaData(
      collectionMintAddress: collectionMint,
      authorityAddress: authority,
    );
  }
}
