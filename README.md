# Kilowatts Mobile

Kilowatts is a mobile-only Flutter application with role-based entry:

- Homeowners operate their assigned energy installation.
- Installers receive one commissioning screen for homeowner handover, MQTT,
  and device-asset assignment.

Each physical installation has a Firestore-generated installation ID. User
UIDs identify people only and are never used as installation identifiers.

Release builds must use a private Android upload key. Copy
`android/key.properties.example` to `android/key.properties`, set the real
keystore values, and keep both the completed properties file and the keystore
outside version control.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```
