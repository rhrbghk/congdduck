// lib/widgets/chat/user_avatar.dart
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;
  final Color? backgroundColor;
  final bool showOnlineStatus;
  final bool isOnline;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
    this.backgroundColor,
    this.showOnlineStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Theme.of(context).primaryColor,
          ),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? _buildNetworkImage()
              : _buildInitials(),
        ),
        if (showOnlineStatus)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : Colors.grey,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNetworkImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => _buildInitials(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitials() {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class UserAvatarGroup extends StatelessWidget {
  final List<UserData> users;
  final double size;
  final double overlap;

  const UserAvatarGroup({
    super.key,
    required this.users,
    this.size = 40,
    this.overlap = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + (users.length - 1) * size * (1 - overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < users.length; i++)
            Positioned(
              left: i * size * (1 - overlap),
              child: UserAvatar(
                name: users[i].name,
                imageUrl: users[i].imageUrl,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

class UserData {
  final String name;
  final String? imageUrl;

  const UserData({
    required this.name,
    this.imageUrl,
  });
}