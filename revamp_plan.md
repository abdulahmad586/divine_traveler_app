# Tahfeex Revamp Plan

Based on `app_revamp.md`. This document is the single source of truth for the revamp — consult it before starting any phase.

---

## Guiding Principle

> Simple on the surface, deep underneath.

Every decision must pass this test: does it help the user **start, continue, or complete a journey**? If not, it is hidden, deferred, or removed from the primary flow.

---

## Phase 0 — Design Foundation

*Do this first. Every subsequent phase depends on it.*

### 0.1 — Color & Theme System

**Current state:** `AppColors.primaryColor = Colors.green` (Material green — loud, generic).

**Target:**

| Token | Value | Usage |
|---|---|---|
| `surface` | `#F5F0E8` | Warm off-white background |
| `primary` | `#2D5016` | Deep forest green — headers, CTAs |
| `primaryMuted` | `#4A7C28` | Secondary green — progress, badges |
| `gold` | `#C9A84C` | Completion states, highlights |
| `textPrimary` | `#1A1A1A` | Near-black body text |
| `textSecondary` | `#6B6B6B` | Supporting labels |
| `cardSurface` | `#FFFFFF` | Cards on warm background |
| `border` | `#E0D8CC` | Subtle dividers |

Replace `AppColors` in `lib/resources/colors.dart` with a full token-based class. Update `ThemeData` in `main.dart` to use `ColorScheme.fromSeed` with the new primary, plus explicit `scaffoldBackgroundColor`, `cardColor`, and `AppBarTheme`.

### 0.2 — Typography

Define a text theme in `main.dart`:

- Arabic text: already using `google_fonts` (Lateef) — keep, increase base size to 32px, generous line height (2.0)
- English body: system sans-serif, 14px, weight 400, color `textPrimary`
- Labels/captions: 11–12px, `textSecondary`
- Hierarchy enforced: nothing competes visually with Arabic text

### 0.3 — Spacing & Shape Constants

Add a `AppSizes` / `AppRadius` constants class:

- `cardRadius`: 16px
- `pagePadding`: 20px horizontal
- `sectionGap`: 28px
- Button height: 52px (generous tap targets)
- Card elevation: 0 (use border + warm bg for depth instead)

---

## Phase 1 — Home Screen Overhaul

*The entry point must collapse cognitive load to a single decision.*

### 1.1 — Remove the current `_HomeTab` layout

**Current state:** AppBar with avatar/greeting, "STUDY TOOLS" section (grid of tools), "MY JOURNEYS" section listing all journeys with Continue buttons. Two sections fighting for attention.

**Target layout:**

```
┌─────────────────────────────────┐
│  Assalamu Alaikum, [Name]       │  ← subtle, small
│                                 │
│  ┌───────────────────────────┐  │
│  │   CURRENT JOURNEY CARD    │  │  ← dominant, full-width
│  │   Title                   │  │
│  │   Progress bar            │  │
│  │   X of Y ayahs            │  │
│  │   [Continue →]            │  │  ← single primary CTA
│  └───────────────────────────┘  │
│                                 │
│  [Start a Journey]              │  ← secondary, text or outlined
│  [View Companions]              │  ← only shown if Phase 3 unlocked
└─────────────────────────────────┘
```

Rules:
- If user has an active journey: show its card front and center
- If user has multiple active journeys: show the most recently updated one; add a subtle "2 more journeys" link below
- If user has no journeys: show the "Start a Journey" prompt with a calm empty-state message (no icon spam, no emoji guilt)
- "STUDY TOOLS" grid is removed from home entirely — those features are accessed from inside a journey

### 1.2 — Remove bottom navigation bar from home

**Current state:** Three-tab bottom nav (Home / Companions / Profile).

**Target:** No persistent bottom nav bar on the home screen. Navigation is contextual:
- Profile: tap avatar in top-right of home
- Companions: unlocked in Phase 3, accessible via home secondary action or profile screen

This is the most impactful single change for reducing clutter.

### 1.3 — Empty state

Replace current empty state with:
> "Begin with a short journey. Consistency matters more than speed."

Single "Start a Journey" button below it. No other options.

---

## Phase 2 — Journey Creation: Templates First

*Users should not design their first journey. They should accept one.*

### 2.1 — Template selection screen

New screen: `JourneyTemplateScreen` (replaces `CreateJourneyScreen` as the primary entry point).

Three cards, full-width, stacked:

| Template | Dimensions | Pacing | Auto-deadline |
|---|---|---|---|
| **Daily Reading** | `read` | 5 ayahs/day | `totalAyahs / 5` days |
| **Memorization Path** | `memorize` | 3 ayahs/day | `totalAyahs / 3` days |
| **Deep Study** | `read` + `commentary` | 2 ayahs/day | `totalAyahs / 2` days |

Each card shows: name, one-line description, estimated daily commitment.

Tapping a template goes to a minimal range picker (start surah/ayah → end surah/ayah only). No title field, no dimension checkboxes, no date pickers — the template handles all of that.

A small "Customize instead" text link at the bottom opens the existing `CreateJourneyScreen` for experienced users.

### 2.2 — Backend call

Templates call `createJourney` with the pre-set dimensions and computed dates. No new API needed.

### 2.3 — Lock custom creation for new users

Track whether the user has ever completed a journey (check if any journey in the list has `status == 'completed'`). If not, the "Customize instead" link is hidden. Custom creation is unlocked after first completion.

---

## Phase 3 — Journey Study Screen Refocus

*This is the heart of the app. It must feel focused.*

### 3.1 — New layout structure in `QuranJourneyScreen`

**Current state:** AppBar with title + progress counter, FAB for Mark Complete, body switches between ayah-centric and page-context views, toolbar with view toggle.

**Target:**

```
┌─────────────────────────────────┐
│  ← back   Surah Name  [•••]     │  ← minimal AppBar
│                                 │
│  ━━━━━━━━━━━━━━━━░░░░░░  14/40  │  ← slim progress, top of body
│                                 │
│                                 │
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │    Arabic text (large)    │  │  ← dominant
│  │                           │  │
│  │    Translation (below)    │  │  ← secondary
│  │                           │  │
│  └───────────────────────────┘  │
│                                 │
│  [← Prev]            [Next →]   │  ← subtle navigation
│                                 │
│       [  Mark Complete  ]       │  ← primary CTA, bottom
│                                 │
│   🔊 Audio  📖 Tafsir  ⊞ Page  │  ← secondary row, muted
└─────────────────────────────────┘
```

### 3.2 — Ayah card redesign

The current per-ayah view uses `_SectionCard` wrappers with labeled sections. Replace with a single scrollable card:
- Arabic text at top, large (32px Lateef, line-height 2.0)
- Translation below with a subtle divider, smaller (14px)
- No section labels competing — the hierarchy speaks for itself

### 3.3 — Swipe gesture for navigation

Add horizontal swipe gesture to the ayah card (left = next, right = previous). Replaces the explicit Prev/Next buttons as the primary navigation — buttons remain but become subtle icon buttons.

### 3.4 — Secondary actions row

Replace the current view-mode toggle icon button with a three-icon row at the bottom:
- 🔊 Audio (opens inline player below card, not a new screen)
- 📖 Tafsir (expands inline below card, same as current `CommentarySection`)
- ⊞ Page view (navigates to page context mode — keep as secondary, not default)

These are subdued (grey icons, no labels by default). They do not compete with Mark Complete.

### 3.5 — Mark Complete feedback

On tap: soft haptic + ayah card briefly glows gold border + progress bar animates smoothly to new value. Then auto-advance to next ayah with a fade transition. No dialog unless it's the final ayah.

---

## Phase 4 — Progressive Disclosure System

*Features unlock in layers. Nothing is removed — everything is withheld until relevant.*

### 4.1 — Unlock state storage

Add a `UserProgressionState` to Hive local storage with boolean flags:

```dart
class UserProgression {
  bool hasStartedJourney;      // Day 0 — set on first journey creation
  bool hasCompletedFirstAyah;  // Phase 1 → 2 gate
  bool hasShownConsistency;    // Phase 2 → 3 gate (3+ days with activity)
  bool hasCompletedJourney;    // Phase 3 → 4 gate + unlocks custom creation
}
```

### 4.2 — Gate enforcement

| Feature | Unlocks when |
|---|---|
| Progress visualization (dot grid, surah rings) | After first ayah marked complete |
| Page context mode | After first ayah marked complete |
| Companions tab / social features | After 3 days of activity |
| Group journeys | After 3 days of activity |
| Contributions section | After first journey completed |
| Custom journey creation | After first journey completed |

Implementation: wrap gated UI in a `_FeatureGate` widget that shows a subtle "Keep going to unlock" placeholder instead of the feature.

### 4.3 — Activity tracking

Increment a daily activity counter (stored in Hive) whenever `updateProgress` is called. Check on app open whether the `hasShownConsistency` threshold (3 distinct calendar days) has been reached.

---

## Phase 5 — Social UI Containment

*Companions should feel like quiet co-travel, not a leaderboard.*

### 5.1 — Hide companion activity by default

On `UserProfileScreen` and the group journey members section: show only completion counts, not real-time progress differences. No "X is 5 ayahs ahead of you" language.

### 5.2 — Companion screen simplification

The current `CompanionsScreen` has an Add Companion button + bell icon with badge + list. Keep the function, simplify the visual:
- Remove the badge-heavy bell icon from AppBar
- Incoming requests: shown as a quiet card at the top of the companions list, not a separate screen navigation
- Activity feed style: "Abdullah completed 3 ayahs today" — one line, no avatars competing

### 5.3 — Nudge: reframe the copy

Current: "Nudge sent to [name]!" — feels pushy.
New: "A gentle reminder sent." — calm, non-transactional.

### 5.4 — Group journey detail

The member progress section currently shows all members in a list with progress bars. Keep the data, soften the presentation:
- No percentage labels next to each member (too comparative)
- Show completion count only: "14 ayahs"
- Nudge button tooltip: "Send a gentle reminder" not "Nudge [name]"

---

## Phase 6 — Navigation & Information Architecture

### 6.1 — New navigation structure

```
Home (no bottom nav)
 ├── Current Journey Card → Journey Study Screen
 ├── Avatar tap → My Profile
 ├── "Start a Journey" → Template Screen → Journey Study Screen
 └── "View Companions" (Phase 3+) → Companions Screen
      └── Companion name → User Profile Screen
           └── Journey tile → Journey Detail Screen

Journey Detail Screen (settings, members, alarms)
 └── "Continue" → Journey Study Screen
```

The `JourneyListScreen` becomes a secondary screen, accessible from profile or a "My Journeys" link — not a tab.

### 6.2 — Remove contributions from primary navigation

`audio_surahs_screen.dart`, `audio_files_screen.dart`, `community_audio_picker.dart`, `new_audio_screen.dart` — these are contribution-management screens. Move them behind a "Contributions" entry in the profile screen (Phase 4 unlocked), completely out of the home flow.

### 6.3 — Profile screen becomes the settings hub

My Profile screen contains:
- User info (name, username, avatar)
- My Journeys (link to `JourneyListScreen`)
- Contributions (Phase 4+)
- Settings (alarm defaults, text size, etc.)
- Sign out

---

## Phase 7 — Motion & Feedback Polish

*The app should feel like it breathes.*

### 7.1 — Transitions

Replace all `MaterialPageRoute` push transitions with custom `PageRouteBuilder` using a fade + slight upward slide (300ms, `Curves.easeOutCubic`). This is a single wrapper (`AppRoute`) used everywhere.

### 7.2 — Ayah completion animation

After tapping Mark Complete:
1. Border of ayah card glows gold for 300ms (AnimatedContainer)
2. Progress bar fills smoothly (TweenAnimationBuilder, 400ms)
3. Card fades out and next ayah fades in (200ms)

### 7.3 — Progress bar

Replace all `LinearProgressIndicator` with a custom `AnimatedProgressBar` widget that smoothly tweens between values instead of jumping.

---

## Phase 8 — Empty States & Copywriting

Replace all generic empty states with calm, directional prompts:

| Screen | Current | New |
|---|---|---|
| Home, no journeys | "No journeys yet" + icon | "Begin with a short journey. Consistency matters more than speed." |
| Companions, none | "No companions" + inbox icon | "Companions join you on the path. Invite someone when you're ready." |
| Incoming requests, none | "No incoming requests" | "No requests right now." |
| Journey list, empty | existing `JourneyEmptyState` | Replace with template prompt |

---

## Execution Order

Phases should be executed in this order to avoid rework:

1. **Phase 0** — Design foundation (colors, typography, spacing). All other phases depend on this.
2. **Phase 3** — Journey study screen (the heart — most used screen, highest impact).
3. **Phase 1** — Home screen overhaul (entry point, depends on Phase 0 tokens).
4. **Phase 2** — Journey templates (depends on Phase 1 being clean).
5. **Phase 6** — Navigation restructure (depends on Phases 1–3 being stable).
6. **Phase 4** — Progressive disclosure (add unlock gates after nav is stable).
7. **Phase 5** — Social containment (companion UI polish).
8. **Phase 7** — Motion & polish (do last — easiest to add once structure is right).
9. **Phase 8** — Copy & empty states (can be done in parallel with any phase).

---

## What Is Not Changing

- All backend API calls — no changes to repositories or cubits
- The data model (Journey, JourneyMember, etc.)
- Auth flow (login screen)
- Alarm scheduling logic
- Markdown commentary rendering
- The `quran` package integration (Arabic text, translation, page viewer)

---

## Files That Will Change Significantly

| File | Nature of change |
|---|---|
| `lib/resources/colors.dart` | Full rewrite — new token system |
| `lib/main.dart` | Theme, home screen layout, remove bottom nav |
| `lib/screens/quran_journey_screen.dart` | Layout restructure, swipe gestures, completion animation |
| `lib/screens/journey_list_screen.dart` | Demoted to secondary screen |
| `lib/screens/create_journey_screen.dart` | Demoted — expert path only |
| `lib/screens/companions_screen.dart` | Simplification, inline requests |

## Files Being Added

| File | Purpose |
|---|---|
| `lib/screens/journey_template_screen.dart` | Template-first journey creation |
| `lib/shared/progression/user_progression.dart` | Local unlock state tracking |
| `lib/widgets/animated_progress_bar.dart` | Smooth progress animation |
| `lib/widgets/app_route.dart` | Unified page transition wrapper |
| `lib/shared/constants/app_sizes.dart` | Spacing/radius constants |

