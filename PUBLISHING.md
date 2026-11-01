# Publishing müslic to Google Play

## App identity

| | |
|---|---|
| App name | müslic |
| Developer | dot Studios |
| Package name | `com.dotstudios.muslic` (permanent once published) |
| Version | `version:` in `pubspec.yaml` (shown to users); the build number (version code) is the CI run number, so every build can be uploaded |
| Target SDK | 36 (Android 16), as Play requires since 31 Aug 2026 |

## Signing

Builds are signed with dot Studios' **upload key** (`muslic-upload.jks`,
alias `upload`). Google re-signs the app for users with its own app signing
key (Play App Signing), so the upload key only proves uploads come from you.
If it is ever lost, Google can reset it from Play Console after you verify
your identity.

The key is **not** in this repository (it is public). CI reads it from two
repository secrets. To set them: GitHub repo → Settings → Secrets and
variables → Actions → New repository secret.

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the full contents of `muslic-upload.jks.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | the password from `muslic-upload-password.txt` |

Then push any commit (or Actions → Build müslic → Run workflow). The build's
`verify.log` (branch `ci-logs`) shows the signer: it must say
`CN=dot Studios`, not `CN=Android Debug`.

Keep `muslic-upload.jks` and its password somewhere safe outside GitHub
(a password manager is ideal).

## Uploading

Play only accepts the bundle: upload a **signed `muslic.aab`**, not an APK.
Until the two secrets above are set, CI bundles are debug-signed; sign one
by hand with the upload key (this is what produced `muslic-1.0.0-play.aab`):

```
zip -d muslic.aab 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/MANIFEST.MF'
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore muslic-upload.jks muslic.aab upload
jarsigner -verify muslic.aab
```

1. Create the app in Play Console: name müslic, app, free or paid.
   A paid app needs a Google Payments merchant account first, and an app
   published as free can never be changed to paid later.
2. Keep Play App Signing on (default) and upload the bundle to a testing
   track (Internal testing is fastest).
3. Personal developer accounts created after 13 Nov 2023 must run a
   **closed test with at least 12 testers, opted in for 14 days in a row**,
   before they can apply for production access.
4. Fill in **App content**:
   - Privacy policy: host `PRIVACY.md` at a public URL and paste the link.
     Replace "[support email]" first.
   - Data safety: "No data collected or shared". All data stays on device
     and the app never connects to the internet.
   - Foreground service permissions: declare **Media playback**. It keeps
     music playing with the screen off, with controls in the notification
     and on the lock screen. Play may ask for a short screen recording.
   - Content rating questionnaire (music player, no user content), target
     audience, ads: none.
5. Store listing: the 512 px icon and the 1024 x 500 feature graphic are in
   `store/`. Add at least 2 phone screenshots taken on a real phone, a
   short description (80 characters) and a full description.
6. Each new upload needs a higher version code. CI uses its run number, so
   every CI bundle can be uploaded after the previous one. Raise
   `version:` in `pubspec.yaml` (for example 1.0.1) for the name users see.

## Licences

- The app is proprietary: see `LICENSE` ("All rights reserved"). The
  copyright line is also shown at the bottom of Settings.
- Every library is under a permissive licence (MIT, BSD, Apache 2.0; fonts
  under the SIL Open Font License). None is GPL/LGPL/AGPL. Each CI run
  lists them in `licenses.log` on the `ci-logs` branch.
- These licences allow commercial use and selling. Their one condition is
  keeping their copyright notices, which the app does under Settings >
  Open-source licences.
- `packages/just_audio` is a modified copy of an MIT-licensed plugin; its
  `LICENSE` file must stay in the repository.

## Why a sideloaded APK shows a warning

Installing any APK from outside the Play Store goes through Android's
"unknown apps" check, and Play Protect warns about apps it has not seen
from a known developer. Signing with the dot Studios key (instead of
Flutter's shared debug key) helps, but the warning cannot be fully removed
for sideloaded copies. Installs from the Play Store do not show it.
