# Hogona

Rider companion app (iOS + Android, Flutter). Phase I prototype.

## Working now
- Create a group (4-digit code) or join with a code
- Live rider pins on an OpenStreetMap map
- Handlebar remote via keyboard keys: Up / + zoom in, Down / - zoom out,
  arrows pan left/right, Enter re-centres. Any Bluetooth keyboard works for testing.
- Demo mode: without Firebase, two simulated riders orbit you so you can try it solo.

## Run
```
flutter pub get
flutter run
```

## Firebase setup (real multi-phone groups)
1. Create a free Firebase project, add an Android and an iOS app (`com.air.air_rider`).
2. Enable Authentication > Anonymous, and create a Realtime Database.
3. Run `flutterfire configure`, which adds `google-services.json` and `GoogleService-Info.plist`.
4. Rebuild. The app switches from demo mode to Firebase automatically.

## Next
Music controls, then push-to-talk voice (LiveKit).
