# 🧹 CleanUp: Modern Privacy-First iOS Storage Utility App

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

**CleanUp** is an advanced, privacy-focused iOS application designed to help users analyze, optimize, and reclaim device storage space. Built natively with **SwiftUI**, **PhotoKit**, **Contacts Framework**, **AVFoundation**, and **WidgetKit**, CleanUp provides an intuitive Liquid Glass UI for managing photos, videos, contacts, and encrypted files—100% on-device with zero cloud dependencies.

---

## 🌟 Key Features

### 🖼️ Smart Media Cleanup
- **Perceptual Image Similarity Clustering**: Uses 64-bit Difference Hashing (`dHash`), 1x1 RGB average color fingerprinting, bitwise Hamming distance ($\le 12$ bits), and Disjoint-Set Union (DSU) graph partitioning to group visually similar photos without false positives or transitive bleeding.
- **⭐ Automated "Best Shot" Identification**: Automatically highlights the highest-resolution and sharpest photo within each similarity cluster.
- **📱 Screenshot Detector**: Identifies and organizes system screenshots for instant batch cleanup.
- **👁️ Blurry Photo Analyzer**: Evaluates image contrast and sharpness using Accelerate/CoreImage Laplacian variance algorithms.
- **🎥 Large Video Finder**: Displays large videos sorted by disk size with built-in video player previews.

### 👥 Contact Deduplication & Safe Merging
- **Smart Contact Matching**: Scans `CNContactStore` for identical structured names or normalized phone numbers.
- **Non-Destructive Merging**: Consolidates multiple duplicate entries into a single master contact while preserving all unique phone numbers, email addresses, and notes.

### 🔒 Encrypted Private Vault
- **AES-Encrypted Storage**: Hides sensitive photos from the public iOS Photo Library inside an isolated application sandbox.
- **Biometric Protection**: Secured with LocalAuthentication (Face ID / Touch ID / Device Passcode).

### 🎥 Video Compressor
- **High-Efficiency Re-Encoding**: Compresses high-bitrate 4K and 1080p videos using `AVAssetExportSession`, reducing file sizes by up to 70% with negligible quality loss.

### 📲 Home Screen Widget
- **WidgetKit Integration**: Displays dynamic system storage usage percentages, free space, and used space gauges right on the iOS Home Screen.

### 🎨 Liquid Glass UI & Auto-Hiding Tab Bar
- Modern frosted glass aesthetic built with `.ultraThinMaterial` and dynamic liquid gradients.
- **Scroll-Aware Navigation**: The bottom navigation bar automatically slides out of view when scrolling down through media grids and smoothly reappears when scrolling up.

---

## 🏗️ Project Architecture & Structure

CleanUp follows the **MVVM (Model-View-ViewModel)** reactive design pattern:

```
Cleanup/
├── Cleanup/
│   ├── MyApp.swift                       # App Entry Point & Window Setup
│   ├── ContentView.swift                 # Root Container & Navigation Controller
│   ├── Models/
│   │   └── StorageModels.swift           # Data Structures (PhotoGroup, PhotoAssetItem, etc.)
│   ├── Services/
│   │   ├── StorageManager.swift          # Hardware System Storage Metrics API
│   │   ├── PhotoLibraryScanner.swift     # Perceptual Hashing, Blur & Media Scanner Engine
│   │   ├── MediaCleaner.swift            # Safe PhotoKit Asset Deletion Manager
│   │   ├── ContactScanner.swift          # CNContactStore Fetching & Merging Engine
│   │   ├── VaultManager.swift            # AES Private Vault Import/Export & Encryption
│   │   ├── VideoCompressorService.swift  # AVFoundation Video Compression Engine
│   │   └── PermissionManager.swift       # Photos & Contacts Authorization State Manager
│   └── Views/
│       ├── DashboardView.swift           # Main Storage Ring Gauge & Category Quick-Links
│       ├── MediaSessionView.swift        # Media Landing Stack & Category Router
│       ├── SimilarPhotosView.swift       # Similar Photos Cluster Grid & Best Shot Display
│       ├── AllPhotosView.swift           # All Photos Grid View
│       ├── ScreenshotsView.swift         # Screenshot Management View
│       ├── BlurryPhotosView.swift        # Blurry Photos Detection View
│       ├── LargeVideosView.swift         # Video List & Inline Player Preview
│       ├── ContactsSessionView.swift     # Duplicate Contacts Scanner & Merge View
│       ├── DuplicateContactsView.swift   # Detailed Contact Merge Review Screen
│       ├── PrivateVaultView.swift        # Biometrically Locked Encrypted Vault View
│       ├── VideoCompressorView.swift     # Video Compression Dashboard
│       ├── SwipeCleanerView.swift        # Tinder-Style Swipe Photo Review Mode
│       ├── ReviewDeleteView.swift        # Final Confirmation Modal Before Deletion
│       ├── CompletionView.swift          # Clean Summary & Storage Reclaimed Screen
│       └── Components/
│           ├── GlassyTabBar.swift        # Dynamic Floating Liquid Glass Tab Bar
│           ├── ImagePreviewModal.swift   # Full-Screen Gallery & Vault/Delete Overlay
│           ├── UIComponents.swift        # Storage Ring Gauge, Cards & Scroll Tracking
│           └── StorageWidget.swift       # App Widget Component Shared UI
└── StorageWidget/                        # iOS WidgetKit Extension Target
    ├── StorageWidget.swift               # Widget Configuration & Views
    ├── StorageWidgetBundle.swift         # Widget Entry Point
    └── AppIntent.swift                   # Dynamic Widget Intents
```

---

## 🧠 Deep-Dive: Image Similarity Algorithm

Perceptual similarity detection is performed entirely on-device through a 4-stage pipeline:

1. **64-bit Difference Hash (`dHash`)**: Downsamples images to $9 \times 8$ grayscale matrices and evaluates adjacent pixel intensity gradients:
   $$\text{bit}_i = \begin{cases} 1 & \text{if } P_{x, y} > P_{x+1, y} \\ 0 & \text{otherwise} \end{cases}$$
2. **1x1 Color Vector Guardrail**: Extracts average RGB values to prevent structural matches between visually distinct colors (e.g., sky vs. grass).
3. **Bitwise Hamming Distance**: Computes structural similarity via CPU hardware bitwise operations:
   $$\text{Hamming Distance} = \text{popcount}(\text{hash}_1 \oplus \text{hash}_2)$$
   A threshold of $\le 12$ bits represents high perceptual similarity.
4. **Disjoint-Set Union (DSU) Graph Partitioning**: Clusters similar photos into isolated groups in $\mathcal{O}(N \cdot \alpha(N))$ time, preventing transitive cluster bleeding.

---

## 🛠️ Requirements & Setup

- **iOS**: 16.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Device Support**: iPhone & iPad

### 🚀 Building and Running
1. Clone or open the project folder in Xcode:
   ```bash
   open Cleanup.xcodeproj
   ```
2. Select the `Cleanup` scheme.
3. Choose your target simulator or connected iOS device.
4. Press `⌘R` to build and run the app.

---

## 🔒 Privacy & Security

- **100% On-Device Processing**: All perceptual hashing, blur detection, contact merging, and encryption operations run locally on the device.
- **Zero Data Collection**: No user metrics, photos, media, or contact data leave the device.
- **Non-Destructive Deletion**: Deletions are sent through system `PHPhotoLibrary` confirmation dialogs and move assets to the iOS **Recently Deleted** folder for 30 days before permanent deletion.

