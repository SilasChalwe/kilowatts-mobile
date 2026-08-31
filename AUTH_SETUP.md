# Kilowatts Authentication and Access

Kilowatts uses Firebase Email/Password authentication and UID-keyed Firestore
profiles.

## Account lifecycle

```text
Register and verify email
        ↓
users/{uid} with role = unassigned
        ↓
Installer starts handover
        ↓
Firestore generates installations/{installationId}
        ↓
users/{uid}.installationId = installationId
users/{uid}.role = homeowner
        ↓
Homeowner application opens
```

The first installer must be bootstrapped in Firebase Console by setting the
UID-keyed profile's `role` to `installer`. Installer accounts never receive an
`installationId` and only open the commissioning page.

## Firebase Console

1. Enable Email/Password authentication.
2. Configure and brand verification and password-reset emails.
3. Deploy [firestore.rules](firestore.rules).
4. Create the first installer account through normal registration.
5. Change `users/{installerUid}.role` from `unassigned` to `installer` in the
   Firebase Console.

## Security decisions

- Passwords are managed only by Firebase Authentication.
- New accounts cannot assign their own role or installation.
- Only installers can create installations or change MQTT/device assets.
- A homeowner can read only the installation referenced by their own profile.
- Password reset does not disclose whether an email is registered.
- Unverified and unassigned accounts cannot enter the homeowner application.
