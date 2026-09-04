# NaturalBeauty — Flutter app

Client for the Node/Express API in `../backend`.

## Getting the APK without installing Flutter

Every push to `main` that touches `app/` triggers a GitHub Actions build.

1. Open the repo's **Actions** tab
2. Click the most recent **Build Android APK** run
3. Wait for the green tick (~5 minutes)
4. Download **naturalbeauty-apk** from the Artifacts section
5. Unzip and install `app-release.apk` on the phone
   (Android will ask you to allow installing from unknown sources)

You can also trigger a build by hand: Actions → Build Android APK → **Run workflow**.

## Before it will connect

The API URL is set in one place — [`lib/config.dart`](lib/config.dart):

```dart
static const String baseUrl = 'http://192.168.1.5:3000';
```

For this to work from a phone:

- `npm run dev` must be running on the PC
- The PC's IP must still be `192.168.1.5` — check with `ipconfig`, it changes
- Phone and PC must be on the same Wi-Fi
- Windows Firewall must allow inbound TCP on port 3000

To open the firewall port, in an **admin** PowerShell:

```powershell
New-NetFirewallRule -DisplayName "Node API 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

Also make sure Express listens on all interfaces, not just localhost:

```js
app.listen(3000, '0.0.0.0', () => { ... });
```

## Screens

| Screen | Endpoint used |
|---|---|
| Login | `POST /auth/login` — stores the JWT on the device |
| Signup | `POST /auth/signup` |
| Create post | `POST /posts/create` — multipart, camera or gallery |
| Like | `POST /likes/:id/like`, `DELETE /likes/:id/unlike` |

## What's missing, and why

There is **no feed**. The backend has no endpoint that returns posts —
`getPost` and `getUserPost` are empty stubs — so there is nothing to list.

For the same reason, liking asks for a post ID by hand instead of showing
a heart under a photo. The ID is shown in a snackbar after creating a post.

Once these exist on the server, a feed screen becomes possible:

- `GET /posts/feed` — all posts, newest first, paginated
- `GET /posts/:id` — one post with author, like count, is_liked
- `GET /posts/user/:userId` — a profile grid
- `app.use('/uploads', express.static('uploads'))` — without this,
  image URLs return 404 and no photo will render

## Structure

```
app/
├── lib/
│   ├── main.dart              entry point, decides login vs home
│   ├── config.dart            API base URL — edit this
│   ├── services/
│   │   └── api_service.dart   every HTTP call to the backend
│   └── screens/
│       ├── login_screen.dart
│       ├── signup_screen.dart
│       ├── home_screen.dart
│       ├── create_post_screen.dart
│       └── like_screen.dart
└── android/                   manifest: internet + camera + cleartext HTTP
```

Only `lib/`, `pubspec.yaml` and the Android config are committed. The CI
workflow runs `flutter create` to generate the rest of the scaffolding.
