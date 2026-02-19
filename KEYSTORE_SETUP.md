# Keystore Setup Instructions

## ✅ Keystore Created Successfully!

A release keystore has been generated at `android/app/keystore.jks` with the following credentials:

### Keystore Credentials

- **Keystore Password:** `android123`
- **Key Alias:** `release`
- **Key Password:** `android123`

> ⚠️ **IMPORTANT:** These credentials are for development/testing. For production apps, use strong passwords and keep them secure!

## Setting Up GitHub Secrets

To enable automated deployment, you need to add the following secrets to your GitHub repository:

### 1. Navigate to GitHub Secrets

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### 2. Add the Following Secrets

#### KEYSTORE
```bash
# Copy the content of keystore_base64.txt file
# This file contains the base64-encoded keystore
cat keystore_base64.txt
```
- **Name:** `KEYSTORE`
- **Value:** Paste the entire base64 string from `keystore_base64.txt`

#### KEYSTORE_PASSWORD
- **Name:** `KEYSTORE_PASSWORD`
- **Value:** `android123`

#### KEYSTORE_ENTRY_ALIAS
- **Name:** `KEYSTORE_ENTRY_ALIAS`
- **Value:** `release`

#### KEYSTORE_ENTRY_PASSWORD
- **Name:** `KEYSTORE_ENTRY_PASSWORD`
- **Value:** `android123`

## Quick Copy-Paste Command

To easily copy the base64 keystore to your clipboard (on Linux):

```bash
cat keystore_base64.txt | xclip -selection clipboard
```

Or simply open the file and copy its contents:

```bash
cat keystore_base64.txt
```

## Security Notes

1. ✅ The keystore files are already added to `.gitignore` and will NOT be committed
2. ✅ Never share or commit the keystore or base64 file
3. ✅ Delete `keystore_base64.txt` after adding it to GitHub secrets
4. 🔒 For production apps, consider using Android App Signing by Google Play

## Testing the Setup

Once you've added all secrets to GitHub:

1. Commit and push your changes
2. The GitHub Actions workflow will automatically:
   - Build signed APK
   - Build signed AAB (App Bundle)
   - Create a GitHub release with both files attached

## File Locations

- **Keystore:** `android/app/keystore.jks` (not committed)
- **Base64 encoded:** `keystore_base64.txt` (temporary, delete after use)
- **Build output APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **Build output AAB:** `build/app/outputs/bundle/release/app-release.aab`

## Regenerating the Keystore (if needed)

If you need to regenerate the keystore:

```bash
cd android/app
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

Then re-encode it:

```bash
base64 -w 0 android/app/keystore.jks > keystore_base64.txt
```

---

**Ready to deploy!** 🚀 After setting up the GitHub secrets, your app will be automatically built and released on every push to `main`.
