# Firestore schema

The canonical reference for what's in Firestore, how documents are keyed, and
which `firestore.rules` function governs each path. Read this before touching
Firestore data by hand in the Console — see
[firestore-cutover.md](firestore-cutover.md) for the history of how this
schema came to be.

## Collections at a glance

| Path                                          | Doc ID convention                          | Governed by                                    |
| ---------------------------------------------- | ------------------------------------------- | ----------------------------------------------- |
| `users/{userId}`                               | account email, `.trim().toLowerCase()`      | `isOwnProfile`, `isInstaller`, `isOwnProfileUpdate`, `isNewUnassignedProfile` |
| `installations/{installationId}`               | the homeowner's own Firebase Auth **UID**   | `isAssignedHomeowner`, `isInstaller`            |
| `installations/{installationId}/settings/mqtt` | fixed doc ID `mqtt`                         | `isAssignedHomeowner`, `isInstaller`            |
| `installations/{installationId}/assets/{assetId}` | Firestore auto-ID                        | `isAssignedHomeowner`, `isInstaller`            |
| `installations/{installationId}/presence/{presenceUid}` | the signed-in user's Firebase Auth **UID** | `isOwnUid` + `isAssignedHomeowner`  |
| `telemetry/{installationId}/history/{series}`  | `installationId` == homeowner's UID; `series` is a fixed name (e.g. `graphs`) | `isAssignedHomeowner` |

**There are two identity spaces at play, not one.** `users/{userId}` is keyed
by **email**. Everything under `installations/{installationId}` — including
the `installationId` path segment itself and the `presence/{presenceUid}`
subcollection — is keyed by Firebase Auth **UID**. Don't conflate the two: a
homeowner's own UID is both their `installations/{id}` document ID *and* the
`presence` doc ID under it, but it is never a `users` document ID.

## `users/{email}`

Written by `AuthService._ensureProfile` (`lib/features/auth/data/auth_service.dart`)
on every sign-in/sign-up, and by `AccessControlService.assignHomeowner` /
`revokeAccess` (`lib/features/auth/data/access_control_service.dart`) during
handover/revocation. Read by `AccessControlService.resolve`, `watchCurrent`,
`watchUsers`.

| Field         | Type   | Required | Notes                                                                 |
| ------------- | ------ | -------- | ---------------------------------------------------------------------- |
| `uid`         | string | usually  | The account's Firebase Auth UID. Absent on hand-authored docs until the account signs in or is handed over — treat as nullable everywhere. |
| `email`       | string | yes      | Matches the doc ID once lowercased/trimmed.                          |
| `role`        | string | yes      | One of `installer`, `homeowner`, `unassigned`.                       |
| `fullName`    | string | no       |                                                                        |
| `phoneNumber` | string | no       |                                                                        |
| `updatedAt`   | timestamp | yes   | Server timestamp, set on every write.                                |

There is **no `installationId` field** on this document. A homeowner's
installation ID is always their own `uid` — see below.

## `installations/{uid}`

Doc ID is the homeowner's Firebase Auth UID, not an auto-generated ID.
Created/updated by `AccessControlService.assignHomeowner` (sets `status:
active`) and `revokeAccess` (sets `status: unassigned`).

| Field       | Type      | Notes                          |
| ----------- | --------- | ------------------------------- |
| `name`      | string    | Installer-assigned label.       |
| `ownerUid`  | string    | Same value as the doc ID.       |
| `status`    | string    | `active` or `unassigned`.       |
| `createdAt` | timestamp | Set once, on first handover.    |
| `updatedAt` | timestamp | Server timestamp.               |

### `installations/{uid}/settings/mqtt`

MQTT broker config for the installation. Written by installers via
`AppState.saveSharedMqttConfig` → `MqttCloudConfigStore`
(`lib/core/services/mqtt_cloud_config_store.dart`). Fields: `host`,
`password`, `port`, `topicNamespace`, `updatedAt`, `useTls`, `username`,
`webSocketPath`.

### `installations/{uid}/assets/{assetId}`

Physical device assets tied to the installation. Written/read by
`AccessControlService.addAsset`/`watchAssets`/`removeAsset`. Fields:
`deviceId`, `name`, `type`, `createdAt`, `updatedAt`.

### `installations/{uid}/presence/{presenceUid}`

Live connection presence for the homeowner app. **`{presenceUid}` is a
Firebase Auth UID, matching the parent `installations/{uid}`** — this is
homeowner-only data, not a list of arbitrary users. Written by
`AppState._publishPresence` → `MqttPresenceStore`
(`lib/core/services/mqtt_presence_store.dart`). Fields: `online`, `status`,
`lastSeen`.

## `telemetry/{uid}/history/{series}`

Cached telemetry history, keyed by the homeowner's UID (same value as their
`installations/{uid}` doc). Written/read by `TelemetryHistoryStore`
(`lib/core/services/telemetry_history_store.dart`).

## Which code touches this

- `lib/features/auth/data/auth_service.dart` — creates `users/{email}` on sign-in/sign-up.
- `lib/features/auth/data/access_control_service.dart` — all reads/writes to `users` and `installations` (incl. handover/revoke), plus `assets`.
- `lib/core/services/mqtt_cloud_config_store.dart` — `installations/{uid}/settings/mqtt`.
- `lib/core/services/mqtt_presence_store.dart` — `installations/{uid}/presence/{uid}`.
- `lib/core/services/telemetry_history_store.dart` — `telemetry/{uid}/history/{series}`.
- `lib/core/app_state/app_state.dart` — orchestrates the above; owns `resolveCurrentAccess`, `assignHomeowner`, `revokeAccess`, `watchAccessUsers`.
- `firestore.rules` — security rules for every path above.

## Change log

See [firestore-cutover.md](firestore-cutover.md) for the history of hard
cutovers this schema has been through.
