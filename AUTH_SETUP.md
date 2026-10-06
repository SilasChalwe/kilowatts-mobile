# Kilowatts Authentication and Access

Kilowatts uses Firebase Email/Password authentication and email-keyed
Firestore profiles. See [docs/firestore-schema.md](docs/firestore-schema.md)
for the full data model — this file only covers setup steps.

## Account lifecycle

```text
Register and verify email
        ↓
users/{email} with role = unassigned
        ↓
Installer starts handover
        ↓
installations/{uid} created, uid = the homeowner's own Firebase Auth UID
        ↓
users/{email}.role = homeowner
        ↓
Homeowner application opens
```

The first installer must be bootstrapped in Firebase Console by setting the
email-keyed profile's `role` to `installer`. Installer accounts don't have an
installation and only open the commissioning page.

## Firebase Console

1. Enable Email/Password authentication.
2. Configure and brand verification and password-reset emails.
3. Deploy [firestore.rules](firestore.rules).
4. Create the first installer account through normal registration.
5. Change `users/{installer-email}.role` from `unassigned` to `installer` in
   the Firebase Console.

## Security decisions

- Passwords are managed only by Firebase Authentication.
- New accounts cannot assign their own role or installation.
- Only installers can create installations or change MQTT/device assets.
- A homeowner can read only the installation referenced by their own profile.
- Password reset does not disclose whether an email is registered.
- Unverified and unassigned accounts cannot enter the homeowner application.
