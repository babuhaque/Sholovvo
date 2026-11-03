-- Solovvo · Stage 8.3 · Supabase Storage for post photographs
--
-- DELIVERED, NOT APPLIED. Nothing in this repository runs this file, and the
-- app does not need it at build time: with no Supabase defines, the compose
-- screen says photo upload is not set up and only the text half of the form is
-- offered.
--
-- Where to run it: Supabase dashboard → SQL Editor, in the same project that
-- already carries the Firebase third-party auth integration for
-- `sholovvo-blood-donation` (the one Stage 6's avatars bucket lives in).
-- See README.md in this folder for the full order of operations.
--
-- This file is deliberately almost a copy of supabase-avatars.sql. It is a
-- second bucket rather than a second design, and the identity model is the only
-- thing that decides the predicates:
--   * The app authenticates with **Firebase** ID tokens and has no Supabase
--     user, so there is no `role` claim on the token. Supabase therefore treats
--     the request as the `anon` Postgres role. Minting `role: 'authenticated'`
--     would need a blocking function on Firebase (Blaze) — not used here.
--   * Instead of trusting a role, every policy proves three things itself:
--     the token came from this Firebase project (`iss`), it was issued for this
--     project (`aud`), and the path it is writing sits under the token's own
--     `sub`. A request without a verified Firebase token has no `sub` and no
--     `iss`, so every comparison below is false and the row is refused.
--
-- Why this is not the avatars bucket:
--   * A post carries up to four photographs, each of which may be deleted
--     independently while the draft is still being written. Mixing them into
--     `avatars` would mean one delete policy whose blast radius covers a
--     donor's profile photo.
--   * The two buckets will age differently. Avatars are replaced one at a time;
--     post images accumulate one folder of orphans per deleted post and will be
--     swept by a different job, at a different time, on a different budget.

-- 1. The bucket.
--
-- One bucket with a folder per donor (`{uid}/post-{millis}-{n}.{ext}`) rather
-- than a bucket per donor: bucket count is a project-wide resource and per-user
-- folders are what the policies address.
--
-- `public = true` is deliberate and is the only reason `Image.network` needs no
-- Authorization header. Feed photographs are, by product design, shown to every
-- signed-in donor; the compose screen offers no "private post" toggle, so
-- nothing is promised that the bucket would not honour. Nothing private may
-- ever be stored here.
--
-- The limits mirror the client: 5 MB and the three formats the validator sniffs
-- (PostValidator reuses the same photo rules as the avatar sheet). They are the
-- actual enforcement — the client checks are a courtesy.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-images',
  'post-images',
  true,
  5242880, -- 5 * 1024 * 1024, the same number as PhotoValidator.maxBytes
  array['image/jpeg', 'image/png', 'image/webp']
);

-- 2. Uploads: a donor may create objects inside their own folder, and nowhere
--    else. There is no update policy on purpose: the app's object names carry a
--    millisecond timestamp and a per-session sequence number
--    (`post-{millis}-{n}`), `upsert` is off, and a photograph is never replaced
--    — removing one deletes the object and the document field together — so
--    overwriting an existing object is never needed and is not allowed.
drop policy if exists "post-images: donor uploads into their own folder" on storage.objects;
create policy "post-images: donor uploads into their own folder"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'post-images'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  -- `{uid}/file.jpg` only: one folder level, named after the caller. A nested
  -- path, another donor's folder, or a file at the bucket root is refused.
  -- The client's objectPath builds exactly this shape; the client's ownPath
  -- refuses anything else before a delete is attempted.
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- 3. Deletes: the same ownership proof, for two paths in the app —
--    `ComposeController.removeImage` (the donor took a photo back out of the
--    draft) and `ComposeController.discard` (the draft was abandoned, so the
--    objects it uploaded have no document that will ever own them).
--
--    Note what this policy does *not* cover: deleting a published post does not
--    delete its images. That is a stage-9+ decision (the feed has no delete yet)
--    and it will need the same proof plus a document read.
drop policy if exists "post-images: donor deletes from their own folder" on storage.objects;
create policy "post-images: donor deletes from their own folder"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'post-images'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- Deliberately absent:
--   * no `select` policy — downloads go through the public object route, which
--     streams from the CDN without touching RLS; nothing needs to list the
--     bucket
--   * no `update` policy — see above
--   * no policy on any other bucket — RLS denies by default, and the app never
--     addresses another bucket
--   * nothing on `posts` in Firestore — this file does not touch the database.
--     `firestore.rules` already permits a create whose `authorUid` equals
--     `request.auth.uid`; it does not yet validate the field shapes.
--
-- The client refuses to send a privileged key at all (`SupabaseConfig` rejects
-- `sb_secret_...` and any JWT carrying `role: service_role`), so an RLS bypass
-- key cannot be shipped by accident.

-- 4. Verification. Run these after applying, and keep the output with the
--    project record: the stage report has to be able to say what the bucket and
--    the policies actually are.
--
-- select id, name, public, file_size_limit, allowed_mime_types
-- from storage.buckets
-- where id = 'post-images';
--
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies
-- where schemaname = 'storage' and tablename = 'objects'
--   and policyname like 'post-images:%'
-- order by policyname;
--
-- A quick negative test that needs no token at all (must return 400/403, never
-- a URL): the same request with a foreign `sub` is what the predicates refuse.
--
-- select auth.jwt() ->> 'sub';
--   → null outside a request, which is exactly why an unauthenticated caller
--     cannot satisfy `(storage.foldername(name))[1] = auth.jwt() ->> 'sub'`.

-- 5. Rolling back (only to remove the feature, never to make an upload work):
--
-- drop policy if exists "post-images: donor uploads into their own folder" on storage.objects;
-- drop policy if exists "post-images: donor deletes from their own folder" on storage.objects;
-- delete from storage.buckets where id = 'post-images'; -- empties the bucket too
