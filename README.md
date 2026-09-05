# PDF Maker

A feature-rich Flutter PDF toolkit. Scan documents, create PDFs from images, merge, split, compress, secure with passwords/watermarks, reorder and rotate pages, edit metadata, annotate, and export/share — all on-device.

## Features

- **Scan** documents with native edge detection (`cunning_document_scanner`) or import from gallery
- **Create PDF** from multiple images
- **Merge / Split / Compress** PDFs
- **Security** — AES-256 encryption, password unlock, text/image watermarks
- **Organize** — reorder pages (drag & drop), rotate pages, edit metadata
- **Viewer** — pinch-to-zoom with draw, sign & text annotation overlay
- **Export & Share** — PDF, JPG, PNG, TXT/DOC
- **Cloud (optional)** — Cloud Firestore keeps your favorites and share history in sync

## Tech Stack

| Area | Package |
| --- | --- |
| PDF editing engine | `syncfusion_flutter_pdf` |
| PDF generation | `pdf` |
| PDF rendering | `pdfx` |
| Image handling | `image` |
| Document scanning | `cunning_document_scanner` |
| Picking files/images | `file_picker`, `image_picker` |
| Cloud sync (optional) | `firebase_core`, `cloud_firestore` |

## Getting Started

```bash
flutter pub get
flutter run
```

### Firebase setup (optional)

The app works fully offline without Firebase. To enable cloud sync of Favorites/Shared:

1. Create a Firebase project and register an **Android app** with package name `com.pdfmaker.app`
2. Download `google-services.json` and place it in `android/app/`
3. Create a **Cloud Firestore** database in the Firebase console
4. Regenerate the config:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

> **Do not commit `google-services.json`, `GoogleService-Info.plist`, or `lib/firebase_options.dart`** — they are ignored via `.gitignore` and must be added locally.

## App ID

- Android: `com.pdfmaker.app`
- iOS: `com.pdfmaker.app`

## Structure

```
lib/
├── main.dart                 # App entry + Firebase init
├── theme/                    # Dark/light themes + colors
├── utils/file_helper.dart    # File system, permissions, share helpers
├── services/                 # Firebase service layer (favorites, share history)
├── widgets/                  # Reusable UI widgets
└── screens/                  # Feature screens
```