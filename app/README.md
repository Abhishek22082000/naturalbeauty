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

## Pointing it at your API

**The URL is set inside the app, not in the code.** On first launch the
app asks for it, and it can be changed any time from the server icon in
the app bar or the link under the login button.

Enter whatever address your Node server is on, e.g. `192.168.1.16:3000`.
The `http://` and `:3000` are filled in for you if you leave them out.
**Test** checks the server answers before you save, so you find problems
on that screen rather than at the login prompt.

Because the URL lives on the device, a changed IP means editing one field
on the phone — no APK rebuild.

For a phone to reach a backend on your PC:

- `npm run dev` must be running
- The IP must be current — run `ipconfig` on the PC, it changes when the
  router reassigns DHCP leases
- Phone and PC on the same Wi-Fi
- Windows Firewall must allow inbound TCP 3000. In an **admin** PowerShell:

```powershell
New-NetFirewallRule -DisplayName "Node API 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

The backend must also bind to all interfaces, not just localhost —
`app.listen(3000, '0.0.0.0', ...)`. This is already set.

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
│   ├── config.dart            API base URL, saved on the device
│   ├── services/
│   │   └── api_service.dart   every HTTP call to the backend
│   └── screens/
│       ├── login_screen.dart
│       ├── signup_screen.dart
│       ├── home_screen.dart
│       ├── server_screen.dart    backend URL + connection test
│       ├── create_post_screen.dart
│       └── like_screen.dart
└── android/                   manifest: internet + camera + cleartext HTTP
```

Only `lib/`, `pubspec.yaml` and the Android config are committed. The CI
workflow runs `flutter create` to generate the rest of the scaffolding.
