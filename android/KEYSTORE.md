# Android Release Keystore

## Why this exists

Prior to this scaffold, `android/app/build.gradle` wired the `release` build type to
`signingConfigs.debug`. The debug keystore is world-readable and shared across every
Android developer machine — anyone can forge update APKs that Android accepts as coming
from the same app. This is a CRITICAL security issue that blocks Play Store publication.

This scaffold:
- Wires `signingConfigs.release` into `buildTypes.release` when `android/key.properties` is present.
- Falls back to `signingConfigs.debug` with a loud warning when it is absent (safe for local development only).
- Ensures `key.properties` and `*.jks` files are permanently excluded from git.

---

## 1. Generate the keystore (run once)

```bash
keytool -genkey -v \
  -keystore ~/sacdia-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sacdia
```

You will be prompted for:
- Distinguished name (CN, OU, O, L, ST, C) — use your organization details.
- A **store password** (protects the .jks file itself).
- A **key password** (protects the private key entry inside the file).

Use strong, unique passwords. Store them in your password manager (see section 3).

---

## 2. Create `android/key.properties`

Copy the template and fill in real values:

```bash
cp android/key.properties.template android/key.properties
```

Edit `android/key.properties`:

```
storeFile=../sacdia-release-key.jks
storePassword=<your store password>
keyAlias=sacdia
keyPassword=<your key password>
```

The `storeFile` path is relative to the `android/` directory (Gradle rootProject). If
you place the `.jks` file in a different location, adjust the path accordingly.

---

## 3. Store passwords securely

Save both passwords in **1Password** (or equivalent) under a shared vault accessible to
all release engineers. Suggested entry name: `SACDIA Android Keystore`.

Fields to save:
- Store password
- Key password
- Key alias (`sacdia`)
- Location of the `.jks` backup (see section 5)

---

## 4. Verify signing

After placing `key.properties` and building a release:

```bash
# Build a release APK
flutter build apk --release

# Verify the APK is signed with your release key (not debug)
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk

# Or use Gradle's signing report
./gradlew signingReport
```

The certificate fingerprint shown must match the one registered in Play Console
(Project Settings > App integrity > App signing key certificate).

---

## 5. Backup strategy (CRITICAL)

If you lose the keystore, you CANNOT publish updates to the same Play Store listing.
There is no recovery path — Google will not re-sign on your behalf.

**Mandatory backups:**
1. Upload `sacdia-release-key.jks` to a private, access-controlled location
   (e.g., 1Password document, encrypted S3 bucket, or company secrets manager).
2. Store passwords alongside the file (1Password recommended — see section 3).
3. Verify the backup is restorable at least once before the first Play Store submission.

Never store the `.jks` file in the git repository or any public location.

---

## 6. Play Console upload key

Google Play uses **Play App Signing** by default. Your keystore is the **upload key**
(used to authenticate uploads), and Google manages the final **app signing key**
(used to sign APKs delivered to users).

Steps:
1. In Play Console, go to **Release > Setup > App integrity**.
2. Follow the prompts to register your upload key certificate.
3. To export your upload key certificate (DER format):
   ```bash
   keytool -export -rfc \
     -keystore ~/sacdia-release-key.jks \
     -alias sacdia \
     -file sacdia-upload-cert.pem
   ```
4. Upload `sacdia-upload-cert.pem` to Play Console.

---

## 7. CI/CD integration

For automated builds (Fastlane, Codemagic, GitHub Actions), store secrets as
environment variables and generate `key.properties` at build time:

```bash
# Example CI step (bash)
cat > android/key.properties <<EOF
storeFile=${KEYSTORE_PATH}
storePassword=${KEYSTORE_PASSWORD}
keyAlias=${KEY_ALIAS}
keyPassword=${KEY_PASSWORD}
EOF
```

Decode the base64-encoded `.jks` from a CI secret:

```bash
echo "$KEYSTORE_BASE64" | base64 --decode > ~/sacdia-release-key.jks
```

---

## 8. Recommended next steps

- **Obfuscation**: Run release builds with:
  ```bash
  flutter build appbundle \
    --obfuscate \
    --split-debug-info=build/app/outputs/symbols
  ```
  Upload the symbols to Firebase Crashlytics or Sentry for de-obfuscated crash reports.
  The necessary comments are already in `android/app/build.gradle`.

- **ProGuard/R8**: Uncomment `minifyEnabled` and `shrinkResources` in `build.gradle`
  once ProGuard rules are validated to not break the app.

- **Key rotation policy**: Plan for upload key rotation every 2-3 years or immediately
  upon any suspected compromise. Contact Google Play support for rotation procedures.
