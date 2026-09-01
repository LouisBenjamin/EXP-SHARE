# Push notifications (FCM) — setup handoff

Realtime in-app updates are done (Push 5). **Background push notifications** need a
Firebase project and credentials that can't be scaffolded without your account, so
they're documented here rather than half-wired (adding Firebase to Android without
`google-services.json` breaks the Gradle build).

## What's already in place
- `device_tokens` table (migration `0008`) — stores each user's push token, RLS so a
  user only manages their own.
- Live in-app updates via Supabase Realtime (no Firebase needed) — see
  `lib/features/realtime/group_realtime_provider.dart`.

## What you need to do

### 1. Create a Firebase project
- console.firebase.google.com → add project.
- Add an **Android app** with package name **`com.tally.app`** → download
  `google-services.json` → place in `android/app/`.
- (Web push) Add a **Web app** → copy the config + generate a **Web Push (VAPID) key**.

### 2. Add Flutter dependencies
```
flutter pub add firebase_core firebase_messaging
```
Android: add the `com.google.gms.google-services` Gradle plugin (Firebase console shows
the exact lines for `android/build.gradle.kts` and `android/app/build.gradle.kts`).

### 3. Register the token in the app
On launch (after login), request permission, get the FCM token, and upsert it:
```dart
final token = await FirebaseMessaging.instance.getToken(/* vapidKey on web */);
await supabase.from('device_tokens').upsert({
  'user_id': supabase.auth.currentUser!.id,
  'token': token,
  'platform': kIsWeb ? 'web' : 'android',
}, onConflict: 'user_id,token');
```
Handle `onTokenRefresh` to keep it current.

### 4. Send pushes from an Edge Function
Create `supabase/functions/send-push` that, on a new expense (call it from a DB trigger
via `pg_net`/webhook, or `supabase functions invoke`), looks up the group members'
`device_tokens` and POSTs to FCM v1 (`https://fcm.googleapis.com/v1/projects/<id>/messages:send`)
using a **service-account** credential stored as a function secret
(`supabase secrets set FCM_SERVICE_ACCOUNT=...`). Never ship that key in the app.

### 5. CI
Android release builds need `google-services.json`. Store it as a base64 secret and
write it out in the workflow before `flutter build apk`, or commit a non-secret dev one.

## Suggested trigger
Fire a notification when an expense is added to a group: "New expense in <group>:
<description> — <amount>". The recipient list is every member of `group_id` except the
creator, resolved through `device_tokens`.
