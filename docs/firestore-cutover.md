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

## Canonical schema

```text
users/{uid}
  uid
  email
  fullName
  phoneNumber
  role: installer | homeowner | unassigned
  installationId                    # homeowner only

installations/{installationId}
  name
  ownerUid
  status: active | unassigned

installations/{installationId}/settings/mqtt
installations/{installationId}/assets/{assetId}
installations/{installationId}/presence/{uid}
telemetry/{installationId}/history/graphs
```

The commissioning transaction creates the installation document and updates
the homeowner profile atomically. There is no compatibility or fallback read.
