# Flip Aesthetic Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the entire Lipster app around the Flip (Cover Flow) aesthetic — custom bottom bar, 3-section navigation, carousel-driven Library with category switching, Flip-treated Now Playing, and unified PS3 visual language.

**Architecture:** Rebuild the app shell (custom bottom bar replacing TabView, 3-section navigation) and unify the visual language. Generalize `FlipView` to accept any entity via `FlipItem`. Extract the PS3 ambient background into a reusable component. Preserve all internals: carousel engine, playback, database, models.

**Tech Stack:** SwiftUI, UIKit (FlipView), AVFoundation, MediaPlayer, SQLite3, iOS 26

**Spec:** `docs/superpowers/specs/2026-04-01-flip-aesthetic-redesign.md`

---

## File Map

### New Files

| File | Purpose |
|------|---------|
| `Views/Components/AmbientBackgroundView.swift` | Reusable PS3 gradient background |
| `Views/BottomBarView.swift` | Custom bottom bar + mini player connected unit |
| `Views/Discover/DiscoverView.swift` | Placeholder for future Discover tab |

### Rewritten Files

| File | Scope |
|------|-------|
| `App/LipsterApp.swift` | Hidden TabView + custom BottomBarView, gear icon, sheet presentations |
| `Views/NowPlaying/MiniPlayerView.swift` | Simplified for integration into BottomBarView (no background, no swipe) |
| `Views/Library/LibraryView.swift` | Category bar + carousel host for Albums/Artists/Playlists |
| `Views/NowPlaying/NowPlayingView.swift` | Flip treatment — reflection, PS3 background, updated layout |

### Modified Files

| File | Change |
|------|--------|
| `Views/Components/FlipView.swift` | Accept `[FlipItem]` instead of `[Album]`, callback returns index |
| `Models/Playlist.swift` | Add `coverArtFilePath` computed property |
| `Views/Search/SearchView.swift` | Restyle with glassy rows + ambient background |
| `Views/Settings/SettingsView.swift` | Restyle with glassy lists + ambient background |

### Unchanged

FlipView UIKit engine internals (transform math, scrolling, snapping), AppState, AudioPlayer, DatabaseManager, NowPlayingManager, LiveActivityManager, ImageCache, ColorExtractor, HapticManager, Song/Album/Folder models, QueueView.

---

### Task 1: Foundation — Reusable Components + FlipItem Generalization

**Files:**
- Create: `Lipster/Views/Components/AmbientBackgroundView.swift`
- Modify: `Lipster/Views/Components/FlipView.swift`
- Modify: `Lipster/Views/Flip/FlipBrowserView.swift`
- Modify: `Lipster/Models/Playlist.swift`

- [ ] **Step 1: Create AmbientBackgroundView**

Extract the PS3 background pattern from `FlipBrowserView.swift:212-249` into a reusable component.

Create `Lipster/Views/Components/AmbientBackgroundView.swift`:

```swift
import SwiftUI

struct AmbientBackgroundView: View {
    let colors: AlbumColors
    let image: UIImage?
    var overlayOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .opacity(0.2)
                    .scaleEffect(1.5)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    colors.primary.opacity(0.25),
                    .clear,
                    colors.secondary.opacity(0.15),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [colors.primary.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 10,
                endRadius: 350
            )

            if overlayOpacity > 0 {
                Color.black.opacity(overlayOpacity)
            }
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 2: Add FlipItem struct to FlipView.swift**

Add this struct at the top of `Lipster/Views/Components/FlipView.swift`, before the `FlipView` struct:

```swift
struct FlipItem: Identifiable, Equatable {
    let id: String
    let coverArtFilePath: String?
}
```

- [ ] **Step 3: Update FlipView SwiftUI bridge to use FlipItem**

In `FlipView.swift`, replace the `FlipView` struct (lines 6-50) with:

```swift
struct FlipView: UIViewRepresentable {
    let items: [FlipItem]
    var centeredIndex: Binding<Int>?
    let onItemTapped: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> FlipUIView {
        let view = FlipUIView()
        view.delegate = context.coordinator
        view.setItems(items)
        return view
    }

    func updateUIView(_ uiView: FlipUIView, context: Context) {
        context.coordinator.parent = self
        if uiView.items != items {
            uiView.setItems(items)
        }
        if let index = centeredIndex?.wrappedValue, index != uiView.currentIndex,
           items.indices.contains(index) {
            uiView.scrollToIndex(index, animated: true)
        }
    }

    class Coordinator: FlipUIViewDelegate {
        var parent: FlipView

        init(parent: FlipView) {
            self.parent = parent
        }

        func flipDidScroll(toIndex index: Int) {
            parent.centeredIndex?.wrappedValue = index
        }

        func flipDidTapCenter(atIndex index: Int) {
            guard parent.items.indices.contains(index) else { return }
            parent.onItemTapped(index)
        }
    }
}
```

- [ ] **Step 4: Update FlipUIView to use FlipItem**

In `FlipUIView` (same file), make these changes:

1. Change the stored property (line ~63):
```swift
// OLD: private(set) var albums: [Album] = []
private(set) var items: [FlipItem] = []
```

2. Rename `setAlbums` to `setItems` (line ~123):
```swift
func setItems(_ items: [FlipItem]) {
    self.items = items
    coverViews.forEach { $0.removeFromSuperview() }
    coverViews.removeAll()

    for (index, item) in items.enumerated() {
        let itemView = CoverItemView(size: coverSize)
        scrollView.addSubview(itemView)
        coverViews.append(itemView)
        loadImage(for: item, index: index)
    }

    updateContentSize()
    setNeedsLayout()
}
```

3. Update `loadImage` (line ~139):
```swift
private func loadImage(for item: FlipItem, index: Int) {
    guard let path = item.coverArtFilePath else { return }
    let scale = window?.screen.scale ?? 3.0
    let targetPixels = coverSize * scale

    DispatchQueue.global(qos: .userInitiated).async {
        let url = URL(fileURLWithPath: path)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
        let image = UIImage(cgImage: cgImage)

        DispatchQueue.main.async { [weak self] in
            guard let self, index < self.coverViews.count else { return }
            self.coverViews[index].setImage(image)
        }
    }
}
```

4. Replace all remaining `albums` references with `items` throughout the class:
   - `layoutSubviews`: `!albums.isEmpty` → `!items.isEmpty`
   - `updateContentSize`: `albums.count` → `items.count`
   - `updateTransforms`: loop guard and `coverViews.enumerated()`  — no change needed, it already iterates `coverViews`
   - `snapToNearest`: `albums.indices` → `items.indices`
   - `handleTap`: `albums.indices` → `items.indices`
   - `scrollViewDidScroll`: `albums.indices` → `items.indices`

5. Update the Preview at the bottom:
```swift
#Preview {
    FlipView(items: []) { _ in }
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Update FlipBrowserView to use new FlipView API**

In `FlipBrowserView.swift`, update the `FlipView` usage (lines 29-34):

```swift
// Replace the FlipView call:
FlipView(
    items: albums.map { FlipItem(id: "album-\($0.id)", coverArtFilePath: $0.coverArtFilePath) },
    centeredIndex: $centeredAlbumIndex
) { index in
    guard albums.indices.contains(index) else { return }
    selectedAlbum = albums[index]
}
.frame(height: 250)
.clipped()
```

Replace the `ps3Background` computed property (lines 212-249) with:

```swift
private var ps3Background: some View {
    AmbientBackgroundView(
        colors: albumColors,
        image: centeredAlbum?.coverArtImage
    )
    .id(centeredAlbumIndex)
    .transition(.opacity)
    .animation(.easeInOut(duration: 0.5), value: centeredAlbumIndex)
}
```

- [ ] **Step 6: Add coverArtFilePath to Playlist model**

In `Lipster/Models/Playlist.swift`, add after the `folderId` property:

```swift
import UIKit

struct Playlist: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let name: String
    let description: String?
    let coverPath: String?
    let folderId: Int64?

    var coverArtFilePath: String? {
        guard let coverPath, !coverPath.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = docs.appendingPathComponent(coverPath)
        if FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        return nil
    }

    var coverArtImage: UIImage? {
        guard let path = coverArtFilePath else { return nil }
        return ImageCache.shared.image(forPath: path)
    }
}
```

- [ ] **Step 7: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. FlipBrowserView should look and behave identically — only the internal types changed.

- [ ] **Step 8: Commit**

```bash
git add Lipster/Views/Components/AmbientBackgroundView.swift \
       Lipster/Views/Components/FlipView.swift \
       Lipster/Views/Flip/FlipBrowserView.swift \
       Lipster/Models/Playlist.swift
git commit -m "Extract AmbientBackgroundView, generalize FlipView to FlipItem"
```

---

### Task 2: Create Bottom Bar + Redesign Mini Player

**Files:**
- Create: `Lipster/Views/BottomBarView.swift`
- Rewrite: `Lipster/Views/NowPlaying/MiniPlayerView.swift`

- [ ] **Step 1: Create BottomBarView**

Create `Lipster/Views/BottomBarView.swift`:

```swift
import SwiftUI

enum AppSection: Hashable {
    case discover, library, search
}

struct BottomBarView: View {
    @Binding var selectedSection: AppSection
    @Binding var showNowPlaying: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentSong != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
            }

            HStack {
                navButton(.discover, icon: "sparkles", label: "Discover")
                navButton(.library, icon: "music.note.house", label: "Library")
                navButton(.search, icon: "magnifyingglass", label: "Search")
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .background(.ultraThinMaterial)
    }

    private func navButton(_ section: AppSection, icon: String, label: String) -> some View {
        Button {
            Haptics.impact(.light)
            selectedSection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Rewrite MiniPlayerView**

Simplified — no own background (BottomBarView provides it), no swipe gesture (spec removes it).

Rewrite `Lipster/Views/NowPlaying/MiniPlayerView.swift`:

```swift
import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @Binding var showNowPlaying: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar along top edge
            GeometryReader { geo in
                Rectangle()
                    .fill(appState.albumColors.primary)
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 0.5), value: progress)
            }
            .frame(height: 2)

            HStack(spacing: 12) {
                // Album art
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentSong?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(appState.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Play/Pause
                Button {
                    Haptics.impact(.light)
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Skip next
                Button {
                    Haptics.impact(.light)
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
    }

    private var progress: CGFloat {
        guard appState.duration > 0 else { return 0 }
        return CGFloat(appState.currentTime / appState.duration)
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. The new views aren't wired in yet, so the app still uses the old TabView.

- [ ] **Step 4: Commit**

```bash
git add Lipster/Views/BottomBarView.swift Lipster/Views/NowPlaying/MiniPlayerView.swift
git commit -m "Create BottomBarView and redesign MiniPlayerView as connected unit"
```

---

### Task 3: Rewrite App Shell + Create DiscoverView Stub

**Files:**
- Create: `Lipster/Views/Discover/DiscoverView.swift`
- Rewrite: `Lipster/App/LipsterApp.swift`

- [ ] **Step 1: Create DiscoverView stub**

Create directory and file `Lipster/Views/Discover/DiscoverView.swift`:

```swift
import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            AmbientBackgroundView(
                colors: appState.albumColors,
                image: appState.currentSong?.coverArtImage
            )

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Discover")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
```

- [ ] **Step 2: Rewrite LipsterApp.swift**

Replace the entire contents of `Lipster/App/LipsterApp.swift`:

```swift
import SwiftUI

@main
struct LipsterApp: App {
    @State private var appState = AppState()
    @State private var selectedSection: AppSection = .library
    @State private var showNowPlaying = false
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedSection) {
                DiscoverView()
                    .tag(AppSection.discover)

                LibraryView()
                    .tag(AppSection.library)

                SearchView()
                    .tag(AppSection.search)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                BottomBarView(
                    selectedSection: $selectedSection,
                    showNowPlaying: $showNowPlaying
                )
            }
            .overlay(alignment: .topTrailing) {
                gearButton
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(appState)
                    .interactiveDismissDisabled(false)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .environment(appState)
                .preferredColorScheme(.dark)
            }
        }
    }

    private var gearButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(.trailing, 16)
        .padding(.top, 4)
    }
}
```

Note: `LibraryView` still uses the old 5-category XMB selector at this point. It will be rewritten in Task 4. `SearchView` and `SettingsView` are unchanged — they still have their own `NavigationStack` internally.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. The app now has 3 sections (Discover/Library/Search) with a custom bottom bar. The Flip browser tab is gone — its carousel will be absorbed into Library in Task 4.

- [ ] **Step 4: Commit**

```bash
git add Lipster/Views/Discover/DiscoverView.swift Lipster/App/LipsterApp.swift
git commit -m "Rewrite app shell: custom bottom bar, 3-section nav, gear icon for settings"
```

---

### Task 4: Rewrite Library View — Albums Mode with Carousel

**Files:**
- Rewrite: `Lipster/Views/Library/LibraryView.swift`

This is the centerpiece. LibraryView now owns the carousel and category bar. Start with Albums mode only (Artists and Playlists modes are added in Tasks 5 and 6).

- [ ] **Step 1: Rewrite LibraryView.swift**

Replace the entire contents of `Lipster/Views/Library/LibraryView.swift`:

```swift
import SwiftUI

enum LibraryCategory: String, CaseIterable {
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"

    var icon: String {
        switch self {
        case .albums: "square.stack"
        case .artists: "person.2"
        case .playlists: "music.note.list"
        }
    }
}

struct ArtistItem: Equatable {
    let name: String
    let coverArtFilePath: String?
}

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var namespace

    // Category & carousel state
    @State private var selectedCategory: LibraryCategory = .albums
    @State private var centeredIndex: Int = 0

    // Data per category
    @State private var albums: [Album] = []
    @State private var artistItems: [ArtistItem] = []
    @State private var playlists: [Playlist] = []

    // Derived from centered item
    @State private var albumColors: AlbumColors = .placeholder
    @State private var tracks: [Song] = []
    @State private var artistAlbumGroups: [(album: Album, songs: [Song])] = []

    // Navigation
    @State private var selectedAlbum: Album?

    // MARK: - Carousel Items

    private var flipItems: [FlipItem] {
        switch selectedCategory {
        case .albums:
            albums.map { FlipItem(id: "album-\($0.id)", coverArtFilePath: $0.coverArtFilePath) }
        case .artists:
            artistItems.map { FlipItem(id: "artist-\($0.name)", coverArtFilePath: $0.coverArtFilePath) }
        case .playlists:
            playlists.map { FlipItem(id: "playlist-\($0.id)", coverArtFilePath: $0.coverArtFilePath) }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if flipItems.isEmpty {
                    ContentUnavailableView(
                        "No \(selectedCategory.rawValue)",
                        systemImage: selectedCategory.icon,
                        description: Text("\(selectedCategory.rawValue) will appear once ripper.db is loaded.")
                    )
                } else {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 12)

                        categoryBar
                            .padding(.bottom, 8)

                        FlipView(
                            items: flipItems,
                            centeredIndex: $centeredIndex
                        ) { index in
                            handleItemTap(at: index)
                        }
                        .frame(height: 250)
                        .clipped()
                        .id(selectedCategory)

                        centeredItemInfo
                            .padding(.top, -8)
                            .padding(.bottom, 8)

                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(height: 0.5)

                        playShuffleRow

                        contentBelowCarousel
                    }
                }
            }
            .background {
                AmbientBackgroundView(colors: albumColors, image: centeredItemImage)
                    .animation(.easeInOut(duration: 0.5), value: centeredIndex)
                    .animation(.easeInOut(duration: 0.5), value: selectedCategory)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { loadAllData() }
            .onChange(of: centeredIndex) { _, _ in updateCenteredState() }
            .onChange(of: selectedCategory) { _, _ in
                centeredIndex = 0
                updateCenteredState()
            }
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LibraryCategory.allCases, id: \.self) { category in
                        categoryButton(category)
                            .id(category)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selectedCategory) { _, newCategory in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(newCategory, anchor: .center)
                }
            }
        }
    }

    private func categoryButton(_ category: LibraryCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, isSelected ? 14 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .matchedGeometryEffect(id: "category_indicator", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Centered Item Info

    @ViewBuilder
    private var centeredItemInfo: some View {
        switch selectedCategory {
        case .albums:
            if let album = centeredAlbum {
                VStack(spacing: 3) {
                    Text(album.name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                    Text(album.artist)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    if let year = album.year {
                        Text(String(year))
                            .font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("album-\(centeredIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: centeredIndex)
            }
        case .artists:
            if artistItems.indices.contains(centeredIndex) {
                VStack(spacing: 3) {
                    Text(artistItems[centeredIndex].name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("artist-\(centeredIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: centeredIndex)
            }
        case .playlists:
            if playlists.indices.contains(centeredIndex) {
                let playlist = playlists[centeredIndex]
                VStack(spacing: 3) {
                    Text(playlist.name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                    if let desc = playlist.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("playlist-\(centeredIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: centeredIndex)
            }
        }
    }

    // MARK: - Play / Shuffle Row

    @ViewBuilder
    private var playShuffleRow: some View {
        let currentTracks = allCurrentTracks
        if !currentTracks.isEmpty {
            HStack(spacing: 20) {
                Button {
                    if let first = currentTracks.first {
                        appState.play(song: first, queue: currentTracks)
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    if let random = currentTracks.randomElement() {
                        appState.playShuffled(song: random, queue: currentTracks)
                    }
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content Below Carousel

    @ViewBuilder
    private var contentBelowCarousel: some View {
        switch selectedCategory {
        case .albums:
            albumTrackList
        case .artists:
            artistGroupedList
        case .playlists:
            playlistTrackList
        }
    }

    // MARK: - Album Track List

    private var albumTrackList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { song in
                    trackRow(song: song, queue: tracks)

                    if song.id != tracks.last?.id {
                        Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                    }
                }
            }
        }
    }

    // MARK: - Artist Grouped List (placeholder — Task 5 fills this in)

    private var artistGroupedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(artistAlbumGroups, id: \.album.id) { group in
                    // Album header
                    HStack(spacing: 10) {
                        if let image = group.album.coverArtImage {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.album.name)
                                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                            if let year = group.album.year {
                                Text(String(year))
                                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.04))

                    // Tracks under this album
                    ForEach(group.songs) { song in
                        trackRow(song: song, queue: allCurrentTracks)

                        if song.id != group.songs.last?.id {
                            Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playlist Track List

    private var playlistTrackList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { song in
                    trackRow(song: song, queue: tracks)

                    if song.id != tracks.last?.id {
                        Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                    }
                }
            }
        }
    }

    // MARK: - Shared Track Row

    private func trackRow(song: Song, queue: [Song]) -> some View {
        Button {
            appState.play(song: song, queue: queue)
        } label: {
            HStack(spacing: 10) {
                if let num = song.trackNumber {
                    Text("\(num)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, alignment: .trailing)
                        .monospacedDigit()
                }

                Text(song.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(song.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var centeredAlbum: Album? {
        albums.indices.contains(centeredIndex) ? albums[centeredIndex] : nil
    }

    private var centeredItemImage: UIImage? {
        switch selectedCategory {
        case .albums:
            centeredAlbum?.coverArtImage
        case .artists:
            guard artistItems.indices.contains(centeredIndex),
                  let path = artistItems[centeredIndex].coverArtFilePath else { return nil }
            return ImageCache.shared.image(forPath: path)
        case .playlists:
            guard playlists.indices.contains(centeredIndex) else { return nil }
            return playlists[centeredIndex].coverArtImage
        }
    }

    /// All tracks currently visible below the carousel (used for Play/Shuffle).
    private var allCurrentTracks: [Song] {
        switch selectedCategory {
        case .albums, .playlists:
            return tracks
        case .artists:
            return artistAlbumGroups.flatMap(\.songs)
        }
    }

    // MARK: - Data Loading

    private func loadAllData() {
        albums = appState.databaseManager.loadAlbums()

        // Build artist items from loaded albums (first album cover per artist)
        var seen: Set<String> = []
        var artists: [ArtistItem] = []
        for album in albums {
            if !seen.contains(album.artist) {
                seen.insert(album.artist)
                artists.append(ArtistItem(name: album.artist, coverArtFilePath: album.coverArtFilePath))
            }
        }
        artistItems = artists

        playlists = appState.databaseManager.loadPlaylists()

        updateCenteredState()
    }

    private func updateCenteredState() {
        switch selectedCategory {
        case .albums:
            guard let album = centeredAlbum else { tracks = []; return }
            tracks = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            updateColors(image: album.coverArtImage, cacheKey: album.spotifyId ?? "album-\(album.id)")

        case .artists:
            guard artistItems.indices.contains(centeredIndex) else { artistAlbumGroups = []; return }
            let artistName = artistItems[centeredIndex].name
            let artistAlbums = albums.filter { $0.artist == artistName }
            artistAlbumGroups = artistAlbums.map { album in
                let songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
                return (album: album, songs: songs)
            }
            if let firstAlbum = artistAlbums.first {
                updateColors(image: firstAlbum.coverArtImage, cacheKey: firstAlbum.spotifyId ?? "album-\(firstAlbum.id)")
            }

        case .playlists:
            guard playlists.indices.contains(centeredIndex) else { tracks = []; return }
            let playlist = playlists[centeredIndex]
            tracks = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
            if let image = playlist.coverArtImage {
                updateColors(image: image, cacheKey: "playlist-\(playlist.id)")
            } else {
                albumColors = .placeholder
            }
        }
    }

    private func updateColors(image: UIImage?, cacheKey: String) {
        guard let image else { albumColors = .placeholder; return }
        albumColors = ColorExtractor.shared.extract(from: image, cacheKey: cacheKey)
    }

    private func handleItemTap(at index: Int) {
        switch selectedCategory {
        case .albums:
            guard albums.indices.contains(index) else { return }
            selectedAlbum = albums[index]
        case .artists:
            // Tapping an artist in the carousel does nothing extra — content shows below
            break
        case .playlists:
            // Tapping a playlist in the carousel does nothing extra — tracks show below
            break
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. Library now shows the carousel with category bar. Albums mode should work identically to the old FlipBrowserView. Artists and Playlists modes should work — carousel populates and content shows below.

Note: `SongRow` and `SongContextMenu` (defined in `SongsView.swift`) are still used by `SearchView`, `PlaylistDetailView`, and `ArtistDetailView`. Those files still exist and compile fine — we're not removing them.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/Library/LibraryView.swift
git commit -m "Rewrite LibraryView: carousel with Albums/Artists/Playlists category bar"
```

---

### Task 5: Redesign Now Playing with Flip Treatment

**Files:**
- Rewrite: `Lipster/Views/NowPlaying/NowPlayingView.swift`

- [ ] **Step 1: Rewrite NowPlayingView.swift**

Replace the entire contents of `Lipster/Views/NowPlaying/NowPlayingView.swift`:

```swift
import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var showQueue: Bool = false
    @State private var artOffset: CGFloat = 0

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            // PS3 ambient background with darker overlay for contrast
            AmbientBackgroundView(colors: colors, image: appState.currentSong?.coverArtImage, overlayOpacity: 0.3)
                .animation(.easeInOut(duration: 1.0), value: colors)

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                // Album art with reflection
                albumArtWithReflection
                    .padding(.horizontal, 28)

                Spacer().frame(height: 28)

                songInfo

                Spacer().frame(height: 24)

                progressScrubber
                    .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                transportControls

                VolumeSliderView()
                    .frame(height: 34)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer().frame(height: 16)

                bottomControls

                Spacer().frame(height: 20)
            }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = appState.currentTime
            artScale = appState.isPlaying ? 1.0 : 0.85
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging { sliderValue = newValue }
        }
        .onChange(of: appState.currentSong) { _, _ in
            sliderValue = 0
        }
        .onChange(of: appState.isPlaying) { _, playing in
            withAnimation(.easeInOut(duration: 0.4)) {
                artScale = playing ? 1.0 : 0.85
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
        }
    }

    // MARK: - Album Art with Reflection

    private var albumArtWithReflection: some View {
        VStack(spacing: 0) {
            // Main album art
            Group {
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: colors.primary.opacity(0.4), radius: 30, y: 15)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(artScale)
            .offset(x: artOffset)
            .gesture(artSwipeGesture)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: artScale)

            // Reflection
            if let song = appState.currentSong, let uiImage = song.coverArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(x: 1, y: -1)
                    .frame(height: 60)
                    .clipped()
                    .mask(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.3)
                    .scaleEffect(artScale)
                    .offset(x: artOffset)
            }
        }
    }

    // MARK: - Art Swipe Gesture

    private var artSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    artOffset = value.translation.width * 0.5
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                if value.translation.width < -threshold {
                    Haptics.impact(.medium)
                    appState.skipNext()
                } else if value.translation.width > threshold {
                    Haptics.impact(.medium)
                    appState.skipPrevious()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    artOffset = 0
                }
            }
    }

    // MARK: - Song Info

    private var songInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(appState.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Star / favorite button
            Button {
                Haptics.impact(.light)
                if let song = appState.currentSong {
                    appState.databaseManager.toggleLike(songId: song.id)
                }
            } label: {
                Image(systemName: isCurrentSongLiked ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isCurrentSongLiked ? .yellow : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Three-dot menu
            Menu {
                Button { } label: { Label("Add to Playlist", systemImage: "text.badge.plus") }
                Button { } label: { Label("Share Song", systemImage: "square.and.arrow.up") }
                Button { } label: { Label("Go to Album", systemImage: "square.stack") }
                Button { } label: { Label("Go to Artist", systemImage: "person") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 28)
    }

    private var isCurrentSongLiked: Bool {
        guard let song = appState.currentSong else { return false }
        return appState.databaseManager.isLiked(songId: song.id)
    }

    // MARK: - Progress Scrubber

    private var progressScrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: $sliderValue,
                in: 0...max(appState.duration, 1),
                onEditingChanged: { editing in
                    isDragging = editing
                    if editing {
                        Haptics.selection()
                    } else {
                        Haptics.selection()
                        appState.audioPlayer.seek(to: sliderValue)
                        appState.currentTime = sliderValue
                    }
                }
            )
            .tint(colors.primary)

            HStack {
                Text(formatTime(isDragging ? sliderValue : appState.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(max(0, appState.duration - (isDragging ? sliderValue : appState.currentTime))))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                Haptics.impact(.medium)
                appState.skipPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            Button {
                Haptics.impact(.medium)
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                Haptics.impact(.medium)
                appState.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Button {
                // Lyrics placeholder
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                // AirPlay — handled by MPVolumeView route button
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = true
        view.tintColor = .white
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. Now Playing has PS3 background, album art reflection, colored scrubber, star button, art swipe gesture, and clean transport controls.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/NowPlaying/NowPlayingView.swift
git commit -m "Redesign Now Playing with Flip treatment: reflection, PS3 background, new layout"
```

---

### Task 6: Restyle Search View

**Files:**
- Modify: `Lipster/Views/Search/SearchView.swift`

- [ ] **Step 1: Restyle SearchView**

Replace the entire contents of `Lipster/Views/Search/SearchView.swift`:

```swift
import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var songResults: [Song] = []
    @State private var albumResults: [Album] = []
    @State private var artistResults: [String] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient background
                AmbientBackgroundView(
                    colors: appState.albumColors,
                    image: appState.currentSong?.coverArtImage
                )

                Group {
                    if searchText.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("Search by song title, artist, or album.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if songResults.isEmpty && albumResults.isEmpty && artistResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // Artists
                                if !artistResults.isEmpty {
                                    sectionHeader("Artists")
                                    ForEach(artistResults, id: \.self) { artist in
                                        NavigationLink(value: artist) {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(.white.opacity(0.08))
                                                    .frame(width: 40, height: 40)
                                                    .overlay {
                                                        Text(String(artist.prefix(1)).uppercased())
                                                            .font(.headline).fontWeight(.bold)
                                                            .foregroundStyle(.white.opacity(0.6))
                                                    }
                                                Text(artist)
                                                    .font(.body).foregroundStyle(.white)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption).foregroundStyle(.white.opacity(0.3))
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                    }
                                }

                                // Albums
                                if !albumResults.isEmpty {
                                    sectionHeader("Albums")
                                    ForEach(albumResults) { album in
                                        NavigationLink(value: album) {
                                            HStack(spacing: 12) {
                                                if let image = album.coverArtImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(.white.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(album.name)
                                                        .font(.subheadline).foregroundStyle(.white).lineLimit(1)
                                                    Text(album.artist)
                                                        .font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption).foregroundStyle(.white.opacity(0.3))
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                    }
                                }

                                // Songs
                                if !songResults.isEmpty {
                                    sectionHeader("Songs")
                                    ForEach(songResults) { song in
                                        Button {
                                            appState.play(song: song, queue: songResults)
                                        } label: {
                                            HStack(spacing: 12) {
                                                if let image = song.coverArtImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(.white.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(song.title)
                                                        .font(.subheadline).foregroundStyle(.white).lineLimit(1)
                                                    Text(song.artist)
                                                        .font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                                                }
                                                Spacer()
                                                Text(song.durationFormatted)
                                                    .font(.caption).foregroundStyle(.white.opacity(0.4)).monospacedDigit()
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Songs, artists, albums")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                if newValue.count >= 1 {
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        let db = appState.databaseManager
                        songResults = db.searchSongs(query: newValue)
                        albumResults = db.searchAlbums(query: newValue)
                        artistResults = db.searchArtists(query: newValue)
                    }
                } else {
                    songResults = []
                    albumResults = []
                    artistResults = []
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .navigationDestination(for: String.self) { artist in
                ArtistDetailView(artist: artist, allSongs: appState.databaseManager.loadSongs())
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. Search has ambient background and glassy rows.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/Search/SearchView.swift
git commit -m "Restyle SearchView with glassy rows and ambient background"
```

---

### Task 7: Restyle Settings View

**Files:**
- Modify: `Lipster/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Restyle SettingsView**

Replace the entire contents of `Lipster/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List {
            Section("Playback") {
                HStack {
                    Text("Gapless Playback")
                    Spacer()
                    Text("On")
                        .foregroundStyle(.white.opacity(0.5))
                }
                Toggle("Volume Normalization", isOn: $appState.volumeNormalizationEnabled)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Library") {
                LabeledContent("Songs", value: "\(appState.databaseManager.songCount())")
                LabeledContent("Albums", value: "\(appState.databaseManager.albumCount())")
                LabeledContent("Artists", value: "\(appState.databaseManager.artistCount())")
                LabeledContent("Database", value: "ripper.db")
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background {
            AmbientBackgroundView(
                colors: appState.albumColors,
                image: appState.currentSong?.coverArtImage
            )
        }
    }
}
```

Note: SettingsView no longer wraps itself in `NavigationStack` — the parent (LipsterApp sheet) provides it.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. Settings has ambient background and translucent rows.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/Settings/SettingsView.swift
git commit -m "Restyle SettingsView with glassy rows and ambient background"
```

---

### Task 8: Add Matched Transitions (Mini Player ↔ Now Playing)

**Files:**
- Modify: `Lipster/App/LipsterApp.swift`
- Modify: `Lipster/Views/NowPlaying/MiniPlayerView.swift`

The spec calls for a matched geometry transition between the mini player and the Now Playing sheet. This creates a smooth "morph" animation when tapping the mini player.

- [ ] **Step 1: Add @Namespace to LipsterApp and pass to MiniPlayerView**

In `LipsterApp.swift`, add a namespace and pass it down. Add to the WindowGroup content:

```swift
@Namespace private var nowPlayingNamespace
```

Add `.matchedTransitionSource(id: "nowPlaying", in: nowPlayingNamespace)` on the MiniPlayerView inside BottomBarView (this requires passing the namespace through). Alternatively, add the namespace directly in MiniPlayerView using `@Namespace`.

In `MiniPlayerView.swift`, add:

```swift
@Namespace private var namespace
```

Then on the mini player's `VStack` content, add:

```swift
.matchedTransitionSource(id: "nowPlaying", in: namespace)
```

On the Now Playing sheet in `LipsterApp.swift`, add:

```swift
.sheet(isPresented: $showNowPlaying) {
    NowPlayingView()
        .environment(appState)
        .interactiveDismissDisabled(false)
        .navigationTransition(.zoom(sourceID: "nowPlaying", in: nowPlayingNamespace))
}
```

Note: The namespace must be shared between the source and destination. If passing through BottomBarView is complex, the simplest approach is to use `.matchedTransitionSource` directly in MiniPlayerView and `.navigationTransition` on the sheet — iOS 26's sheet transitions may handle this. Test and adjust as needed.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build. Tapping mini player shows a zoom transition into Now Playing.

- [ ] **Step 3: Commit**

```bash
git add Lipster/App/LipsterApp.swift Lipster/Views/NowPlaying/MiniPlayerView.swift
git commit -m "Add matched transition between mini player and Now Playing sheet"
```

---

### Task 9: Cleanup Dead Code

**Files:**
- Delete: `Lipster/Views/Flip/FlipBrowserView.swift` (absorbed into LibraryView)

- [ ] **Step 1: Remove FlipBrowserView**

`FlipBrowserView` was the old Flip tab. Its carousel and PS3 background logic have been absorbed into `LibraryView`. Delete the file:

```bash
rm Lipster/Views/Flip/FlipBrowserView.swift
rmdir Lipster/Views/Flip 2>/dev/null || true
```

Also remove the `Flip` folder from the Xcode project if it's referenced (it may be a folder reference that auto-tracks). If using Xcode's file system folder references, removing the file from disk is sufficient.

- [ ] **Step 2: Remove FlipBrowserView from Xcode project file (if needed)**

If the build fails with "missing file" errors after deleting, the file was referenced in the `.pbxproj`. Open the project in Xcode and remove the stale reference, or use:

```bash
# Check if there are any remaining references to FlipBrowserView
grep -r "FlipBrowserView" Lipster/ --include="*.swift"
```

If any file still imports or references `FlipBrowserView`, remove those references.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet`

Expected: Successful build with no warnings about missing files.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove FlipBrowserView (absorbed into LibraryView)"
```

---

### Task 10: Final Integration Verification

- [ ] **Step 1: Full build verification**

```bash
xcodebuild build -scheme Lipster -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet
```

- [ ] **Step 2: Manual verification checklist**

Run the app in Simulator and verify:

1. **Bottom bar**: 3 icons (Discover/Library/Search), mini player appears above when song plays, connected as one unit
2. **Library — Albums**: Category bar shows Albums/Artists/Playlists, carousel works, tracks show below, play/shuffle work
3. **Library — Artists**: Switching to Artists shows artists in carousel, grouped albums+tracks below
4. **Library — Playlists**: Switching to Playlists shows playlists in carousel, tracks below
5. **Now Playing**: Sheet opens from mini player, has reflection under art, PS3 gradient background, colored scrubber, star button, art swipe to skip
6. **Search**: Ambient background, glassy result rows, search works
7. **Settings**: Gear icon opens sheet, glassy rows, ambient background
8. **Discover**: Shows placeholder stub
9. **Navigation**: Tab switching preserves state, NavigationStack push/pop works
10. **Background**: PS3 gradients update with centered item's colors across all screens

- [ ] **Step 3: Commit any fixes**

If any issues were found and fixed during verification:

```bash
git add -A
git commit -m "Fix integration issues from final verification"
```
