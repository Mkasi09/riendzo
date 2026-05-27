import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final Widget leadingIcon;
  final String textTitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.leadingIcon,
    required this.textTitle,
    required this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        minLeadingWidth: 28,
        leading: IconTheme(
          data: IconThemeData(color: Theme.of(context).colorScheme.primary),
          child: leadingIcon,
        ),
        title: Text(
          textTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Icon(
          trailingIcon,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
