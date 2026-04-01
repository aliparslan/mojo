# Lipster Full-App Redesign — Flip Aesthetic

## Overview

Redesign the entire Lipster app around the Flip (Cover Flow) aesthetic. The 3D carousel, PS3-inspired ambient backgrounds, reflections, and depth-driven visual language become the unifying design principle across every screen. The app should feel like a premium media center, not a standard phone app.

**Approach:** Rebuild the shell (navigation, bottom bar, mini player), preserve internals (FlipView engine, playback infrastructure, database layer, search logic).

## Constraints

- No parallax, Ken Burns, or gyroscope-based motion effects (user gets nauseous)
- iOS 26 minimum deployment target
- Keep existing `AlbumColors` extraction system
- Keep existing `AudioPlayer` / playback infrastructure unchanged
- Keep existing `DatabaseManager` / SQLite layer unchanged
- Keep existing `FlipView` (UIKit carousel engine) unchanged
- No external dependencies

## 1. App Shell & Navigation

### Bottom Bar + Mini Player Unit

Replace the current `TabView` with a custom bottom bar. The mini player and navigation icons form one connected unit (like Tidal) — a single `VStack` sharing one continuous glassy background.

**Mini player (top half of the unit):**
- Album art thumbnail, song title, artist name, play/pause button, skip-next button
- Thin progress bar (2pt) along the top edge, colored with `albumColors.primary`, showing `currentTime / duration`
- Tap anywhere (except buttons) → present Now Playing sheet
- Matched transition source for Now Playing sheet animation

**Navigation bar (bottom half of the unit):**
- 3 icons with labels: Discover (`sparkles`), Library (`music.note.house`), Search (`magnifyingglass`)
- Selected item: white, full opacity. Unselected: `white.opacity(0.4)`
- No visible divider between mini player and nav — they share one background surface

**Background treatment:**
- `.ultraThinMaterial` or custom dark translucent fill
- Consistent across both halves — one connected surface

**State management:**
- Each section (Discover, Library, Search) has its own `NavigationStack`
- Switching sections preserves state (scroll position, navigation depth)
- The bottom bar replaces `TabView` entirely — custom implementation using `@State` for selected section
- When no song is playing: mini player half is hidden, only the navigation icons show. The unit shrinks to just the nav bar.

### Top-Right Gear Icon

- Small glassy circle button (e.g. `circle.fill` with ultra-thin material, `gearshape` icon)
- Top-right corner of the main screen
- Taps to present Settings as a `.sheet`
- Only visible on root-level views (not inside pushed NavigationStack destinations)

### Navigation Flow

```
LipsterApp
├── Custom Bottom Bar + Mini Player (always visible when song playing)
│   ├── Discover (NavigationStack)
│   │   └── Placeholder / future content
│   ├── Library (NavigationStack)
│   │   ├── Category Bar: [Albums] | Artists | Playlists
│   │   ├── Flip Carousel (adapts per category)
│   │   ├── Content below carousel (tracks, albums, etc.)
│   │   └── Push destinations: AlbumDetailView, ArtistDetailView
│   └── Search (NavigationStack)
│       └── Search field + results list
├── Now Playing (Sheet, .large detent)
└── Settings (Sheet, from gear icon)
```

## 2. Library View (Core Experience)

The Library tab is the centerpiece. It contains the Flip carousel with a category bar to switch what's being browsed.

### Category Bar

- Horizontal pill selector: `Albums | Artists | Playlists`
- Same style as current XMB selector — capsule with `matchedGeometryEffect`, white text on translucent background (`white.opacity(0.15)`)
- Positioned above the carousel
- Switching categories: carousel content crossfades/transitions to the new entity type

### Albums Mode (Default)

Essentially the current `FlipBrowserView`:
- Flip carousel showing album covers
- Album info below (name, artist, year)
- Play / Shuffle row
- Track list for the centered album
- PS3 ambient background reacting to centered album's colors

No changes needed to the carousel engine. This mode is the existing experience, just living inside the new Library tab.

### Artists Mode

- Carousel shows artists, each represented by their most recent album's cover art
- Artist name shown below the carousel (same position as album info)
- Below the carousel: grouped list — album headers with tracks nested under each
  - Album header: cover art thumbnail, album name, year
  - Tracks: track number, title, duration (same row style as album tracks)
  - Tap a track → play it, queued with all tracks by that artist
- Centered artist's colors drive the ambient background

### Playlists Mode

- Carousel shows playlists using their cover art (`coverPath` from data model)
- Playlist name shown below the carousel
- Below: track list (same layout as album tracks)
- Centered playlist's cover art colors drive the ambient background

### PS3 Background (Shared)

The ambient background from current `FlipBrowserView` applies to the entire Library regardless of category:
- Black base
- Blurred cover art of centered item (opacity 0.2, scale 1.5, blur 80)
- Linear gradient from album colors (primary → clear → secondary → clear)
- Radial gradient (primary, centered upper-third)
- Animated with `.easeInOut(duration: 0.5)` on item changes

This background component should be extracted into a reusable view (`AmbientBackgroundView` or similar) since it's used in multiple places.

## 3. Now Playing (Flip Treatment)

### Presentation

- Sheet with `.presentationDetents([.large])`
- Matched transition from mini player (`.matchedTransitionSource` / `.navigationTransition(.zoom)`)
- `.interactiveDismissDisabled(false)` — swipe to dismiss

### Layout (Top to Bottom)

1. **Grab bar** — native from `.sheet`, no custom code
2. **Album art** — large, square, `aspectRatio(1, contentMode: .fit)`, 12pt corner radius
   - **Flip treatment:** reflection below the art — flipped image with gradient mask, same technique as `CoverItemView` in the carousel. Reflection height: 30% of art height, alpha 0.3, gradient-faded.
   - Colored shadow: `albumColors.primary.opacity(0.4)`, radius 30, y-offset 15
   - Scale: 1.0 when playing, 0.85 when paused
   - Horizontal swipe gesture for track change (art translates with finger, commits on threshold)
3. **Song info row** — title (`.title3`, bold), artist (`.subheadline`, secondary opacity), star/favorite button, three-dot context menu
4. **Progress scrubber** — native `Slider`, `.tint(albumColors.primary)`, time labels below (elapsed left, remaining right)
5. **Transport controls** — `backward.fill` / `play.fill` or `pause.fill` / `forward.fill`. Large icons (~36pt skip, ~48pt play). `.contentTransition(.symbolEffect(.replace))` on play/pause
6. **Volume slider** — `MPVolumeView` wrapped in `UIViewRepresentable`, flanked by `speaker.fill` and `speaker.wave.3.fill`
7. **Bottom icons** — lyrics (`quote.bubble`), AirPlay (`airplayaudio`), queue (`list.bullet`)

### PS3 Background

Same ambient gradient system as Library:
- Black base + blurred cover art + album color gradients
- Darker overlay (opacity 0.3) for contrast against white controls
- Animated color transitions on track change (`.easeInOut(duration: 1.0)`)

### What Makes It "Flip"

- Reflection under album art (the signature Flip visual element)
- Rich, saturated gradient background (PS3 media center feel, not Apple Music's muted tones)
- Colored shadow matching album palette
- Overall mood: "media center" not "phone app"

### Gestures & Interaction

- Dismiss: native sheet swipe
- Album art swipe: horizontal `DragGesture`, left = next, right = previous. `Haptics.impact(.medium)` on commit
- Scrubber: `Haptics.selection()` on drag start/end
- Transport: `Haptics.impact(.medium)` on skip and play/pause
- Star button: toggles liked state (wired to `liked_songs` DB table)
- Three-dot menu: Add to Playlist, Share, Go to Album, Go to Artist (placeholders)

## 4. Search View

### Layout

- Search field at top (dark/glassy styling consistent with the aesthetic)
- Results below, grouped by type: Albums, Artists, Songs
- Album results: cover art thumbnail + name + artist
- Artist results: album cover thumbnail + artist name
- Song results: album art thumbnail + title + artist + duration

### Background

- PS3 ambient gradient tinted with currently playing song's colors (if playing)
- Falls back to neutral dark gradient when nothing is playing

### Interaction

- Tap album → push `AlbumDetailView`
- Tap artist → push artist detail view (grouped albums + tracks)
- Tap song → play immediately
- Existing `SearchView` query logic reused, restyled

### Visual Treatment

- List rows: subtle translucent background (`white.opacity(0.06)`) with rounded corners
- Consistent with the glassy depth aesthetic

## 5. Discover View (Stub)

- Placeholder for future content
- PS3 ambient background tinted with currently playing song's colors (if available), otherwise neutral dark gradient
- Centered content: "Discover" title, "Coming soon" subtitle
- Will be built out separately with recently played, recently added, recommendations, etc.

## 6. Settings (Profile Sheet)

- Presented as a sheet from the gear icon
- Existing `SettingsView` content preserved (playback options, library stats, sleep timer, etc.)
- Restyled with dark/glassy aesthetic:
  - Translucent grouped list backgrounds (replace default iOS grouped style)
  - PS3 ambient background (neutral dark gradient or current song colors)

## 7. Visual Language (Applied Everywhere)

Design tokens and patterns that unify all screens:

### Backgrounds

- **Black base** with blurred cover art overlay (opacity 0.2, blur 80, scale 1.5)
- **Album color gradients**: linear (top-leading → bottom-trailing) + radial (upper-third center)
- Extract into a reusable `AmbientBackgroundView(colors: AlbumColors, image: UIImage?)` component

### Surfaces

- `.ultraThinMaterial` or custom translucent fills for interactive surfaces
- Bottom bar unit: continuous glassy surface
- List rows: `white.opacity(0.06-0.12)` backgrounds with rounded corners
- No opaque backgrounds anywhere except the black base

### Reflections

- Used on album art in: carousel covers, Now Playing art
- Not applied to every UI element — reserved for hero art only
- Technique: flipped image (scaleY: -1), 30% height, gradient mask, alpha 0.3

### Shadows

- Album art: colored shadow using `albumColors.primary.opacity(0.3-0.4)`, radius 10-30
- Other elements: subtle black shadow (opacity 0.2-0.4)
- Carousel covers: existing shadow params (radius 10, offset y:4, opacity 0.4)

### Typography

- Titles: `.title2` / `.title3`, bold
- Secondary: `.subheadline`, `white.opacity(0.6)`
- Metadata: `.caption` / `.caption2`, `white.opacity(0.4)`
- Time/numbers: `.monospacedDigit()` always
- Color: white with opacity levels (1.0, 0.6, 0.4) — never colored text except accent indicators

### Color

- **Dark mode forced** on all views (`.preferredColorScheme(.dark)`)
- **Dynamic album colors** via existing `ColorExtractor` / `AlbumColors` system
- Primary: scrubber tint, progress bar, art shadow, gradient dominant
- Secondary/tertiary: gradient accents, subtle background tones
- No hardcoded accent colors — everything derives from album art

### Animations

- **Interactions**: `.spring(response: 0.35, dampingFraction: 0.85)` (snappy)
- **Color transitions**: `.easeInOut(duration: 0.5)` for background/gradient changes
- **Symbol effects**: `.contentTransition(.symbolEffect(.replace))` for play/pause
- **Transitions**: `.opacity` for category switching, `.move(edge:)` for directional changes
- **Carousel**: existing sine-curve easing for rotation ramp

### Haptics

- Light impact: taps, favorite toggle, category selection
- Medium impact: transport controls, skip, art swipe commit
- Selection: scrubber drag start/end

## Files Changed

| File | Scope |
|------|-------|
| `LipsterApp.swift` | Complete rewrite — custom bottom bar, mini player unit, 3-section navigation, gear icon, sheet presentations |
| `MiniPlayerView.swift` | Redesign — integrated with bottom bar as connected unit, progress bar, matched transition |
| `LibraryView.swift` | Major rewrite — category bar (Albums/Artists/Playlists), hosts carousel, adapts content per category |
| `FlipBrowserView.swift` | Refactor — carousel logic extracted to be reusable from LibraryView, PS3 background extracted to shared component |
| `NowPlayingView.swift` | Full rewrite — Flip treatment, reflection on art, PS3 background, new layout |
| `SearchView.swift` | Restyle — glassy rows, ambient background, grouped results |
| `SettingsView.swift` | Restyle — glassy grouped lists, ambient background |
| `AlbumsView.swift` | Browsing function absorbed into LibraryView's Albums mode. `AlbumDetailView` (push destination for track list) remains. |
| `ArtistsView.swift` | Rewrite for carousel-driven browsing with grouped album+track lists |
| `PlaylistsView.swift` | Rewrite for carousel-driven browsing |

### New Files

| File | Purpose |
|------|---------|
| `AmbientBackgroundView.swift` | Reusable PS3 gradient background component |
| `BottomBarView.swift` | Custom bottom bar + mini player connected unit |
| `DiscoverView.swift` | Stub placeholder for future Discover tab |

### Unchanged Files

| File | Reason |
|------|--------|
| `FlipView.swift` | Carousel engine works perfectly, no changes needed |
| `AppState.swift` | Playback state management unchanged (minor additions for liked songs if not done) |
| `AudioPlayer.swift` | Playback infrastructure unchanged |
| `DatabaseManager.swift` | Data layer unchanged |
| `NowPlayingManager.swift` | Lock screen / remote controls unchanged |
| `LiveActivityManager.swift` | Dynamic Island unchanged |
| `ImageCache.swift` | Caching unchanged |
| `ColorExtractor.swift` | Color extraction unchanged |
| `HapticManager.swift` | Haptics unchanged |
| `Song.swift` / `Album.swift` / `Playlist.swift` | Models unchanged |
