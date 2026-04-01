# Now Playing Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Now Playing screen, mini player, and app shell to adopt iOS 26 native patterns and match Apple Music's design language.

**Architecture:** Replace `.fullScreenCover` with `.sheet(.large)`, move mini player to `.tabViewBottomAccessory`, use native thumbless Sliders, `MPVolumeView`, album-colored scrubber, and matched geometry transitions. Full layout rewrite of NowPlayingView.

**Tech Stack:** SwiftUI (iOS 26), MediaPlayer (MPVolumeView), AVFoundation (existing)

**Spec:** `docs/superpowers/specs/2026-03-29-now-playing-redesign.md`

---

### Task 1: App Shell — Sheet + Tab Bar Accessory

**Files:**
- Modify: `Lipster/App/LipsterApp.swift`

- [ ] **Step 1: Replace fullScreenCover with sheet and add namespace**

Replace the entire `LipsterApp.swift` with:

```swift
import SwiftUI

@main
struct LipsterApp: App {
    @State private var appState = AppState()
    @State private var showNowPlaying = false
    @Namespace private var playerTransition

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .tabItem { Label("Library", systemImage: "music.note.house") }

                FlipBrowserView()
                    .tabItem { Label("Flip", systemImage: "rectangle.stack") }

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .tabViewBottomAccessory {
                if appState.currentSong != nil {
                    MiniPlayerView(showNowPlaying: $showNowPlaying, namespace: playerTransition)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(appState)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .navigationTransition(.zoom(sourceID: "nowPlaying", in: playerTransition))
            }
        }
    }
}
```

Key changes:
- Removed `.safeAreaInset(edge: .bottom) { miniPlayer }` from every tab
- Added `.tabViewBottomAccessory` on the TabView with the mini player
- Replaced `.fullScreenCover` with `.sheet` using `.presentationDetents([.large])`
- Added `@Namespace` for matched geometry transition
- Added `.navigationTransition(.zoom)` on the sheet content
- Passed `namespace` to `MiniPlayerView` for `matchedTransitionSource`

- [ ] **Step 2: Build and verify the app launches**

Run: Build in Xcode (Cmd+B). This will fail because `MiniPlayerView` doesn't accept `namespace` yet — that's expected. Proceed to Task 2.

- [ ] **Step 3: Commit**

```bash
git add Lipster/App/LipsterApp.swift
git commit -m "refactor: replace fullScreenCover with sheet, add tabViewBottomAccessory"
```

---

### Task 2: Mini Player — Progress Bar + Matched Transition

**Files:**
- Modify: `Lipster/Views/NowPlaying/MiniPlayerView.swift`

- [ ] **Step 1: Rewrite MiniPlayerView with progress bar and matched transition**

Replace the entire `MiniPlayerView.swift` with:

```swift
import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @Binding var showNowPlaying: Bool
    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar along top edge
            GeometryReader { geo in
                let progress = appState.duration > 0
                    ? appState.currentTime / appState.duration
                    : 0

                Rectangle()
                    .fill(appState.albumColors.primary)
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 0.5), value: appState.currentTime)
            }
            .frame(height: 2)

            HStack(spacing: 12) {
                // Album art
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentSong?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(appState.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play/Pause
                Button {
                    Haptics.impact(.light)
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }

                // Next
                Button {
                    Haptics.impact(.light)
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .matchedTransitionSource(id: "nowPlaying", in: namespace)
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
    }
}
```

Key changes:
- Added `namespace: Namespace.ID` parameter
- Added progress bar (2pt, album-colored) along top edge
- Added `.matchedTransitionSource(id: "nowPlaying", in: namespace)` for morph to full player
- Removed horizontal swipe-to-skip gesture
- Removed gradient background (now uses `.ultraThinMaterial` only for cleaner look in tab bar accessory)
- Removed `dragOffset` state
- Added `.contentTransition(.symbolEffect(.replace))` on play/pause icon

- [ ] **Step 2: Build and verify mini player compiles**

Run: Build in Xcode (Cmd+B). The app should now compile with Tasks 1+2.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/NowPlaying/MiniPlayerView.swift
git commit -m "feat: redesign mini player with progress bar and matched transition"
```

---

### Task 3: NowPlayingView — MPVolumeView Wrapper

**Files:**
- Create: `Lipster/Views/NowPlaying/SystemVolumeSlider.swift`

- [ ] **Step 1: Create the MPVolumeView UIViewRepresentable wrapper**

Create `Lipster/Views/NowPlaying/SystemVolumeSlider.swift`:

```swift
import MediaPlayer
import SwiftUI

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        volumeView.setVolumeThumbImage(UIImage(), for: .normal)
        volumeView.tintColor = UIColor.white.withAlphaComponent(0.45)
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
```

- [ ] **Step 2: Add file to Xcode project**

The file should be auto-detected by Xcode if the project uses folder references. If it uses file references, add it to the Xcode project manually.

- [ ] **Step 3: Commit**

```bash
git add Lipster/Views/NowPlaying/SystemVolumeSlider.swift
git commit -m "feat: add MPVolumeView wrapper for system volume slider"
```

---

### Task 4: NowPlayingView — Full Layout Rewrite

**Files:**
- Modify: `Lipster/Views/NowPlaying/NowPlayingView.swift`

- [ ] **Step 1: Rewrite NowPlayingView with new layout**

Replace the entire `NowPlayingView.swift` with:

```swift
import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var showQueue: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var artSwipeOffset: CGFloat = 0
    @State private var skipDirection: Edge = .trailing

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Album art — swipeable
                albumArt
                    .padding(.horizontal, 28)

                Spacer().frame(minHeight: 24, maxHeight: 36)

                // Song info, scrubber, transport, volume, bottom
                VStack(spacing: 0) {
                    songInfoRow
                        .padding(.horizontal, 28)

                    progressScrubber
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                    transportControls
                        .padding(.top, 18)

                    volumeSlider
                        .padding(.horizontal, 28)
                        .padding(.top, 14)

                    bottomControls
                        .padding(.horizontal, 48)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = appState.currentTime
            artScale = appState.isPlaying ? 1.0 : 0.85
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging {
                sliderValue = newValue
            }
        }
        .onChange(of: appState.currentSong) { _, _ in
            sliderValue = 0
        }
        .onChange(of: appState.isPlaying) { _, playing in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                artScale = playing ? 1.0 : 0.85
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [colors.primary, colors.secondary, colors.tertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [colors.primary.opacity(0.6), .clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [colors.secondary.opacity(0.4), .clear],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 400
            )

            Color.black.opacity(0.3)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: colors)
    }

    // MARK: - Album Art

    private var albumArt: some View {
        Group {
            if let song = appState.currentSong, let uiImage = song.coverArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: colors.primary.opacity(0.4), radius: 30, y: 15)
                    .id(song.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: skipDirection).combined(with: .opacity),
                        removal: .move(edge: skipDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
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
        .scaleEffect(artScale)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: artScale)
        .offset(x: artSwipeOffset)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        artSwipeOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 80
                    if value.translation.width < -threshold || value.predictedEndTranslation.width < -200 {
                        // Swipe left → next
                        Haptics.impact(.medium)
                        skipDirection = .trailing
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.skipNext()
                        }
                    } else if value.translation.width > threshold || value.predictedEndTranslation.width > 200 {
                        // Swipe right → previous
                        Haptics.impact(.medium)
                        skipDirection = .leading
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.skipPrevious()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: - Song Info Row

    private var songInfoRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(appState.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
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
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }

                // Context menu
                Menu {
                    Button { } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    Button { } label: {
                        Label("Share Song", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button { } label: {
                        Label("Go to Album", systemImage: "square.stack")
                    }
                    Button { } label: {
                        Label("Go to Artist", systemImage: "person")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
                }
            }
        }
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
                in: 0...max(appState.duration, 1)
            ) {
                Text("Progress")
            } onEditingChanged: { editing in
                isDragging = editing
                if editing {
                    Haptics.selection()
                } else {
                    Haptics.selection()
                    appState.audioPlayer.seek(to: sliderValue)
                    appState.currentTime = sliderValue
                }
            }
            .sliderThumbVisibility(.hidden)
            .tint(colors.primary)

            HStack {
                Text(formatTime(isDragging ? sliderValue : appState.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(max(0, appState.duration - (isDragging ? sliderValue : appState.currentTime))))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack {
            Spacer()

            Button {
                Haptics.impact(.medium)
                skipDirection = .leading
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.skipPrevious()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 56)
            }

            Spacer()

            Button {
                Haptics.impact(.medium)
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 64)
                    .contentTransition(.symbolEffect(.replace))
            }

            Spacer()

            Button {
                Haptics.impact(.medium)
                skipDirection = .trailing
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.skipNext()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 56)
            }

            Spacer()
        }
    }

    // MARK: - Volume Slider

    private var volumeSlider: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            SystemVolumeSlider()
                .frame(height: 34)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Button { } label: {
                Image(systemName: "quote.bubble")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button { } label: {
                Image(systemName: "airplayaudio")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NowPlayingView()
        .environment(AppState())
}
```

Key changes from original:
- Removed: `GeometryReader`, manual safe area math, `dragOffset`, custom pull tab, source label, custom `AppleMusicSlider`, share button
- Added: native `Slider` with `.sliderThumbVisibility(.hidden)` and `.tint(colors.primary)`, volume slider via `SystemVolumeSlider`, star button with `databaseManager.isLiked`/`toggleLike`, three-dot context `Menu`, album art horizontal swipe gesture with slide animation, `.contentTransition(.symbolEffect(.replace))` on play/pause, colored shadow on album art, darker background overlay (0.3 instead of 0.15), song change transition (`.asymmetric` with `.move`)
- Bottom controls: 3 icons (lyrics, AirPlay, queue) instead of 4

- [ ] **Step 2: Add SystemVolumeSlider.swift to the Xcode project if needed**

If using file references in Xcode, add `SystemVolumeSlider.swift` to the project navigator under `Lipster/Views/NowPlaying/`.

- [ ] **Step 3: Build and run**

Build in Xcode (Cmd+B). Run on simulator or device. Verify:
- Sheet presentation from mini player tap
- Album art with colored shadow
- Native slider for progress (album-colored fill)
- Volume slider works
- Star button toggles
- Three-dot menu shows items
- Swipe on art to skip tracks
- Play/pause icon morphs smoothly
- Background gradient is darker/more muted

- [ ] **Step 4: Commit**

```bash
git add Lipster/Views/NowPlaying/NowPlayingView.swift Lipster/Views/NowPlaying/SystemVolumeSlider.swift
git commit -m "feat: redesign Now Playing with iOS 26 native patterns"
```

---

### Task 5: Verify and Fix Xcode Project References

**Files:**
- Modify: `Lipster.xcodeproj/project.pbxproj` (via Xcode)

- [ ] **Step 1: Open project in Xcode and verify all files are included**

Open the project in Xcode and confirm:
- `SystemVolumeSlider.swift` appears in the project navigator under `Lipster/Views/NowPlaying/`
- All 3 Now Playing files compile: `NowPlayingView.swift`, `MiniPlayerView.swift`, `SystemVolumeSlider.swift`
- `LipsterApp.swift` compiles with the new `.tabViewBottomAccessory` and `.sheet` modifiers

If `SystemVolumeSlider.swift` is missing from the project, right-click the `NowPlaying` group → Add Files to "Lipster" → select the file.

- [ ] **Step 2: Run on device or simulator**

Build and run. Test the full flow:
1. Play a song from the library
2. Mini player appears in tab bar accessory with progress bar
3. Tap mini player → sheet expands to full screen
4. Swipe down → sheet dismisses
5. Album art swipe left/right → track changes
6. Scrubber drag → seeks, album-colored fill
7. Volume slider works
8. Star button toggles
9. Play/pause icon animates

- [ ] **Step 3: Commit any project file changes**

```bash
git add -A
git commit -m "chore: update Xcode project references for Now Playing redesign"
```
