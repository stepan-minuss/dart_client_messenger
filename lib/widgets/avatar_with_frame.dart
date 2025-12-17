import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../services/user_service.dart';
import '../utils/image_cache_config.dart';

class AvatarWithFrame extends StatefulWidget {
  final User? user;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final double? size;
  final bool showCameraIcon;
  final VoidCallback? onCameraTap;

  const AvatarWithFrame({
    super.key,
    required this.user,
    this.radius = 28,
    this.size,
    this.backgroundColor,
    this.textStyle,
    this.showCameraIcon = false,
    this.onCameraTap,
  });

  @override
  State<AvatarWithFrame> createState() => _AvatarWithFrameState();
}

class _AvatarWithFrameState extends State<AvatarWithFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getInitials(User? user) {
    if (user == null) return '?';
    
    if (user.username.isNotEmpty) {
      return user.username[0].toUpperCase();
    }
    
    String initials = '';
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      initials += user.firstName![0].toUpperCase();
    }
    if (user.lastName != null && user.lastName!.isNotEmpty) {
      initials += user.lastName![0].toUpperCase();
    }
    
    return initials.isNotEmpty ? initials : '?';
  }

  @override
  Widget build(BuildContext context) {
    final actualSize = widget.size ?? (widget.radius * 2);
    final frameId = widget.user?.avatarFrame;

    Widget avatarWidget;
    if (widget.size != null) {
      avatarWidget = Container(
        width: actualSize,
        height: actualSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.backgroundColor ?? Colors.grey.withOpacity(0.2),
        ),
        child: ClipOval(
          child: widget.user?.avatarUrl != null
              ? ImageCacheConfig.avatarImage(
                  imageUrl: widget.user!.avatarUrl!,
                  size: actualSize,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: widget.backgroundColor ?? Colors.grey.withOpacity(0.2),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: widget.backgroundColor ?? Colors.grey.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: actualSize * 0.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : Icon(
                  Icons.person,
                  size: actualSize * 0.5,
                  color: Colors.white,
                ),
        ),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey.withOpacity(0.2),
        backgroundImage: widget.user?.avatarUrl != null
            ? ImageCacheConfig.avatarImageProvider(widget.user!.avatarUrl!)
            : null,
        child: widget.user?.avatarUrl == null
            ? Text(
                _getInitials(widget.user),
                style: widget.textStyle ?? const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              )
            : null,
      );
    }

    return _buildFrame(avatarWidget, frameId, actualSize);
  }

  Widget _buildFrame(Widget avatar, String? frameId, double size) {
    Widget frameWidget;
    double frameSize = size;
    
    if (frameId == null || frameId.isEmpty || frameId == 'none') {
      frameWidget = avatar;
      frameSize = size;
    } else {
      switch (frameId) {
        case 'rainbow':
          frameWidget = _buildAnimatedRainbowFrame(avatar, size);
          frameSize = size + 8;
          break;

        case 'fire':
          frameWidget = _buildAnimatedFireFrame(avatar, size);
          frameSize = size + 8;
          break;

        case 'purple':
          frameWidget = _buildSvgFrame(avatar, size, _getPurpleFrameSvg(size), Colors.purple);
          frameSize = size + 6; 
          break;

        default:
          frameWidget = avatar;
          frameSize = size;
      }
    }
    
    if (widget.showCameraIcon && widget.onCameraTap != null) {
      return Container(
        width: frameSize,
        height: frameSize,
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            frameWidget,
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.onCameraTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return frameWidget;
  }

  Widget _buildSvgFrame(Widget avatar, double size, String svgString, Color glowColor) {
    final frameSize = size + 6;
    
    return Container(
      width: frameSize,
      height: frameSize,
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: frameSize,
            height: frameSize,
            child: SvgPicture.string(
              svgString,
              fit: BoxFit.contain,
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: avatar,
            ),
          ),
        ],
      ),
    );
  }

  String _getPurpleFrameSvg(double size) {
    final radius = (size + 6) / 2;
    final center = radius;
    return '''
<svg width="${size + 6}" height="${size + 6}" xmlns="http://www.w3.org/2000/svg">
  <circle cx="$center" cy="$center" r="${radius - 1.5}" fill="none" stroke="#800080" stroke-width="4"/>
</svg>
''';
  }

  Widget _buildAnimatedRainbowFrame(Widget avatar, double size) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: size + 8,
          height: size + 8,
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          child: Container(
            width: size + 8,
            height: size + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: const [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.indigo,
                  Colors.purple,
                  Colors.red,
                ],
                transform: GradientRotation(_animationController.value * 2 * math.pi),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: avatar,
          ),
        );
      },
      child: avatar,
    );
  }


  Widget _buildAnimatedFireFrame(Widget avatar, double size) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: size + 8,
          height: size + 8,
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size + 8,
                height: size + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF4500),
                      const Color(0xFFFF6347),
                      const Color(0xFFFFD700),
                      const Color(0xFFFF4500),
                    ],
                    stops: [
                      0.0,
                      0.3 + _animationController.value * 0.2,
                      0.6 + _animationController.value * 0.2,
                      1.0,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: avatar,
              ),
              ...List.generate(8, (index) {
                final angle = (index * math.pi * 2) / 8;
                final radius = (size + 8) / 2 + 10;
                final x = math.cos(angle) * radius;
                final y = math.sin(angle) * radius;
                final flameHeight = 8 + math.sin(_animationController.value * 2 * math.pi + index) * 4;
                return Positioned(
                  left: (size + 8) / 2 + x - 2,
                  top: (size + 8) / 2 + y - flameHeight / 2,
                  child: Container(
                    width: 4,
                    height: flameHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.yellow,
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
      child: avatar,
    );
  }

}
