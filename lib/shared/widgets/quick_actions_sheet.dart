import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Quick Actions bottom sheet - opened from center (+) button
class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.slate900,
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              _ActionTile(
                icon: Icons.mic,
                iconColor: AppTheme.errorRed,
                iconBackground: AppTheme.errorRed.withValues(alpha: 0.1),
                title: 'Record Meeting',
                subtitle: 'Start recording now',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  context.push(AppRoutes.recording);
                },
              ),
              const SizedBox(height: 12),
              
              _ActionTile(
                icon: Icons.search,
                iconColor: AppTheme.primaryBlue,
                iconBackground: AppTheme.primaryBlue.withValues(alpha: 0.1),
                title: 'New Research',
                subtitle: 'Research a company',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  context.push(AppRoutes.researchCreate);
                },
              ),
              const SizedBox(height: 12),
              
              _ActionTile(
                icon: Icons.description_outlined,
                iconColor: AppTheme.successGreen,
                iconBackground: AppTheme.successGreen.withValues(alpha: 0.1),
                title: 'New Preparation',
                subtitle: 'Prepare for a meeting',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  context.push(AppRoutes.preparationCreate);
                },
              ),
              
              const SizedBox(height: 16),
              
              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.slate500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual action tile
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppTheme.slate800 : AppTheme.slate50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.chevron_right,
                color: AppTheme.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

