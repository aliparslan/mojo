# Now Playing Screen Redesign — iOS 26 Native

## Overview

Full overhaul of the Now Playing screen, mini player, and app shell to adopt iOS 26 patterns and match Apple Music's design language. Targets iOS 26 as minimum deployment.

## Reference

Apple Music iOS 26 Now Playing (user-provided screenshot): full-screen sheet at `.large` detent, grab bar, ambient gradient background, album-colored scrubber, large transport icons, volume slider, 3 bottom icons.

## Architecture: Full iOS 26 Native (Approach B)

### App Shell (LipsterApp.swift)

- Replace `.fullScreenCover(isPresented:)` with `.sheet(isPresented:)` using `.presentationDetents([.large])`
- Replace `.safeAreaInset(edge: .bottom) { miniPlayer }` on every tab with `.tabViewBottomAccessory { MiniPlayerView() }` on the TabView
- Add `@Namespace` for matched geometry transition between mini player and sheet
- Use `.matchedTransitionSource(id:in:)` on mini player and `.navigationTransition(.zoom(sourceID:in:))` on sheet

### Now Playing Layout (top to bottom)

1. **Grab bar** — native from `.sheet`, no custom code. Remove the manual `Capsule()` pull tab.
2. **Album art** — square, `aspectRatio(1, contentMode: .fit)`, 12pt corner radius, shadow colored from `colors.primary.opacity(0.4)` instead of static black. Horizontal swipe gesture for track change. Scale 1.0 when playing, 0.85 when paused (keep existing behavior).
3. **Song info row** — title (`.title3`, bold, single line truncated), artist (`.subheadline`, secondary opacity), star/favorite button, three-dot context menu button. Replace the current plus button.
4. **Progress scrubber** — native `Slider` with `.sliderThumbVisibility(.hidden)`, `.tint(colors.primary)` for album-colored fill. Time labels below: elapsed left, remaining right.
5. **Transport controls** — `backward.fill` / `pause.fill` or `play.fill` / `forward.fill`. Large icons (~36pt skip, ~48pt play), plain white, no backgrounds. Add `.contentTransition(.symbolEffect(.replace))` on play/pause.
6. **Volume slider** — `MPVolumeView` wrapped in `UIViewRepresentable` (controls system volume, same as Apple Music). `speaker.fill` and `speaker.wave.3.fill` icons flanking.
7. **Bottom controls** — 3 icons: `quote.bubble` (lyrics), `airplayaudio`, `list.bullet` (queue). Remove share button. Slightly higher opacity than current 0.45.

### Remove from NowPlayingView

- Custom `AppleMusicSlider` component (replaced by native Slider)
- Manual `GeometryReader` for safe area math (sheet handles it)
- Custom drag-to-dismiss gesture (sheet handles it)
- `dragOffset` state and related animation code
- Source label ("PLAYING FROM") — Apple Music doesn't have one, go straight to art
- The pull tab capsule

### Visual Polish

- **Background**: keep ambient 3-color gradient from `AlbumColors` but increase dark overlay from `0.15` to `0.3` for better contrast (Apple Music's is more muted/darker)
- **Art shadow**: `colors.primary.opacity(0.4)` with radius 30, y: 15 — shifts color with each album
- **Scrubber tint**: `.tint(colors.primary)` on native Slider — fill matches album palette
- **Song change animation**: slide transition on art and text when skipping. Art slides out in skip direction, new art slides in from opposite side
- **Play/pause**: `.contentTransition(.symbolEffect(.replace))` for smooth icon morph
- **Background animation**: keep `.easeInOut(duration: 1.0)` on color changes

### Gestures & Interaction

- **Dismiss**: native sheet swipe-to-dismiss. Remove all custom drag gesture code.
- **Album art swipe**: horizontal `DragGesture` on the album art area. Swipe left = next track, swipe right = previous. Art translates with finger, snaps back or commits. `Haptics.impact(.medium)` on commit.
- **Scrubber haptics**: `Haptics.selection()` on drag start and drag end via `isDragging` onChange.
- **Transport haptics**: keep `Haptics.impact(.medium)` on skip buttons. Keep on play/pause.
- **Three-dot menu**: `.menu` with items: Add to Playlist, Share Song, Go to Album, Go to Artist (placeholders for now — no-op actions).
- **Star button**: toggle visual state (`star` / `star.fill`). Wire to `appState` liked songs — the `liked_songs` DB table already exists.

### Mini Player (MiniPlayerView.swift)

- **Placement**: `.tabViewBottomAccessory` on the TabView instead of `.safeAreaInset` on each tab
- **Progress bar**: thin (2pt) bar along top edge of mini player, colored with `colors.primary`, showing `currentTime / duration` progress
- **Matched transition**: `.matchedTransitionSource(id: "nowPlaying", in: namespace)` for morph to full player
- **Keep**: album art thumbnail, title, artist, play/pause button, skip next button
- **Remove**: horizontal swipe-to-skip gesture (may conflict with tab bar accessory behavior)
- **Keep**: tap to expand to full player

## Files Changed

| File | Scope |
|------|-------|
| `NowPlayingView.swift` | Full layout rewrite — new structure, native slider, gestures, visual polish |
| `LipsterApp.swift` | Sheet presentation, tabViewBottomAccessory, namespace, remove safeAreaInset pattern |
| `MiniPlayerView.swift` | Progress bar, matched transition source, remove swipe gesture |
| `AppState.swift` | Liked song toggle method, any volume-related cleanup |

## Constraints

- No parallax or Ken Burns motion effects (user gets nauseous)
- No CoreMotion-based motion
- iOS 26 minimum deployment target
- Keep existing `AlbumColors` extraction system (it works well)
- Keep existing `AudioPlayer` / playback infrastructure unchanged
