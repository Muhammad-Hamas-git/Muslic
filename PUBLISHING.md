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

Play only accepts the bundle: upload **`muslic.aab`** (from the GitHub
release or the `apk` branch), not an APK.

1. Create the app in Play Console: name müslic, app, free.
2. Enable Play App Signing (default) and upload `muslic.aab` to a testing
   track.
3. Personal developer accounts created after 13 Nov 2023 must run a
   **closed test with at least 12 testers for 14 days in a row** before they
   can apply for production access.
4. Fill in **App content**:
   - Privacy policy: host `PRIVACY.md` somewhere public (for example GitHub
     Pages) and paste the link.
   - Data safety: "No data collected or shared". All data stays on device.
   - Foreground service permissions: declare **Media playback**. It is used
     to keep music playing with the screen off, with controls in the
     notification and on the lock screen. Play may ask for a short screen
     recording showing that.
   - Content rating questionnaire, target audience, ads: none.
5. Store listing assets in `store/`: 512 px icon and the 1024 × 500
   feature graphic. You also need at least 2 phone screenshots.

## Why a sideloaded APK shows a warning

Installing any APK from outside the Play Store goes through Android's
"unknown apps" check, and Play Protect warns about apps it has not seen
from a known developer. Signing with the dot Studios key (instead of
Flutter's shared debug key) helps, but the warning cannot be fully removed
for sideloaded copies. Installs from the Play Store do not show it.
