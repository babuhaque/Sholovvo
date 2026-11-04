import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

/// The three seams between the dashboard's layout and the data behind it.
///
/// The donor strip is filled in from Stage 5: it reads the same documents the
/// profile screen edits (`users/{uid}` and `users/{uid}/private/profile`) and the
/// donor's own `donation_history`. The feed is filled in from Stage 8, and the
/// nearby requests from Stage 9, both as projections of the controller that owns
/// the read (see [feedPreviewProvider] and [nearbyRequestsProvider]). Nothing here
/// is a placeholder number — a dashboard that shows "12 requests nearby" before
/// anything has been queried is lying to someone who may act on it.
///
/// The projection from profile data into [DonorSnapshot] lives here rather than
/// in the profile feature because the adapter belongs to its consumer: the
/// profile feature knows nothing about the dashboard's view models.
final Provider<DonorSnapshot?> donorSnapshotProvider =
    Provider<DonorSnapshot?>((Ref ref) {
      final UserProfile? profile = ref.watch(profileProvider).value;
      // No document yet: the card says "Not set yet" rather than "no blood
      // group", which is a different and false claim.
      if (profile == null) {
        return null;
      }

      // A failed history read is not a zero-count history: `valueOrNull` keeps
      // the statistics absent instead of showing "0 donations" to someone who
      // has given blood.
      final DonationHistory? donations = ref
          .watch(donationHistoryProvider)
          .value
          ?.valueOrNull;

      return DonorSnapshot(
        bloodGroup: profile.bloodGroup,
        lastDonationAt: donations?.lastConfirmedAt,
        isAvailable: profile.isAvailable,
        donationCount: donations?.confirmedCount,
      );
    });

/// How many requests the dashboard previews.
///
/// Three, matching the feed preview below it: the two sections share a column on a
/// phone, and a fourth card would push the community off the screen. "See all" is
/// what the rest of the window is for.
const int nearbyRequestLimit = 3;

/// The most urgent open requests, as the dashboard shows them.
///
/// A projection of [requestsControllerProvider] rather than a second read, for the
/// same reason the feed preview is one: the controller already owns the window, the
/// refusal count, the truncation and the one-read-at-a-time rule, and a dashboard
/// that queried `blood_requests` for itself would have two answers to "is anything
/// needed right now". Because the window is ordered soonest-needed first, these
/// three are the three most urgent requests this read saw.
///
/// It is still a `Provider` over a plain list, so a test that wants a preview
/// without a read can override it with one — which is what the dashboard's own
/// layout tests do.
final Provider<List<BloodRequest>> nearbyRequestsProvider =
    Provider<List<BloodRequest>>((Ref ref) {
      final RequestsState requests = ref.watch(requestsControllerProvider);
      return requests.requests.take(nearbyRequestLimit).toList(
        growable: false,
      );
    });

/// How many posts the dashboard previews.
///
/// Three, not a page: the section shares its column with the requests list on a
/// phone, and a fourth card would push the donor's own status off the screen.
/// "See all" is what the rest of the collection is for.
const int feedPreviewLimit = 3;

/// The newest posts, as the dashboard shows them.
///
/// A projection of [feedControllerProvider] rather than a second read. The feed
/// already owns the paging, the cursor, the one-read-at-a-time rule and the
/// failure model; a dashboard that queried `posts` for itself would have two
/// answers to "what is the newest post" and would have to be told which one to
/// believe. This way the preview, the feed screen and a just-published post that
/// [FeedController.prepend] inserts are one list, and the button that says
/// "published" is the button that shows the post.
///
/// It is still a `Provider` over a plain list, so a test that wants a preview
/// without a read can override it with one — which is what the dashboard's own
/// layout tests do.
final Provider<List<FeedPostPreview>> feedPreviewProvider =
    Provider<List<FeedPostPreview>>((Ref ref) {
      final FeedState feed = ref.watch(feedControllerProvider);
      return <FeedPostPreview>[
        for (final Post post in feed.posts.take(feedPreviewLimit))
          FeedPostPreview(
            id: post.id,
            authorName: post.authorName,
            // The card ellipsises at two lines, so the whole text is passed and
            // the layout decides how much of it fits. Cutting it here would be
            // a second truncation the reader cannot expand.
            excerpt: post.text,
            createdAt: post.createdAt,
          ),
      ];
    });
