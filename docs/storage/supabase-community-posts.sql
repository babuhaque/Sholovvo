-- Solovvo · Stage 6 (feed image upload) · Supabase Storage for post photographs
--
-- DELIVERED, NOT APPLIED. Nothing in this repository runs this file, and the app
-- does not need it at build time: with no Supabase defines the compose screen
-- says photo upload is not set up and only the text half of the form is offered.
--
-- WHY THIS FILE EXISTS AND `supabase-post-images.sql` DOES NOT GET RUN.
-- The owner decision (2026-11-04) is that `community-posts` is the authoritative
-- feed bucket. It already holds photographs uploaded by an earlier build; the
-- app now targets it by default (`SupabaseConfig.defaultPostImagesBucket`) and
-- MUST NOT be pointed back at `post-images`, which would orphan the objects that
-- are already there. This file is the storage-policy counterpart of that
-- decision. `supabase-post-images.sql` is retained for history but is superseded
-- for new uploads by this one.
--
-- Where to run it: Supabase dashboard -> SQL Editor, in the same project that
-- already carries the Firebase third-party auth integration for
-- `sholovvo-blood-donation` (the one the `avatars` bucket lives in). See
-- README.md in this folder for the full order of operations.
--
-- The identity model is unchanged from the avatars/post-images buckets and is
-- the only thing that decides the predicates below:
--   * The app authenticates with **Firebase** ID tokens and has no Supabase
--     user, so there is no `role` claim on the token. Supabase therefore treats
--     the request as the `anon` Postgres role. Minting `role: 'authenticated'`
--     would need a blocking function on Firebase (Blaze) -- not used here.
--   * Instead of trusting a role, every policy proves three things itself: the
--     token came from this Firebase project (`iss`), it was issued for this
--     project (`aud`), and the path it writes sits under the token's own `sub`.
--     A request without a verified Firebase token has no `sub` and no `iss`, so
--     every comparison below is false and the row is refused.
--
-- --------------------------------------------------------------------------
-- READ-ONLY PREREQUISITE -- VERIFY BEFORE APPLYING (never assumed here)
-- --------------------------------------------------------------------------
-- The bucket already has live objects. Existing photographs are served over the
-- PUBLIC object route (bucket public read), so reads never touch RLS and every
-- image already referenced by a post keeps rendering no matter what the policies
-- below do. The policies only govern NEW inserts and the deletes the app itself
-- performs, and the client writes new objects as `{uid}/post-{millis}-{n}.{ext}`
-- (one folder level, named after the caller). Confirm the existing layout so the
-- insert/delete ownership shape matches how the app writes:
--
--   -- what top-level folders already exist, and their shapes
--   select split_part(name, '/', 1) as top_folder,
--          count(*)                  as objects
--   from storage.objects
--   where bucket_id = 'community-posts'
--   group by 1
--   order by objects desc;
--
-- If existing objects live under some OTHER shape (a bucket-root file, a
-- `posts/{id}/...` tree, a foreign folder), that is FINE for them -- they stay
-- publicly readable -- but it means the insert policy below only ever authorises
-- the app's own `{uid}/...` writes, and a legacy object outside a caller's own
-- folder cannot be deleted through this policy. Do not loosen the predicate to
-- reach those; deleting foreign objects is a separate, owner-approved decision.
--
-- 1. The bucket.
--
-- Public read, 5 MB, the three formats the validator sniffs (PostValidator
-- reuses the same photo rules as the avatar sheet). The limits are the actual
-- enforcement -- the client checks are a courtesy. `public = true` is the only
-- reason `Image.network` needs no Authorization header; nothing private may ever
-- be stored here.
--
-- NOTE: if `community-posts` ALREADY EXISTS in the project, do NOT re-run this
-- insert. Confirm its settings match and, if they do not, adjust the existing
-- bucket rather than dropping it (dropping empties it, which would destroy the
-- images this file exists to preserve):
--
--   select id, public, file_size_limit, allowed_mime_types
--   from storage.buckets where id = 'community-posts';
--
-- If it is absent, create it:
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-posts',
  'community-posts',
  true,
  5242880, -- 5 * 1024 * 1024, the same number as PhotoValidator.maxBytes
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- 2. Uploads: a donor may create objects inside their own folder, and nowhere
--    else. There is no update policy on purpose: the app's object names carry a
--    millisecond timestamp and a per-session sequence number
--    (`post-{millis}-{n}`), `upsert` is off, and a photograph is never replaced
--    -- removing one deletes the object and the document field together -- so
--    overwriting an existing object is never needed and is not allowed.
drop policy if exists "community-posts: donor uploads into their own folder" on storage.objects;
create policy "community-posts: donor uploads into their own folder"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'community-posts'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  -- `{uid}/file.jpg` only: one folder level, named after the caller. A nested
  -- path, another donor's folder, or a file at the bucket root is refused. The
  -- client's objectPath builds exactly this shape; the client's ownPath refuses
  -- anything else before a delete is attempted.
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- 3. Deletes: the same ownership proof, for the two paths in the app --
--    `ComposeController.removeImage` (the donor took a photo back out of the
--    draft) and `ComposeController.discard` (the draft was abandoned, so the
--    objects it uploaded have no document that will ever own them).
--
--    What this policy does NOT cover: deleting a published post does not delete
--    its images (the feed has no delete yet), and it can never delete a legacy
--    object that lives outside the caller's own folder.
drop policy if exists "community-posts: donor deletes from their own folder" on storage.objects;
create policy "community-posts: donor deletes from their own folder"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'community-posts'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- Deliberately absent:
--   * no `select` policy -- downloads go through the public object route, which
--     streams from the CDN without touching RLS; nothing needs to list the bucket
--   * no `update` policy -- see above
--   * no policy on any other bucket -- RLS denies by default, and the app never
--     addresses another bucket
--   * nothing on `posts` in Firestore -- this file does not touch the database.
--
-- The client refuses to send a privileged key at all (`SupabaseConfig` rejects
-- `sb_secret_...` and any JWT carrying `role: service_role`), so an RLS bypass
-- key cannot be shipped by accident.

-- 4. Verification. Run these after applying, and keep the output with the
--    project record: the stage report has to be able to say what the bucket and
--    the policies actually are.
--
-- select id, name, public, file_size_limit, allowed_mime_types
-- from storage.buckets where id = 'community-posts';
--
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies
-- where schemaname = 'storage' and tablename = 'objects'
--   and policyname like 'community-posts:%'
-- order by policyname;

-- 5. Rolling back (only to remove the feature, never to make an upload work):
--    Drop the POLICIES only. Do NOT `delete from storage.buckets` -- that empties
--    the bucket and would destroy the pre-existing images this file preserves.
--
-- drop policy if exists "community-posts: donor uploads into their own folder" on storage.objects;
-- drop policy if exists "community-posts: donor deletes from their own folder" on storage.objects;
