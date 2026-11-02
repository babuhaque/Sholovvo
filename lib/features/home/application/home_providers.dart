import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// The three seams between the dashboard's layout and the data behind it.
///
/// The donor strip is filled in from Stage 5: it reads the same documents the
/// profile screen edits (`users/{uid}` and `users/{uid}/private/profile`) and the
/// donor's own `donation_history`. The other two stay empty until the stages
/// that own them (`blood_requests` in Stage 9, `posts` in Stage 6). Nothing here
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

final Provider<List<NearbyRequestSummary>> nearbyRequestsProvider =
    Provider<List<NearbyRequestSummary>>(
      (Ref ref) => const <NearbyRequestSummary>[],
    );

final Provider<List<FeedPostPreview>> feedPreviewProvider =
    Provider<List<FeedPostPreview>>((Ref ref) => const <FeedPostPreview>[]);
