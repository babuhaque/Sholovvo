import 'package:flutter/material.dart';

/// Heading above a group of content, with an optional trailing action.
///
/// The action is passed in rather than named here so a section that has nothing
/// to link to yet simply omits it, instead of showing "See all" that goes
/// nowhere.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    );
  }
}
