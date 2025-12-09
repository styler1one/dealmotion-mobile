import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/meeting_model.dart';

/// Meeting card widget
class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final bool showDate;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: meeting.isNow
              ? AppTheme.errorRed.withValues(alpha: 0.5)
              : (isDark ? AppTheme.slate800 : AppTheme.slate200),
          width: meeting.isNow ? 2 : 1,
        ),
        boxShadow: meeting.isNow
            ? [
                BoxShadow(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time and status row
                Row(
                  children: [
                    // Now badge
                    if (meeting.isNow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Time
                    Text(
                      meeting.formattedTimeRange,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: meeting.isNow
                            ? AppTheme.errorRed
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.slate800 : AppTheme.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meeting.formattedDuration,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.slate900,
                  ),
                ),

                const SizedBox(height: 8),

                // Location/Online
                if (meeting.displayLocation != null)
                  Row(
                    children: [
                      Icon(
                        meeting.isOnlineMeeting
                            ? Icons.videocam
                            : Icons.location_on,
                        size: 16,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meeting.displayLocation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                // Company
                if (meeting.prospectName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meeting.prospectName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Attendees
                if (meeting.attendees.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meeting.attendees.length == 1
                              ? meeting.attendees.first.displayName
                              : '${meeting.attendees.first.displayName} +${meeting.attendees.length - 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Prep status
                _PrepStatusBadge(meeting: meeting),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.slate800 : AppTheme.slate50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                // View Prep / Prepare Now button
                Expanded(
                  child: _ActionButton(
                    icon: meeting.isPrepared ? Icons.visibility : Icons.edit_note,
                    label: meeting.isPrepared ? 'View Prep' : 'Prepare Now',
                    color: meeting.isPrepared
                        ? AppTheme.successGreen
                        : AppTheme.warningAmber,
                    onTap: () => _handlePrepAction(context),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Record button (only for current/upcoming meetings)
                if (!meeting.isPast)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.mic,
                      label: 'Record',
                      color: AppTheme.errorRed,
                      onTap: () => _handleRecordAction(context),
                    ),
                  ),
                
                // View Analysis (for past meetings with followup)
                if (meeting.isPast && meeting.hasFollowup)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.analytics,
                      label: 'Analysis',
                      color: AppTheme.primaryBlue,
                      onTap: () => _handleAnalysisAction(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePrepAction(BuildContext context) {
    HapticFeedback.selectionClick();
    if (meeting.isPrepared && meeting.preparationId != null) {
      context.push('/preparation/${meeting.preparationId}');
    } else {
      // Navigate to prep create with pre-filled company
      if (meeting.prospectId != null) {
        // Store in session for the preparation screen
        context.push(AppRoutes.preparationCreate);
      } else {
        context.push(AppRoutes.preparationCreate);
      }
    }
  }

  void _handleRecordAction(BuildContext context) {
    HapticFeedback.mediumImpact();
    final params = <String, String>{};
    if (meeting.prospectId != null) {
      params['prospectId'] = meeting.prospectId!;
    }
    if (meeting.prospectName != null) {
      params['prospectName'] = meeting.prospectName!;
    }
    
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    context.push('${AppRoutes.recording}${queryString.isNotEmpty ? '?$queryString' : ''}');
  }

  void _handleAnalysisAction(BuildContext context) {
    HapticFeedback.selectionClick();
    if (meeting.followupId != null) {
      context.push('/followup/${meeting.followupId}');
    }
  }
}

/// Prep status badge
class _PrepStatusBadge extends StatelessWidget {
  final Meeting meeting;

  const _PrepStatusBadge({required this.meeting});

  @override
  Widget build(BuildContext context) {
    if (meeting.isPast) {
      if (meeting.hasFollowup) {
        return _buildBadge(
          icon: Icons.check_circle,
          label: 'Analysis available',
          color: AppTheme.primaryBlue,
        );
      } else {
        return _buildBadge(
          icon: Icons.history,
          label: 'Past meeting',
          color: AppTheme.slate400,
        );
      }
    }

    if (meeting.isPrepared) {
      return _buildBadge(
        icon: Icons.check_circle,
        label: 'Prepared',
        color: AppTheme.successGreen,
      );
    }

    return _buildBadge(
      icon: Icons.warning_amber,
      label: 'Not prepared',
      color: AppTheme.warningAmber,
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

