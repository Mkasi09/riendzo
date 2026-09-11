import 'package:flutter/material.dart';

class RiendzoSliverAppBar extends StatelessWidget {
  const RiendzoSliverAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.automaticallyImplyLeading = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 156,
      toolbarHeight: 72,
      automaticallyImplyLeading: automaticallyImplyLeading,
      titleSpacing: automaticallyImplyLeading ? 0 : 20,
      elevation: 0,
      scrolledUnderElevation: 5,
      shadowColor: Colors.black26,
      surfaceTintColor: colors.surface,
      backgroundColor: colors.surface,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final progress = ((constraints.maxHeight - 72) / (156 - 72)).clamp(
            0.0,
            1.0,
          );
          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            titlePadding: EdgeInsetsDirectional.only(
              start: automaticallyImplyLeading ? 56 : 20,
              bottom: 18,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 20 + (4 * progress),
              ),
            ),
            background: Opacity(
              opacity: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.14),
                      colors.secondary.withValues(alpha: 0.08),
                      colors.surface,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
