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
///
/// The optional [action] is passed through rather than dropped: a section that
/// is empty *and* has somewhere to go from — the community, whose feed and
/// composer exist even when its posts do not — needs the card to carry the way
/// out. An empty card with no control is only honest when there is genuinely
/// nothing to open.
class HomeEmptyCard extends EmptyStateCard {
  const HomeEmptyCard({
    super.key,
    required super.icon,
    required super.title,
    required super.body,
    super.action,
  });
}
