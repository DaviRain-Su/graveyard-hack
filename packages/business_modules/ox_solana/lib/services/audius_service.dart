import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Audius music service — decentralized music streaming on Solana.
/// API: https://api.audius.co/v1 (no auth needed)
class AudiusService {
  static final AudiusService instance = AudiusService._();
  AudiusService._();

  static const String _baseUrl = 'https://api.audius.co/v1';

  /// Search for tracks
  Future<List<AudiusTrack>> searchTracks(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/tracks/search').replace(queryParameters: {
        'query': query,
        'limit': limit.toString(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['data'] as List?) ?? [];
        return tracks.map((t) => AudiusTrack.fromJson(t)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Audius] Search error: $e');
    }
    return [];
  }

  /// Get trending tracks
  Future<List<AudiusTrack>> getTrending({int limit = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/tracks/trending').replace(queryParameters: {
        'limit': limit.toString(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['data'] as List?) ?? [];
        return tracks.map((t) => AudiusTrack.fromJson(t)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Audius] Trending error: $e');
    }
    return [];
  }

  /// Get track by ID
  Future<AudiusTrack?> getTrack(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tracks/$trackId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AudiusTrack.fromJson(data['data']);
      }
    } catch (e) {
      if (kDebugMode) print('[Audius] Get track error: $e');
    }
    return null;
  }

  /// Get stream URL for a track
  static String getStreamUrl(String trackId) {
    return '$_baseUrl/tracks/$trackId/stream';
  }

  /// Get user's tracks
  Future<List<AudiusTrack>> getUserTracks(String userId, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/users/$userId/tracks').replace(queryParameters: {
        'limit': limit.toString(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['data'] as List?) ?? [];
        return tracks.map((t) => AudiusTrack.fromJson(t)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Audius] User tracks error: $e');
    }
    return [];
  }
}

/// Audius track model
class AudiusTrack {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artworkUrl;
  final int duration; // seconds
  final int playCount;
  final int favoriteCount;
  final int repostCount;
  final String? genre;
  final String? mood;
  final String? description;

  AudiusTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.artworkUrl,
    this.duration = 0,
    this.playCount = 0,
    this.favoriteCount = 0,
    this.repostCount = 0,
    this.genre,
    this.mood,
    this.description,
  });

  String get streamUrl => AudiusService.getStreamUrl(id);

  String get durationDisplay {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get playCountDisplay {
    if (playCount >= 1000000) return '${(playCount / 1000000).toStringAsFixed(1)}M';
    if (playCount >= 1000) return '${(playCount / 1000).toStringAsFixed(1)}K';
    return playCount.toString();
  }

  /// Audius share URL
  String get shareUrl => 'https://audius.co/tracks/$id';

  factory AudiusTrack.fromJson(Map<String, dynamic> json) {
    final artwork = json['artwork'];
    String? artUrl;
    if (artwork is Map) {
      artUrl = artwork['480x480'] ?? artwork['150x150'] ?? artwork['1000x1000'];
    }

    return AudiusTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      artistName: json['user']?['name'] ?? 'Unknown',
      artistId: json['user']?['id']?.toString(),
      artworkUrl: artUrl,
      duration: json['duration'] ?? 0,
      playCount: json['play_count'] ?? 0,
      favoriteCount: json['favorite_count'] ?? 0,
      repostCount: json['repost_count'] ?? 0,
      genre: json['genre'],
      mood: json['mood'],
      description: json['description'],
    );
  }

  /// Create a chat share payload
  Map<String, dynamic> toSharePayload() => {
    'type': 'audius_track',
    'track_id': id,
    'title': title,
    'artist': artistName,
    'duration': duration,
    'stream_url': streamUrl,
    'share_url': shareUrl,
    if (artworkUrl != null) 'artwork_url': artworkUrl,
  };

  /// Convert to Map for cross-module boundary (chat integration)
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artistName,
    'artwork': artworkUrl ?? '',
    'duration': duration,
    'share_url': shareUrl,
    'stream_url': streamUrl,
    'play_count': playCount,
  };

  /// Parse from chat message
  static AudiusTrack? fromSharePayload(Map<String, dynamic> data) {
    if (data['type'] != 'audius_track') return null;
    return AudiusTrack(
      id: data['track_id'] ?? '',
      title: data['title'] ?? '',
      artistName: data['artist'] ?? '',
      artworkUrl: data['artwork_url'],
      duration: data['duration'] ?? 0,
    );
  }
}
