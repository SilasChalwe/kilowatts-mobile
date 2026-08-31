# Firestore schema cutover

This release is a hard cutover. It does not read the former email-keyed user
documents or UID-keyed installations.

## Required production cutover

Before releasing the application:

1. Back up Firestore.
2. Deploy the new `firestore.rules`.
3. Remove the former `users/{email}` documents and UID-keyed installation and
   telemetry documents.
4. Ask every account to sign in once so the app creates `users/{uid}`.
5. Bootstrap the first installer by setting `users/{installerUid}.role` to
   `installer` in Firebase Console.
6. Use the mobile commissioning page to hand each homeowner a newly generated
   installation, MQTT configuration, and device assets.

## Canonical schema (superseded)

This UID-keyed-users / auto-generated-installation-ID scheme was reverted by
the 2026-08-31 cutover below. See [firestore-schema.md](firestore-schema.md)
for the current canonical schema.

## 2026-08-31 cutover: back to email-keyed users, UID-as-installation-ID

This reverses the cutover above. `users` is keyed by email again, and
`installations` is keyed by the homeowner's own UID instead of a
Firestore-generated ID — see [firestore-schema.md](firestore-schema.md) for
the full current schema. Rationale: the previous UID-keyed scheme made it
easy to create Firestore documents by hand (e.g. in the Console) with the
wrong doc ID, silently breaking role resolution with no error surfaced
anywhere — this happened in production. Keying by email is what actually
gets typed by hand, and dropping the separate installation ID removes a
second ID to get wrong.

### Required production cutover

1. Back up Firestore.
2. Identify the installer account(s) and manually create/update
   `users/{their-lowercased-email}` with `role: 'installer'` **before** they
   next sign in — `_ensureProfile` sets `role: 'unassigned'` on any newly
   created doc, and only installers can grant installer role, so skipping
   this step locks everyone out with no in-app recovery.
3. For any homeowner with a working UID-keyed profile/installation today,
   manually recreate `users/{their-email}` (same fields, drop
   `installationId`) and `installations/{their-uid}` (`name`, `status`,
   `ownerUid`, plus their `settings/mqtt` and `assets/*` docs).
4. Deploy the new `firestore.rules`.
5. Release the new app build in the same window as the rules deploy — the
   two can't be deployed atomically for a mobile app, so expect a brief
   breakage window for any already-installed build that hasn't updated yet.
6. Spot-check with the installer account and a homeowner account.
7. Leave old UID-keyed `users/{uid}` and old auto-ID `installations/{...}`
   docs in place for a week or two (installer-readable only, harmless)
   before deleting.
