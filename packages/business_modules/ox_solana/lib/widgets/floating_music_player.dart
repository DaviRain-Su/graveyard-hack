import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_common/utils/theme_color.dart';

import '../services/audius_player_service.dart';
import '../page/audius_page.dart';

/// Floating mini music player — shows at bottom of screen when music is playing.
/// Like WeChat mini-program: persists across all pages.
class FloatingMusicPlayer extends StatefulWidget {
  const FloatingMusicPlayer({super.key});

  @override
  State<FloatingMusicPlayer> createState() => _FloatingMusicPlayerState();
}

class _FloatingMusicPlayerState extends State<FloatingMusicPlayer>
    with SingleTickerProviderStateMixin {
  final _player = AudiusPlayerService.instance;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.removeListener(_onChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_player.hasTrack) return const SizedBox.shrink();

    final track = _player.currentTrack!;
    final isPlaying = _player.isPlaying;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 90, // above tab bar
      child: GestureDetector(
        onTap: () {
          OXNavigator.pushPage(context, (ctx) => const AudiusPage());
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: ThemeColor.color180,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF9945FF).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Progress bar at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: _player.progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF9945FF).withOpacity(0.4)),
                    minHeight: 2,
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Spinning artwork
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (_, child) => Transform.rotate(
                          angle: isPlaying
                              ? _animController.value * 6.28
                              : 0,
                          child: child,
                        ),
                        child: ClipOval(
                          child: track.artworkUrl != null
                              ? Image.network(
                                  track.artworkUrl!,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(),
                                )
                              : _placeholder(),
                        ),
                      ),
                      SizedBox(width: 10),

                      // Track info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                color: ThemeColor.color0,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artistName,
                              style: TextStyle(
                                  color: ThemeColor.color110, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause
                      GestureDetector(
                        onTap: () => _player.togglePlayPause(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF9945FF),
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),

                      // Close
                      GestureDetector(
                        onTap: () => _player.stop(),
                        child: Icon(Icons.close, size: 18,
                            color: ThemeColor.color110),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
        ),
      ),
      child: Icon(Icons.music_note, color: Colors.white, size: 18),
    );
  }
}
