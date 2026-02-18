import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';

import '../services/audius_service.dart';
import '../services/audius_player_service.dart';

/// Audius music page — browse, search, and **play** decentralized music
class AudiusPage extends StatefulWidget {
  final Function(AudiusTrack track)? onTrackSelected;
  final String? autoPlayTitle;
  final String? autoPlayArtist;
  final bool autoPlay;

  const AudiusPage({
    super.key,
    this.onTrackSelected,
    this.autoPlayTitle,
    this.autoPlayArtist,
    this.autoPlay = false,
  });

  @override
  State<AudiusPage> createState() => _AudiusPageState();
}

class _AudiusPageState extends State<AudiusPage> {
  final _searchController = TextEditingController();
  List<AudiusTrack> _tracks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _currentTab = 'trending';
  String? _selectedGenre;

  // ── Global Audio Player (survives page navigation) ──
  final _playerService = AudiusPlayerService.instance;

  // Convenience getters that read from global service
  AudiusTrack? get _currentTrack => _playerService.currentTrack;
  PlayerState get _playerState => _playerService.playerState;
  Duration get _position => _playerService.position;
  Duration get _duration => _playerService.duration;
  // Player is global via AudiusPlayerService — keeps playing when page is closed

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _playerService.addListener(_onPlayerChanged);

    if (widget.autoPlay && widget.autoPlayTitle != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _openSharedTrack(widget.autoPlayTitle!, widget.autoPlayArtist);
      });
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerChanged);
    _searchController.dispose();
    // NOTE: Do NOT dispose the player — it's global, keeps playing
    super.dispose();
  }

  Future<void> _loadTrending({String? genre}) async {
    setState(() { _isLoading = true; _currentTab = 'trending'; _selectedGenre = genre; });
    final tracks = await AudiusService.instance.getTrending(limit: 20, genre: genre);
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

  // ── Playback controls ──

  Future<void> _playTrack(AudiusTrack track) async {
    try {
      await _playerService.play(track, trackList: _tracks);
    } catch (e) {
      if (mounted) {
        CommonToast.instance.show(context, 'Playback error: $e');
      }
    }
  }

  Future<void> _togglePlayPause() async {
    await _playerService.togglePlayPause();
  }

  Future<void> _playNext() async {
    await _playerService.playNext();
  }

  Future<void> _playPrev() async {
    if (_position.inSeconds > 3) {
      await _playerService.seek(Duration.zero);
    } else {
      await _playerService.playPrev();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: widget.onTrackSelected != null ? '🎵 Pick a Track to Share' : '🎵 Audius Music',
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

          // Genre filter chips
          if (_currentTab == 'trending')
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: Adapt.px(12)),
                children: [
                  _buildGenreChip('All', null),
                  ...AudiusService.genres.take(10).map((g) => _buildGenreChip(g, g)),
                ],
              ),
            ),
          SizedBox(height: 8),

          // Tab indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Adapt.px(16)),
            child: Row(
              children: [
                Text(
                  _currentTab == 'trending'
                      ? (_selectedGenre != null ? '🎸 $_selectedGenre' : '🔥 Trending')
                      : '🔍 Results',
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
                        padding: EdgeInsets.only(bottom: _currentTrack != null ? 140 : 0),
                        itemCount: _tracks.length,
                        itemBuilder: (ctx, i) => _buildTrackItem(_tracks[i], i + 1),
                      ),
          ),

          // Mini player
          if (_currentTrack != null) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Future<void> _openSharedTrack(String title, String? artist) async {
    if (title.trim().isEmpty) return;
    _searchController.text = title;
    setState(() {
      _isSearching = true;
      _currentTab = 'search';
    });

    final results = await AudiusService.instance.searchTracks(title, limit: 10);
    AudiusTrack? match;
    if (results.isNotEmpty) {
      if (artist != null && artist.trim().isNotEmpty) {
        match = results.firstWhere(
          (t) => t.artistName.toLowerCase().contains(artist.toLowerCase()),
          orElse: () => results.first,
        );
      } else {
        match = results.first;
      }
    }

    setState(() {
      _tracks = results;
      _isSearching = false;
    });

    if (match != null) {
      _playTrack(match);
    }
  }

  Widget _buildGenreChip(String label, String? genre) {
    final isSelected = _selectedGenre == genre;
    return Padding(
      padding: EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _loadTrending(genre: genre),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF9945FF) : ThemeColor.color180,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Color(0xFF9945FF) : ThemeColor.color160,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : ThemeColor.color100,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackItem(AudiusTrack track, int index) {
    final isPlaying = _currentTrack?.id == track.id;
    final isActive = isPlaying && _playerState == PlayerState.playing;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Adapt.px(12), vertical: 2),
      decoration: BoxDecoration(
        color: isPlaying
            ? Color(0xFF9945FF).withOpacity(0.12)
            : ThemeColor.color180,
        borderRadius: BorderRadius.circular(10),
        border: isPlaying
            ? Border.all(color: Color(0xFF9945FF).withOpacity(0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isPlaying) {
              _togglePlayPause();
            } else {
              _playTrack(track);
            }
          },
          onLongPress: () => _showTrackOptions(track),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Play/index indicator
                SizedBox(
                  width: 28,
                  child: isActive
                      ? _buildEqualizer()
                      : isPlaying
                          ? Icon(Icons.pause, size: 18, color: Color(0xFF9945FF))
                          : Text(
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
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(),
                        )
                      : _buildPlaceholderArt(),
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
                          color: isPlaying ? Color(0xFF9945FF) : ThemeColor.color0,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        track.artistName,
                        style: TextStyle(
                          color: isPlaying ? Color(0xFF9945FF).withOpacity(0.7) : ThemeColor.color100,
                          fontSize: 12,
                        ),
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

                // Share-to-chat or more options
                SizedBox(width: 4),
                if (widget.onTrackSelected != null)
                  GestureDetector(
                    onTap: () {
                      widget.onTrackSelected!(track);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF9945FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send, size: 13, color: Color(0xFF9945FF)),
                          SizedBox(width: 4),
                          Text('Send', style: TextStyle(color: Color(0xFF9945FF), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _showTrackOptions(track),
                    child: Icon(Icons.more_vert, size: 18, color: ThemeColor.color110),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mini Player (bottom bar) ──

  Widget _buildMiniPlayer() {
    final track = _currentTrack!;
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onTap: () => _showNowPlayingSheet(track),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          border: Border(top: BorderSide(color: ThemeColor.color160, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: ThemeColor.color170,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9945FF)),
              minHeight: 2,
            ),
            // Player content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: track.artworkUrl != null
                        ? Image.network(
                            track.artworkUrl!,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderArt(size: 42),
                          )
                        : _buildPlaceholderArt(size: 42),
                  ),
                  SizedBox(width: 10),

                  // Title + artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            color: ThemeColor.color0,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artistName,
                          style: TextStyle(color: ThemeColor.color100, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded,
                        color: ThemeColor.color0, size: 28),
                    onPressed: _playPrev,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Color(0xFF9945FF),
                      size: 38,
                    ),
                    onPressed: _togglePlayPause,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 42),
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded,
                        color: ThemeColor.color0, size: 28),
                    onPressed: _playNext,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Now Playing Full Sheet ──

  void _showNowPlayingSheet(AudiusTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _NowPlayingSheet(
        track: track,
        playerState: _playerState,
        position: _position,
        duration: _duration,
        onTogglePlay: _togglePlayPause,
        onNext: _playNext,
        onPrev: _playPrev,
        onSeek: (pos) => _playerService.seek(pos),
        onShare: widget.onTrackSelected != null
            ? () {
                Navigator.pop(ctx);
                widget.onTrackSelected!(track);
                Navigator.pop(context);
              }
            : null,
      ),
    );
  }

  // ── Equalizer animation ──

  Widget _buildEqualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => _EqualizerBar(delay: i * 100)),
    );
  }

  Widget _buildPlaceholderArt({double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('🎵', style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }

  // ── Track options (long press / more button) ──

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
                          errorBuilder: (_, __, ___) => _buildPlaceholderArt(size: 60))
                      : _buildPlaceholderArt(size: 60),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4),
                      Text(track.artistName,
                          style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
                      if (track.genre != null)
                        Text(track.genre!,
                            style: TextStyle(color: ThemeColor.color110, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            _buildActionTile(Icons.play_circle_filled, 'Play Now', () {
              Navigator.pop(ctx);
              _playTrack(track);
            }),

            _buildActionTile(Icons.open_in_browser, 'Open on Audius', () {
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
              Clipboard.setData(ClipboardData(text: track.shareUrl));
              CommonToast.instance.show(context, 'Link copied! 🔗');
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

// ── Now Playing Sheet (full-height) ──

class _NowPlayingSheet extends StatefulWidget {
  final AudiusTrack track;
  final PlayerState playerState;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(Duration) onSeek;
  final VoidCallback? onShare;

  const _NowPlayingSheet({
    required this.track,
    required this.playerState,
    required this.position,
    required this.duration,
    required this.onTogglePlay,
    required this.onNext,
    required this.onPrev,
    required this.onSeek,
    this.onShare,
  });

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  final _playerService = AudiusPlayerService.instance;

  PlayerState get _state => _playerService.playerState;
  Duration get _pos => _playerService.position;
  Duration get _dur => _playerService.duration;

  @override
  void initState() {
    super.initState();
    _playerService.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _playerService.removeListener(_onChanged);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isPlaying = _state == PlayerState.playing;
    final progress = _dur.inMilliseconds > 0
        ? _pos.inMilliseconds / _dur.inMilliseconds
        : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeColor.color160,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 8),
          Text('Now Playing',
              style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
          SizedBox(height: 24),

          // Large artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: track.artworkUrl != null
                ? Image.network(
                    track.artworkUrl!,
                    width: 240,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child: Text('🎵', style: TextStyle(fontSize: 64))),
                    ),
                  )
                : Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(child: Text('🎵', style: TextStyle(fontSize: 64))),
                  ),
          ),
          SizedBox(height: 28),

          // Title + artist
          Text(
            track.title,
            style: TextStyle(
              color: ThemeColor.color0,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            track.artistName,
            style: TextStyle(color: ThemeColor.color100, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          if (track.genre != null) ...[
            SizedBox(height: 4),
            Text(track.genre!,
                style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
          ],

          Spacer(),

          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Color(0xFF9945FF),
              inactiveTrackColor: ThemeColor.color170,
              thumbColor: Color(0xFF9945FF),
              overlayColor: Color(0xFF9945FF).withOpacity(0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final newPos = Duration(
                    milliseconds: (v * _dur.inMilliseconds).round());
                widget.onSeek(newPos);
              },
            ),
          ),

          // Time labels
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_pos),
                    style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
                Text(_formatDuration(_dur),
                    style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous_rounded,
                    color: ThemeColor.color0, size: 36),
                onPressed: widget.onPrev,
              ),
              SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(0xFF9945FF),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: widget.onTogglePlay,
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.skip_next_rounded,
                    color: ThemeColor.color0, size: 36),
                onPressed: widget.onNext,
              ),
            ],
          ),

          SizedBox(height: 16),

          // Bottom actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onShare != null)
                _buildSmallAction(Icons.send, 'Share', widget.onShare!),
              _buildSmallAction(Icons.open_in_browser, 'Audius', () {
                launchUrl(Uri.parse(track.shareUrl),
                    mode: LaunchMode.externalApplication);
              }),
              _buildSmallAction(Icons.link, 'Copy', () {
                Clipboard.setData(ClipboardData(text: track.shareUrl));
                CommonToast.instance.show(context, 'Link copied! 🔗');
              }),
            ],
          ),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: ThemeColor.color110, size: 22),
            SizedBox(height: 4),
            Text(label, style: TextStyle(color: ThemeColor.color110, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Equalizer animation bars ──

class _EqualizerBar extends StatefulWidget {
  final int delay;
  const _EqualizerBar({this.delay = 0});

  @override
  State<_EqualizerBar> createState() => _EqualizerBarState();
}

class _EqualizerBarState extends State<_EqualizerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.delay),
    );
    _anim = Tween<double>(begin: 4, end: 14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 3,
        height: _anim.value,
        margin: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: Color(0xFF9945FF),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
