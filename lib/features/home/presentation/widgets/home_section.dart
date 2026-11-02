import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/section_header.dart';

/// The dashboard's names for the shared section widgets.
///
/// These are aliases, not copies: the profile screen in Stage 5 shows the same
/// heading and the same "nothing here yet" card, and two implementations of one
/// visual would drift the moment either theme changes.
class HomeSectionHeader extends SectionHeader {
  const HomeSectionHeader({
    super.key,
    required super.title,
    super.action,
  });
}

/// See [EmptyStateCard].
class HomeEmptyCard extends EmptyStateCard {
  const HomeEmptyCard({
    super.key,
    required super.icon,
    required super.title,
    required super.body,
  });
}
