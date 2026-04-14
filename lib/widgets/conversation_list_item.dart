import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A single conversation item in the admin chat list
class ConversationListItem extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final bool isSelected;
  final bool hasActiveCall;
  final bool isOnline;
  final bool isMuted;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.hasActiveCall,
    required this.isOnline,
    required this.onTap,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unreadCount = conversation['unread_count'] ?? 0;
    final status = conversation['status'] ?? 'open';
    final memberName = conversation['member_name'] ?? l10n.unknown;
    final lastMessage = conversation['last_message'] ?? l10n.noMessagesConv;
    final lastSeenStr = conversation['last_seen'] as String?;

    return Container(
      color: isSelected ? const Color(0xFF1a1a2e).withValues(alpha: 0.1) : null,
      child: ListTile(
        dense: true,
        leading: _buildAvatar(memberName, status),
        title: _buildTitle(memberName, unreadCount),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasActiveCall ? l10n.inCallLabel : lastMessage,
              style: TextStyle(
                fontSize: 11,
                color: hasActiveCall ? Colors.green.shade700 : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (!isOnline && lastSeenStr != null)
              Text(
                _formatLastSeen(lastSeenStr, l10n),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  /// Format last seen timestamp to human-readable localized text
  String _formatLastSeen(String lastSeenStr, AppLocalizations l10n) {
    try {
      final lastSeen = DateTime.parse(lastSeenStr);
      final now = DateTime.now();
      final difference = now.difference(lastSeen);

      if (difference.inSeconds < 60) {
        return l10n.lastActiveSecondsAgo(difference.inSeconds);
      } else if (difference.inMinutes < 60) {
        return l10n.lastActiveMinutesAgo(difference.inMinutes);
      } else if (difference.inHours < 24) {
        return l10n.lastActiveHoursAgo(difference.inHours);
      } else if (difference.inDays < 7) {
        return l10n.lastActiveDaysAgo(difference.inDays);
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return l10n.lastActiveWeeksAgo(weeks);
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return l10n.lastActiveMonthsAgo(months);
      } else {
        final years = (difference.inDays / 365).floor();
        return l10n.lastActiveYearsAgo(years);
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildAvatar(String memberName, String status) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: hasActiveCall ? Colors.green.shade100 : Colors.blue.shade100,
          child: hasActiveCall
              ? Icon(Icons.call, color: Colors.green.shade700, size: 20)
              : Text(
                  memberName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        // Show online/offline indicator (green for online, red for offline)
        if (!hasActiveCall)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(String memberName, int unreadCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            memberName,
            style: TextStyle(
              fontWeight: isSelected || unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMuted)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.notifications_off, size: 14, color: Colors.orange.shade700),
          ),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
