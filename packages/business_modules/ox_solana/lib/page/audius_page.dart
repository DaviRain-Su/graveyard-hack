import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';

import '../services/audius_service.dart';

/// Audius music page — browse, search, and share decentralized music
class AudiusPage extends StatefulWidget {
  /// If onTrackSelected is provided, selecting a track calls it (for chat share)
  final Function(AudiusTrack track)? onTrackSelected;

  const AudiusPage({super.key, this.onTrackSelected});

  @override
  State<AudiusPage> createState() => _AudiusPageState();
}

class _AudiusPageState extends State<AudiusPage> {
  final _searchController = TextEditingController();
  List<AudiusTrack> _tracks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _currentTab = 'trending';

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() { _isLoading = true; _currentTab = 'trending'; });
    final tracks = await AudiusService.instance.getTrending(limit: 20);
    setState(() { _tracks = tracks; _isLoading = false; });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() { _isSearching = true; _currentTab = 'search'; });
    final tracks = await AudiusService.instance.searchTracks(query, limit: 20);
    setState(() { _tracks = tracks; _isSearching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: '🎵 Audius Music',
        backgroundColor: ThemeColor.color190,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(Adapt.px(12)),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: ThemeColor.color0),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search artists, songs...',
                hintStyle: TextStyle(color: ThemeColor.color110),
                prefixIcon: Icon(Icons.search, color: ThemeColor.color100),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: ThemeColor.color100, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrending();
                        },
                      )
                    : null,
                filled: true,
                fillColor: ThemeColor.color180,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Adapt.px(16)),
            child: Row(
              children: [
                Text(
                  _currentTab == 'trending' ? '🔥 Trending' : '🔍 Results',
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  '${_tracks.length} tracks',
                  style: TextStyle(color: ThemeColor.color110, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Track list
          Expanded(
            child: _isLoading || _isSearching
                ? Center(child: CircularProgressIndicator(color: Color(0xFF9945FF)))
                : _tracks.isEmpty
                    ? Center(
                        child: Text('No tracks found',
                            style: TextStyle(color: ThemeColor.color100)))
                    : ListView.builder(
                        itemCount: _tracks.length,
                        itemBuilder: (ctx, i) => _buildTrackItem(_tracks[i], i + 1),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(AudiusTrack track, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Adapt.px(12), vertical: 2),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showTrackOptions(track),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Index number
                SizedBox(
                  width: 24,
                  child: Text(
                    '$index',
                    style: TextStyle(color: ThemeColor.color110, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 10),

                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: track.artworkUrl != null
                      ? Image.network(
                          track.artworkUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(track),
                        )
                      : _buildPlaceholderArt(track),
                ),
                SizedBox(width: 12),

                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        track.artistName,
                        style: TextStyle(color: ThemeColor.color100, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Duration + plays
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      track.durationDisplay,
                      style: TextStyle(color: ThemeColor.color110, fontSize: 11),
                    ),
                    SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 12, color: ThemeColor.color110),
                        Text(
                          track.playCountDisplay,
                          style: TextStyle(color: ThemeColor.color110, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt(AudiusTrack track) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('🎵', style: TextStyle(fontSize: 20)),
      ),
    );
  }

  void _showTrackOptions(AudiusTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: track.artworkUrl != null
                      ? Image.network(track.artworkUrl!, width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(track))
                      : _buildPlaceholderArt(track),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4),
                      Text(track.artistName, style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
                      if (track.genre != null)
                        Text(track.genre!, style: TextStyle(color: ThemeColor.color110, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Actions
            _buildActionTile(Icons.play_circle_outline, 'Play in Browser', () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(track.shareUrl), mode: LaunchMode.externalApplication);
            }),

            if (widget.onTrackSelected != null)
              _buildActionTile(Icons.send, 'Share in Chat', () {
                Navigator.pop(ctx);
                widget.onTrackSelected!(track);
                Navigator.pop(context);
              }),

            _buildActionTile(Icons.link, 'Copy Link', () {
              Navigator.pop(ctx);
              // Copy share URL
              CommonToast.instance.show(context, 'Link copied: ${track.shareUrl}');
            }),

            _buildActionTile(Icons.music_note, 'Stream URL', () {
              Navigator.pop(ctx);
              CommonToast.instance.show(context, track.streamUrl);
            }),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF9945FF)),
      title: Text(label, style: TextStyle(color: ThemeColor.color0)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
