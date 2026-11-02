-- Solovvo · Stage 6 · Supabase Storage for profile photos
--
-- DELIVERED, NOT APPLIED. Nothing in this repository runs this file, and the
-- app does not need it at build time: with no Supabase defines the photo sheet
-- simply reports that upload is not set up.
--
-- Where to run it: Supabase dashboard → SQL Editor, in the project that carries
-- the Firebase third-party auth integration for `sholovvo-blood-donation`.
-- See README.md in this folder for the full order of operations.
--
-- Why the policies are written this way (short version):
--   * The app authenticates with **Firebase** ID tokens and has no Supabase
--     user, so there is no `role` claim on the token. Supabase therefore treats
--     the request as the `anon` Postgres role. Minting `role: 'authenticated'`
--     would need a blocking function on Firebase (Blaze) — not used here.
--   * Instead of trusting a role, every policy proves three things itself:
--     the token came from this Firebase project (`iss`), it was issued for this
--     project (`aud`), and the path it is writing sits under the token's own
--     `sub`. A request without a verified Firebase token has no `sub` and no
--     `iss`, so every comparison below is false and the row is refused.

-- 1. The bucket.
--
-- One bucket with a folder per donor (`{uid}/avatar-{millis}.{ext}`) rather than
-- a bucket per donor: bucket count is a project-wide resource and per-user
-- folders are what the policies address.
--
-- `public = true` is deliberate and is the only reason `Image.network` needs no
-- Authorization header. Profile photos are shown on the donor card that other
-- donors see, so they are public by product design; the app says so in the
-- sheet before the first upload. Nothing private may ever be stored here.
--
-- The limits mirror the client: 5 MB and the three formats the validator sniffs.
-- They are the actual enforcement — the client checks are a courtesy.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 * 1024 * 1024, the same number as PhotoValidator.maxBytes
  array['image/jpeg', 'image/png', 'image/webp']
);

-- 2. Uploads: a donor may create objects inside their own folder, and nowhere
--    else. There is no update policy on purpose: the app's object names are
--    unique per upload (`avatar-{millis}`), `upsert` is off, and replacement is
--    "upload a new object, then publish its URL", so overwriting an existing
--    object is never needed and is not allowed.
drop policy if exists "avatars: donor uploads into their own folder" on storage.objects;
create policy "avatars: donor uploads into their own folder"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'avatars'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  -- `{uid}/file.jpg` only: one folder level, named after the caller. A nested
  -- path, another donor's folder, or a file at the bucket root is refused.
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- 3. Deletes: the same ownership proof, for removal and for the compensation
--    path (a photo was uploaded but the profile write that would have published
--    it failed, so the app deletes the object again).
drop policy if exists "avatars: donor deletes from their own folder" on storage.objects;
create policy "avatars: donor deletes from their own folder"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'avatars'
  and auth.jwt() ->> 'iss' = 'https://securetoken.google.com/sholovvo-blood-donation'
  and auth.jwt() ->> 'aud' = 'sholovvo-blood-donation'
  and (auth.jwt() ->> 'sub') is not null
  and (auth.jwt() ->> 'sub') <> ''
  and array_length(storage.foldername(name), 1) = 1
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

-- Deliberately absent:
--   * no `select` policy — downloads go through the public object route, which
--     streams from the CDN without touching RLS; nobody needs to list the bucket
--   * no `update` policy — see above
--   * no policy on any other bucket — RLS denies by default, and the app never
--     addresses another bucket
--
-- The client refuses to send a privileged key at all (`SupabaseConfig` rejects
-- `sb_secret_...` and any JWT carrying `role: service_role`), so an RLS bypass
-- key cannot be shipped by accident.

-- 4. Verification. Run these after applying, and keep the output with the
--    project record: the report for Stage 6 has to be able to say what the
--    bucket and the policies actually are.
--
-- select id, name, public, file_size_limit, allowed_mime_types
-- from storage.buckets
-- where id = 'avatars';
--
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies
-- where schemaname = 'storage' and tablename = 'objects'
-- order by policyname;
--
-- A quick negative test that needs no token at all (must return 400/403, never
-- a URL): the same request with a foreign `sub` is what the predicates refuse.
--
-- select auth.jwt() ->> 'sub';
--   → null outside a request, which is exactly why an unauthenticated caller
--     cannot satisfy `(storage.foldername(name))[1] = auth.jwt() ->> 'sub'`.
