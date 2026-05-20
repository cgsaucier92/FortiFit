# SCREENS.md: FitNavi Screen Definitions

> Full layout descriptions, state tables, and interaction details for every screen.
> For data models, see `PRD.md` Section 5. For algorithms, see `SERVICES.md`. For constants, see `CONSTANTS.md`.

---

## Standard Patterns

These patterns are referenced throughout. Implement once, reuse everywhere.

**Delete Confirmation:** Alert title "Delete [Item Name]?" with body "This cannot be undone." Two actions: "Cancel" (default) and "Delete" (destructive, red). Cancel dismisses without action.

**Ellipsis Menu:** Blue ellipsis icon (16px). Tapping opens dropdown menu. Menu dismisses on outside tap.

**Long-Press Tease:** Cards that support long-press context menus (Workout Type cards, Home widgets, Goal cards, Trends chart cards, Saved Template cards, Scheduled Workout cards) share a single tease animation — a slight lift/scale on press hold that signals an imminent context menu. Implementation reuses the Home widget tease — do not invent a new animation curve.

**Standard Reorder Edit Mode:** Activated from a context menu "Reorder [Items]". Drag handles (≡, muted, 16px) appear on the right of each card. Long-press anywhere on a card to pick up — held card elevates with shadow, others animate to make room (0.2s ease), drop snaps into place. `sortOrder` re-indexes from 0 and persists on drop. Long-press context menu disabled during reorder. Exit by tapping outside any card (no "Done" button). Single-card case: enterable but drag has no visible effect.

Home widgets use a delete + drag combined variant — see § Home Screen → Widget Edit Mode.

**Standard Sortable Card System:** Backs Home widgets and Trends charts (SwiftData records — `HomeWidget`, `TrendsChart` — with `sortOrder`). Shared behavior:
- First launch seeds default cards in a defined order; user controls afterward.
- Cards render vertically in ascending `sortOrder`.
- **Add Menu:** opened from the screen's ellipsis. Centered overlay, dimmed bg, scrollable list of all card types. Each row: display name, brief description (muted), "Add" button. Already-added types show muted "Added" instead. Tap "Add" → creates record at max+1, dismisses, renders with live data (or empty state if data thresholds unmet).
- **Delete:** long-press → context menu → "Delete [Item]" → standard delete confirmation. Removes record only; no underlying data affected. Remaining cards re-index `sortOrder`.
- **Reorder:** long-press → context menu → "Reorder [Items]" → Standard Reorder Edit Mode.
- **All Removed state:** centered muted message inviting use of the ellipsis. Ellipsis + non-card chrome stay accessible.

Each screen specifies only seed defaults, card definitions, and deviations.

**Scroll Fade Header:** Floating header overlay that fades content scrolling beneath it.
- Structure: `ZStack(alignment: .top)` with `ScrollView` (`.scrollClipDisabled()`) + fixed header `VStack` on top. Scroll content uses `.padding(.top, headerHeight)` measured via `GeometryReader`.
- Header bg: `FortiFitColors.background.opacity(0.90)`. Below the header, a 30pt `LinearGradient` fades to `.clear` (`.allowsHitTesting(false)`).
- Header holds only top-level action buttons (back, ellipsis, plus, share/edit/delete); screen headings (`FortiFitScreenHeading`) live in scroll content.
- FortiFitDivider in header: kept on form/detail screens (Log Workout, Create Workout Template); removed on list/tab screens (Home, Workouts, Plan, Plan Workout, Trends, Goals, Workout Templates, Create Goal, Workout Detail).
- Empty states use `.padding(.top, headerHeight)`.

**Peripheral Apple Workout Label:** Inline "Apple Workout" text alongside workout metadata on compact surfaces. `bodySmall` / muted to match surroundings.

- **Scope:** renders only when `workout.healthKitUUID != nil` AND `HealthKitClient.sourceName(for:)` returns `Apple Workout` (i.e., the source is Apple Watch). Other HK sources (Strava, Peloton, etc.) render no label on peripheral surfaces — visually indistinguishable from manual workouts there.
- **Position:** trailing metadata on the date row (Home) or duration/distance row (Workouts), separated by ` · `. Always the last token on its row.
- **Examples:** `Apr 23, 2026 · Apple Workout` (Home); `45 min · Apple Workout` (Workouts); `Apr 23, 2026` (manual, no label).
- **Used on:** Home Recent Workouts rows; Workouts expanded preview rows; Plan logged-only and Apple-Watch-linked completed scheduled cards.
- **Not used on:** Workout Detail (uses the full Source Indicator instead — see § Workout Detail), Log Workout (uses disabled fields + popovers — see § Log Workout HK-Linked Workouts), Trends, Goals, widget bodies.

**See Info Modal:** Shared explainer sheet for a single feature. Opened via long-press context menu → "See Info" (SF Symbol `info.circle`). Used by Trends chart cards (Strength Tracker, Training Frequency, etc.) and Home widgets (Training Load, Power Level, Activity Rings).

**Component:** `FortiFitSeeInfoModal.swift`. Takes a content struct (`title`, `intro`, `sections: [(heading, body)]`). Content sourced from INFO_COPY.md — Chart entries for Trends, Widget entries for Home widgets. Strings always read from `AppConstants`; never hardcoded.

**Presentation:** iOS modal sheet, `.large` detent, swipe-down dismiss, Card Surface bg.

**Layout:**

| Element | Treatment |
|---|---|
| Header | Centered title "About [Subject]" (Primary Text, heading typography per PRD § 2). Matches Match Prompt Sheet header style. |
| Close button | Top-right 24×24pt circular, Elevated Surface bg + Border, muted `×`. Reused across this modal, the QR Modal, and Settings widget modals. ID `seeInfoModal_closeButton`. |
| Body | Scrollable. Intro paragraph (Secondary Text 14px, no preceding heading) + named sections (15px/800 heading, Secondary Text body). Body may contain bullet lists — bullets are parsed from source-string `- ` prefixes and rendered by the component (don't pre-format in constants). |
| Footer | None — ends after last section + safe-area padding. |

**Accessibility:** title announced first; section headings traverse as headers (`accessibilityAddTraits(.isHeader)`); close button reads "Close, button".

**Back Navigation Chevron:** Every drill-down screen (Workout Detail, Edit Workout, Create Workout Template, Workout Templates, Create Goal, Plan Workout, Settings, Trends Chart Detail, etc.) uses a single shared back control — a blue left-pointing chevron at the top-leading edge of the screen.

| Property | Value |
|---|---|
| SF Symbol | `chevron.left` |
| Color | Primary Accent Blue `#3b82f6` |
| Tap target | 24×24pt circular, 44×44pt hit area (Apple HIG) |
| Position | Top-leading, inset under the Scroll Fade Header (when present) |
| Action | Pops one level on the navigation stack. Left-to-right edge-swipe-back also dismisses, restored via the `.swipeToDismiss()` view modifier (`Core/Utilities/Extensions/ViewExtensions.swift`) — required because every drill-down screen sets `.toolbar(.hidden, for: .navigationBar)` to make room for its custom header, which otherwise suppresses the built-in interactive pop. Exception: Trends Chart Detail does not support edge-swipe-back — see § Trends Chart Detail. |
| Identifier convention | `{screenId}_backButton` — e.g., `workoutDetail_backButton`, `trendsChartDetail_strengthTracker_backButton` |
| VoiceOver label | "Back, button" |

Replaces the previously documented "← BACK" text button. Any earlier reference to `← BACK` in this doc points to this pattern.

**Watch Sync Card Glyph:** Shared component (`FortiFitWatchSyncGlyph` in `Design/Components/`) used to indicate and toggle a `ScheduledWorkout`'s Apple Watch push state on Plan cards (Plan screen) and the Edit Planned Workout screen. SF Symbols + color treatment per CONSTANTS.md § Watch Sync Glyph. (Component name retains "Sync" for code-level continuity; user-facing copy uses "Push" — see CONSTANTS.md § Apple Watch Strings.)

| State | SF Symbol | Color | Opacity | Tap behavior |
|---|---|---|---|---|
| Active (synced) | `applewatch.watchface` | Watch Sync Green | 1.0 | Toggle off — optimistic UI flips immediately, `WatchScheduleService.removePlan(_:)` fires async, error toast on failure (glyph stays inactive — intent matches visible state). |
| Inactive (not synced, gates pass) | `applewatch.slash` | Muted Text | 1.0 | Toggle on — optimistic UI flips immediately, `WatchScheduleService.schedule(_:)` fires async, glyph reverts on error with toast (intent retained). |
| Disabled (gates fail or master off or auth denied) | `applewatch.slash` | Muted Text | 0.4 | Show contextual popover explaining the gate failure (see CONSTANTS.md § Apple Watch Strings). Does not flip the underlying flag. |

**Gating conditions** (all must hold for the glyph to be in active or inactive state, not disabled): `UserSettings.syncPlanToAppleWatchEnabled == true` (master on), WorkoutKit auth granted, `scheduledWorkout.scheduledDate >= today`, snapshot decodes to ≥1 exercise. See WORKOUTKIT.md § 7 for full gate semantics. Note: `scheduledTime` is not a gate — when nil, the service falls back to noon for the WorkoutKit API call.

The glyph is positioned in the upper-right corner of any card hosting it (44×44pt minimum tap target, glyph 24×24pt centered). Identifier convention: `{screenContext}_watchSyncGlyph` — e.g., `scheduledWorkoutCard_{index}_watchSyncGlyph`, `editScheduledWorkout_watchSyncToggle`.

**Master Sync Off Popover:** Shared popover affordance triggered when the user taps any Watch Sync surface (card glyph, Edit Planned Workout toggle) while `UserSettings.syncPlanToAppleWatchEnabled == false`. Single SwiftUI `.popover` with the copy below, anchored to the tapped element. ID `masterSyncOff_popover`.

> **Push to Apple Watch is off**
>
> Turn it on in Settings to push this workout to your Apple Watch.
>
> [Open Settings]

The "Open Settings" button (ID `masterSyncOff_openSettingsButton`) navigates **in-app** to Settings → Apple Watch section via `NavigationPath` push (not iOS Settings). This is distinct from the auth-denied "Open iOS Settings" button which deep-links via `UIApplication.openSettingsURLString`. When the user is on the master-on but auth-denied path, the popover instead surfaces auth-denial copy and the iOS Settings deep-link.

Tap-outside dismisses. Does not flip the underlying per-card `syncToAppleWatch` flag (the user's intent is preserved; only the gate is the obstacle).

**Home Widget Tap-to-Open (Phase 8.8):** Every Home widget card opens a per-widget detail sheet on tap. Tap routing lives in `HomeWidgetService.detailSheet(for:)` (see SERVICES.md § HomeWidgetService → Widget Tap Routing); presentation reuses the Activity Detail Sheet conventions (iOS modal sheet, `.large` detent, swipe-down dismiss, drag indicator visible, Card Surface bg, close button top-right). Per-widget routing:

| Widget | Tap behavior |
|---|---|
| Today's Plan | Opens Today's Plan Detail Sheet (§ below) regardless of populated/completed/empty state. |
| Training Load | Opens Training Load Detail Sheet (§ below). |
| Weekly Streak | Opens Weekly Streak Insights Sheet (§ below). |
| Power Level | Opens Power Level Breakdown Sheet (§ below). |
| Activity Rings | Live state → Activity Detail Sheet (existing, § below). `Connect Apple Health` state → navigates to Settings → Apple Health (existing behavior, unchanged). `Pair an Apple Watch` state → no-op (existing behavior, unchanged). |

**Edit-mode suppression:** Tap-to-open is suppressed when the home is in Widget Edit Mode (`HomeViewModel.isEditMode == true`). Taps in edit mode reach the existing delete-and-drag chrome only — no detail sheet opens. Long-press context menus remain the entry point for `See Info`, `Configure Settings`, `Complete Workout`, `Reorder Widgets`, and `Delete Widget` on every widget, in every mode.

**Footer button block (shared across the four new detail sheets and the Activity Detail Sheet retrofit):** When a sheet has both `See Info` and `Configure Settings` entries available, they render as side-by-side text buttons in the sheet footer, separated by a `·`. Primary Accent Blue `#3b82f6`, 13px / 600 weight, ~44pt vertical tap target each. When only one entry applies (e.g., Power Level has no settings modal), that single entry renders alone, centered. Tapping either dismisses the detail sheet and opens the corresponding modal — never stacked sheet-on-sheet. Identifier convention: `{widgetDetailSheetId}_seeInfoButton`, `{widgetDetailSheetId}_configureSettingsButton`.

---

**Trends Chart Card Visual Treatment:** Shared visual styling for every chart card on the Trends screen. Implemented via `FortiFitChartCard` (Design/Components/), which wraps `FortiFitCard` and composes a gradient backdrop, inner plot hairline, header summary block, latest-point highlight, rounded bar tops, smoothed line interpolation, donut center label, and tap-to-select state. Per-chart values (gradient anchor, header summary formula, selection availability) live in CONSTANTS.md § Trends Chart Visual Tokens — never hardcoded in views.

**Component:** `FortiFitChartCard.swift`. Public API takes `chartId: ChartType`, `title: String`, `summary: ChartSummary?`, `gradientAnchor: ChartGradientAnchor`, plus `@ViewBuilder` slots for controls (toggles, dropdowns), the chart marks themselves, and an optional footer (legend).

**Layout (top-to-bottom):**

| Slot | Content |
|---|---|
| Title row | Existing chart title; preserves chart-specific affordances (e.g., dropdown chevron on Strength Tracker / Personal Records). |
| Header summary | Hero value + caption per CONSTANTS.md § Trends Chart Visual Tokens → Header Summary Block. Hidden on empty state. The Workout Type Breakdown chart suppresses this slot — its summary lives inside the donut (see § Donut Center Label). |
| Controls row | Existing toggles (30D/60D/90D, exercise dropdowns). Unchanged. |
| Plot area | Gradient backdrop + inner hairline + chart marks per CONSTANTS.md § Trends Chart Visual Tokens. |
| Footer | Existing legend / reference-line callouts. Unchanged. |

**Empty state:** When the chart's data threshold is not met (CONSTANTS.md § Chart Data Thresholds), the gradient, hairline, header summary, plot marks, and (on Workout Type Breakdown) donut center label all hide; the existing centered muted empty message renders inside the card. Controls row hides as well per existing per-chart empty-state behavior.

**Accessibility:** When the header summary is visible, its hero + caption are announced first as a single label (`"{hero}, {caption}"`). The chart marks then follow per Swift Charts' default accessibility behavior.

---

## Home Screen

**Purpose:** Central hub showing training status, quick stats, and access to logging. Fully customizable widget layout.

### Widget Card System
Per § Standard Patterns: Sortable Card System, backed by `HomeWidget` records. Default seed order (first launch only): **Today's Plan, Training Load, Power Level**. Add-only (not in default seed): **Weekly Streak**, **Activity Rings**. The previously-seeded Workout Info widget has been removed from the product entirely — see § Widget Definitions below and CONSTANTS.md § Widget Types. Home's edit mode is a variant of the standard — see § Widget Edit Mode below.

### Layout
Top: Left: blue ellipsis icon (functional — opens Home ellipsis menu). Right: blue gear icon (→ Settings). ✦ divider. Widget cards render vertically by `sortOrder`. Full-width blue-outlined "+ Log Workout" button below last widget. "Recent Workouts" header, then list of 5 most recent workouts. Each row has three lines: (1) workout name, (2) date with trailing "Apple Workout" text label when Apple-Watch-sourced (see § Standard Patterns → Peripheral Apple Workout Label) — e.g., `Apr 23, 2026 · Apple Workout`, (3) duration if recorded (e.g., `45 min`). Trailing chevron (>). Other HK sources and manual workouts render no peripheral label. Duration row is omitted when not set. Recent Workouts list and "+ Log Workout" are unaffected by widget customization.

### Home Ellipsis Menu
One option: **"Add Widgets"** with SF Symbol `plus.rectangle.on.rectangle` to the left → opens Add Widgets Menu overlay.

### Add Widgets Menu
Per § Standard Patterns: Sortable Card System → Add Menu.

### Widget Context Menu (Long Press)
Long-pressing any widget card (uses Standard Long-Press Tease) opens a context menu. Items render top-to-bottom in the order below. "Complete Workout", "See Info", and "Configure Settings" are conditional — they only appear on the widgets and in the states noted.

**"Complete Workout":** SF Symbol `checkmark.circle` to the left of the label (see CONSTANTS.md § Widget Context Menu SF Symbols). Visible **only on the Today's Plan widget**, and **only when one or more uncompleted `ScheduledWorkout` records exist for today** (i.e., the same condition that drives the left column's workout name and silhouette). Tapping opens the same compact confirmation sheet used by the Plan tab's Complete Planned Workout flow (see SCREENS.md § Plan → Complete Planned Workout Flow). On confirm, the widget's left column repopulates with the next planned workout for today — same auto-repopulation logic as before. When no uncompleted scheduled workout exists today (no plans, all completed, or every plan has been skipped), the menu item is **hidden entirely** — never rendered as a disabled/grey item. Accessibility identifier `homeWidget_todaysPlan_completeWorkoutMenuItem`.

**"See Info":** SF Symbol `info.circle` to the left of the label (see CONSTANTS.md § Widget Context Menu SF Symbols). Visible only on Training Load, Power Level, and Activity Rings widgets — opens the See Info Modal (see § Standard Patterns) populated from INFO_COPY § Widget Info Modal Copy for that widget. Not rendered on Weekly Streak or Today's Plan widgets.

**"Configure Settings":** SF Symbol `gear` to the left of the label. Visible only on Training Load, Weekly Streak, and Activity Rings widgets — opens that widget's existing settings modal (Training Load Settings Modal, Weekly Streak Settings Modal, or Activity Rings Settings Modal — see § Widget Definitions). Not rendered on Power Level or Today's Plan widgets.

**"Reorder Widgets":** Enters Widget Edit Mode (see below). Always visible regardless of widget count.

**"Delete Widget":** Standard delete confirmation for the long-pressed widget. Removes the `HomeWidget` record, removes the card, re-indexes remaining `sortOrder`. No underlying workout data affected.

**Resulting menus by widget type:**
- **Training Load:** See Info → Configure Settings → Reorder Widgets → Delete Widget (4 items)
- **Power Level:** See Info → Reorder Widgets → Delete Widget (3 items)
- **Weekly Streak:** Configure Settings → Reorder Widgets → Delete Widget (3 items)
- **Today's Plan (with uncompleted plan today):** Complete Workout → Reorder Widgets → Delete Widget (3 items)
- **Today's Plan (no uncompleted plan today):** Reorder Widgets → Delete Widget (2 items)
- **Activity Rings:** See Info → Configure Settings → Reorder Widgets → Delete Widget (4 items)

### Widget Edit Mode
Entered via the context menu's "Reorder Widgets" item. Unlike the standard reorder pattern, Home combines delete + drag in a single edit mode:
- "x" button appears in top-right of each widget (24x24pt circular, #2d2d2d bg, #404040 border, muted "×"). Tapping deletes the `HomeWidget` record, removes the card, re-indexes remaining `sortOrder`.
- Cards are draggable with the same drag physics as Standard Reorder Edit Mode (0.2s ease, sortOrder re-indexed on drop).
- Cards maintain full styling during edit and drag.
- Long-press context menu is disabled during edit mode.
- Exit by tapping outside any widget. "x" buttons fade out (0.15s).

### Widget Definitions

**Training Load** (`trainingLoad`): Blue-bordered card. "Training Load" header + zone label (e.g., "Moderate") + gradient progress bar (LOW→HIGH) + context-aware advisory below. Advisory uses readiness variant (no workout today) or post-training variant (trained today) — see CONSTANTS § Training Load Zones / Advisory Text. Algorithm: SERVICES § Training Load. **Tap** → Training Load Detail Sheet (§ below). **Long-press** → "See Info" (INFO_COPY § Training Load) or "Configure Settings" → Training Load Settings Modal. Updates in real time on workout log/edit/delete. Tap-to-open is suppressed in Widget Edit Mode (§ Standard Patterns → Home Widget Tap-to-Open).

**Training Load Settings Modal:** Centered modal, dimmed bg. "Configure Training Load" heading + "?" tooltip. Two slider cards: Training Experience (3-position: Beginner/Intermediate/Advanced) and Target Workout Duration (0–300 min, fallback for the Training Load algorithm). Changes apply immediately; experience change triggers recalc. Bottom action row: full-width **`Done` button** (outlined Primary Accent Blue, copy from CONSTANTS § Settings Modal Done Button) dismisses the modal — same dismiss path as the close X. Dismiss: Done button, close button (top-right `xmark`), or outside tap. ID `trainingLoadSettings_doneButton`.

**Weekly Streak** (`weekStreak`): "Weekly Streak" card. Left: animated blue flame SVG scaling by tier (1.2s flicker loop). Right: streak count (32px, 900 weight) + "WEEK STREAK" label (blue uppercase) + motivational message (muted italic). See CONSTANTS § Streak Flame Tiers / Streak Motivational Messages and SERVICES § Streak Algorithm. **Tap** → Weekly Streak Insights Sheet (§ below). **Long-press** → "Configure Settings" → Weekly Streak Settings Modal. Tap-to-open is suppressed in Widget Edit Mode (§ Standard Patterns → Home Widget Tap-to-Open).

**Weekly Streak Settings Modal:** Centered modal, dimmed bg. "Configure Streak Widget" heading. Single slider: Target Workouts per Week (0–99). Used exclusively by the Streak algorithm. Changes apply immediately and recalculate streak retroactively. Bottom action row: full-width **`Done` button** (outlined Primary Accent Blue, copy from CONSTANTS § Settings Modal Done Button) dismisses the modal — same dismiss path as the close X. Dismiss: Done button, close button (top-right `xmark`), or outside tap. ID `weeklyStreakSettings_doneButton`.

**Power Level** (`powerLevel`): Blue-bordered card. "Power Level" header + status label (Deloading/Steady/Rising) + directional indicator (↓/—/↑, status-colored) + contextual message (muted italic). See CONSTANTS § Power Level Statuses and SERVICES § Power Level Algorithm. **Tap** → Power Level Breakdown Sheet (§ below). **Long-press** → "See Info" (INFO_COPY § Power Level). Tap-to-open is suppressed in Widget Edit Mode (§ Standard Patterns → Home Widget Tap-to-Open).

**Today's Plan** (`todaysPlan`): "Today's Plan" header. Two-column card.

**Left column (workout info):**
- ≥1 uncompleted workout today → first one's template name (Primary Text). Below: muted "X more planned" if additional workouts remain. Completion happens via long-press → "Complete Workout" (no inline button, no workout-type pill). On completion, widget auto-repopulates with the next planned workout same day.
- All today's workouts completed → "All planned workouts completed." (muted, green checkmark).
- No workouts scheduled → "No workout planned for today." (muted).

**Background silhouette (left column):** When a planned workout exists today, render the workout type's SF Symbol (CONSTANTS § Workout Type SF Symbols) as a watermark behind the workout name. Muted Text at 20% opacity. ~140pt symbol against ~100pt column so the icon bleeds top/bottom — `.scaledToFit()` + explicit `.frame(140×140)`, ZStack centered, clipped by the parent card. Hidden in completed / empty / no-plan states. ID: `homeWidget_todaysPlan_silhouette` (rendered only when a planned workout exists; tests assert presence/absence by state).

**Right column (calendar square):** Always visible. Rounded rectangle styled after the iOS Calendar icon in FitNavi colors — Primary Accent Blue top bar with day abbreviation (white, bold uppercase), dark body with month + date number (Primary Text, large). Below the date: blue dot = planned `ScheduledWorkout`, green dot = completed (scheduled OR logged-only surfaced on Plan; see § Plan → Logged-Only Workout Surfacing). Logged-only workouts do **not** appear in the left column — that area remains scoped to `ScheduledWorkout` records.

**Tap** → Today's Plan Detail Sheet (§ below). Opens in all states (populated, all-completed, empty). Tap-to-open is suppressed in Widget Edit Mode (§ Standard Patterns → Home Widget Tap-to-Open). **Long-press** → "Complete Workout" (when an uncompleted plan exists today) → compact confirmation sheet (existing behavior, see § Widget Context Menu).

Included in default widget set; also available via Add Widgets menu.

**Activity Rings** (`appleActivity`): "Activity Rings" header. Two-column card. Add-only — always offered in the Add Widgets menu regardless of HK/Watch state.

**Layout:**

| Region | Content |
|---|---|
| Left column | Three stacked entries (Move, Exercise, Stand). Each: chevron icon (CONSTANTS § Activity Rings → Ring Chevron SF Symbols) + uppercase label (Primary Text, label treatment) + hero `current/goal unit` value rendered in the ring's accent color (CONSTANTS § Activity Rings → Ring Colors), 20px heavy. |
| Right column | Three nested rings (Move outermost, Exercise middle, Stand innermost — matches Apple Fitness). Ring thickness ~10pt, ~2pt gap. Arcs start 12 o'clock, sweep clockwise. Center: abbreviated month (10pt) over day-number (18pt), both Muted Text. |
| Bottom chip | Weekly closure rate — `Closed all rings {n} day(s) this week`. Sourced from `AppleActivityService.closedAllRingsDayCount`. Hidden in non-live states. |

**Workout contribution caption (Move and Exercise only):** Below each fraction, if ≥1 HK-linked workout today contributes, render a muted single-line caption. One contributor: `+{value} from today's {workoutName}`. Multiple: `+{summed value} from today's workouts`. Manual logs (no `healthKitUUID`) never appear — they're not in HealthKit. Stand never renders this caption. Source: SERVICES § AppleActivityService.

**Over-100% behavior:** Replicates Apple Watch — once a ring hits 100%, a second arc layer continues drawing on top, sweeping from `(progress - 1.0)`. Implementation: two `Circle().trim(...).stroke(...)` per ring, base + overlay.

**All-rings-closed celebration:** When all three reach 100%, widget pulses (0.6s scale 1.0 → 1.05 → 1.0). Debounced — once per closure event per day; does not retrigger on subsequent foregrounds the same day.

**Tap (live state only):** Opens the Activity Detail Sheet (§ below).

**Long-press context menu (all states):** See Info, Configure Settings, Reorder Widgets, Delete Widget. Configure Settings is accessible even when HK/Watch unavailable; the "Import from Apple Health" button inside the modal is the only thing that disables.

**States** (gating logic in SERVICES § AppleActivityService → Apple Watch Empty-State Detection):

| `healthKitEnabled` | `appleWatchDetected` | What the user sees |
|---|---|---|
| false | (any) | **Connect Apple Health.** Muted gray ring outlines on the right. Left column shows centered message + small "Connect" text button (Primary Accent Blue) → deep-links to Settings → Apple Health. Tapping anywhere else on the card also navigates to Settings. Closure chip hidden. IDs: `homeWidget_appleActivity_state_connectAppleHealth`, `homeWidget_appleActivity_connectButton`. |
| true | false | **Pair an Apple Watch.** Same muted ring outlines. Centered message; no CTA (FitNavi can't pair watches). Tap is a no-op. Watch-detection cached per foreground session — a freshly paired Watch may need one background/foreground cycle to register. Closure chip hidden. ID: `homeWidget_appleActivity_state_pairAppleWatch`. |
| true | true | **Live rings.** Full layout above. IDs: `homeWidget_appleActivity_card`, `homeWidget_appleActivity_moveRing`, `homeWidget_appleActivity_exerciseRing`, `homeWidget_appleActivity_standRing`, `homeWidget_appleActivity_weeklyClosureChip`. |

**Add Widgets row description:** *"Tracks your daily Move, Exercise, and Stand rings. Requires an Apple Watch and Apple Health connected in Settings."* The Add button is always enabled — gating happens via the in-card states.

### Activity Rings Settings Modal

Centered modal, dimmed bg. Same visual treatment as Weekly Streak / Training Load Settings Modals. Long-press Activity Rings widget → "Configure Settings".

Heading: "Configure Activity Rings".

Body — three slider cards (track tints to ring accent color, white thumb):

| Card | Range | Label | Increment |
|---|---|---|---|
| Move | 1–2000 cal | `Move — {value} cal` | 10 |
| Exercise | 1–240 min | `Exercise — {value} min` | 5 |
| Stand | 1–24 hrs | `Stand — {value} hrs` | 1 |

Slider changes apply immediately to `UserSettings.targetMoveCalories` / `targetExerciseMinutes` / `targetStandHours` — no save button. Widget rings update on dismiss.

Action buttons (two, full-width, stacked, in this top-to-bottom order — Phase 8.8):
1. **"Import from Apple Health"** (blue-filled, **first position — directly below the Stand slider**). Calls `AppleActivityService.importGoalsFromAppleHealth()` (SERVICES § AppleActivityService → Goal Import). Sliders animate to imported values. Disabled when `healthKitEnabled == false` OR `appleWatchDetected == false`; disabled-state caption: *"Connect Apple Health to import your goals."* ID `activityRingsSettings_importButton`.
2. **"Done"** (blue-outlined, **second position — bottom of the modal; replaces the previous "Reset to defaults" button, which has been removed entirely in Phase 8.8**). Copy from CONSTANTS § Settings Modal Done Button. Dismisses the modal — same dismiss path as the close X. ID `activityRingsSettings_doneButton`.

Dismiss: Done button, close button (top-right `xmark`), or outside tap. No live ring preview in the modal.

> **Phase 8.8 note — Reset to defaults removed.** The previous "Reset to defaults" button (formerly `activityRingsSettings_resetButton`) has been removed entirely. Users who want to revert to FitNavi defaults can re-import from Apple Health (if their HK goals are at defaults) or adjust the sliders manually. The identifier `activityRingsSettings_resetButton` is retired and must not be reused.

### Activity Detail Sheet

Tap the Activity Rings widget in live state → opens `FortiFitActivityDetailSheet`. Pulls all data from `AppleActivityService` (never queries HK directly).

Presentation: iOS modal sheet, `.large` detent, swipe-down dismiss, Card Surface bg, drag indicator visible.

Header: centered title `Activity Insights`. Close button top-right (`xmark`, Muted Text). ID `activityDetailSheet_closeButton`.

Range toggle below header: segmented "7 days" (default) / "30 days". Tapping refetches and re-renders all blocks. IDs `activityDetailSheet_range7d`, `activityDetailSheet_range30d`.

Body — three sparkline blocks + one heatmap, scrollable. Each sparkline block is a FortiFitCard with a centered chevron-icon silhouette (100pt, ring color, 3% opacity) behind the chart:

| Block | Line color | Silhouette | Goal line at | Caption |
|---|---|---|---|---|
| Move sparkline | `#ef4444` | `chevron.right` | `targetMoveCalories` | `Last {7\|30} days · Move` |
| Exercise sparkline | `#10b981` | `chevron.right.2` | `targetExerciseMinutes` | `Last {7\|30} days · Exercise` |
| Stand sparkline | `#0845AD` | `chevron.up` | `targetStandHours` | `Last {7\|30} days · Stand` |

Sparkline structure: Swift Charts `LineMark` with each day a ~3pt filled circle; today's point is ~6pt Primary Accent Blue. Y-axis auto-scaled. Goal line is dashed Muted Text.

Ring closure heatmap (4th block): horizontal calendar strip (7 cells for 7-day, ~5×6 for 30-day). Cell fill: all three rings closed = Primary Accent Blue 100%; one or two rings closed = Primary Accent Blue 40%; none = Card Surface with border. Cell label: day-of-month (Primary Text 10px). Today's cell has Primary Accent Blue 1px outline. Caption: `Ring closure heatmap · last {7|30} days`. ID `activityDetailSheet_closureHeatmap`.

Empty / insufficient data: day with no HK summary → empty cell + 0 sparkline point. Range entirely empty → block-level fallback `Not enough data yet — wear your Apple Watch and check back.`

Tap behavior on cells / sparkline points: none in v1 (passive breakdown).

**Footer (Phase 8.8 retrofit):** Side-by-side `See Info` · `Configure Settings` text buttons per § Standard Patterns → Home Widget Tap-to-Open → Footer button block. `See Info` opens the Activity Rings See Info Modal (§ below); `Configure Settings` opens the Activity Rings Settings Modal (§ above). Both dismiss the Activity Detail Sheet first — never stacked sheet-on-sheet. IDs `activityDetailSheet_seeInfoButton`, `activityDetailSheet_configureSettingsButton`.

### Activity Rings See Info Modal

Standard See Info Modal (§ Standard Patterns). Content from INFO_COPY § Activity Rings. Title "About Activity Rings". Reuses `seeInfoModal_closeButton`.

### Today's Plan Detail Sheet

Opened by tapping the Today's Plan widget in any state (populated / all-completed / empty). Component: `FortiFitTodaysPlanDetailSheet.swift` in `Design/Components/`.

**Presentation:** iOS modal sheet, `.large` detent, swipe-down dismiss, drag indicator visible, Card Surface bg.

**Header:** Centered title `Today's Plan – {Month Day}` (e.g., `Today's Plan – May 17`). Close button top-right (`xmark`, Muted Text). ID `todaysPlanDetailSheet_closeButton`.

**Body — scrollable stack of mini-cards, one per `ScheduledWorkout` for today.** Sort: `Planned` and `Skipped` rows first, then `Completed` rows (mirrors the Plan tab day-detail stack order — finished work sinks to the bottom). Within each group, rows order by `scheduledTime` ascending (nil times sort last), then by `dateCreated`. Each mini-card is a `FortiFitCard`. **Card border:** Positive Green on `Completed` rows, default Border token otherwise — matches the Plan tab's `FortiFitScheduledWorkoutCard` border convention. Mini-card contains:

| Slot | Content |
|---|---|
| Top row | Workout-type SF Symbol (CONSTANTS § Workout Type SF Symbols, 18pt, type color) + template name (Primary Text 17/700) + status pill (right-aligned). Pill states: `Planned` (Primary Accent Blue outlined), `Completed` (Positive Green filled), `Skipped` (Muted Text outlined). |
| Meta row | Scheduled time (e.g., `7:30 AM`, hidden when nil) · estimated duration · `FortiFitWatchSyncGlyph` (Phase 8.7 — present only on Strength/HIIT since `ScheduledWorkout` is template-backed and templates are restricted to those two types per § Create Workout Template). `·` separated. All Muted Text 13px. |
| Exercise list | Per-exercise listing of the snapshot's `SnapshotExercise` entries (sorted by `sortOrder`). Same `exerciseName` entries are grouped under one header (exercise name in `FortiFitTypography.labelSmall` Primary Text); each group renders one line per `SnapshotExercise` set group below (`FortiFitTypography.labelSmall` Muted Text). Per-line format: `{sets} × {reps} reps[ · {weight} kg/lbs][ · rest {restSeconds}s]`. Time-based exercises render `{sets} × {reps}s` instead. **`displayAsTime` resolution:** explicit value on the snapshot wins; when nil, falls back to `ExerciseSuggestionService.isIsometric(exerciseName)` so isometric exercises (Planks, Dead Hang, etc.) and ambiguous-default-time exercises (Battle Ropes, Farmers Walks, etc.) still render as time even when the template author didn't toggle the REPS/TIME control. Weight is suppressed for bodyweight (`weightKg == nil` or 0). `restSeconds` segment appears only when present. Unit follows `UserSettings.useLbs`. Hidden when the underlying snapshot has no exercises. Replaces the previous summary row "`{n} exercises · {m} sets`" — full listing was added in response to user feedback that the summary obscured the workout's contents. |
| Action row | **`Complete Workout` button** (blue-filled, full-width within the card, Primary Accent Blue) on `Planned` rows. Tapping opens the **same compact confirmation sheet used by the Plan tab's Complete Planned Workout Flow** (§ Plan → Complete Planned Workout Flow) and the Today's Plan widget long-press flow (SERVICES.md § HomeWidgetService → Today's Plan — Complete Workout). On `Completed` rows: action row is **hidden entirely** — the green `Completed` pill in the top-right is the sole completion signal (removed the redundant bottom checkmark + label). On `Skipped` rows: action row hidden entirely (status pill is the only signal). ID `todaysPlanDetailSheet_row_{scheduledWorkoutId}_completeButton`. |

**Row tap (outside the Complete button):** Tap a `Planned` row → dismiss sheet, navigate to that workout's Schedule Workout sheet (existing flow per § Plan → Scheduling Flow). Tap a `Completed` row → dismiss sheet, navigate to the linked `Workout` Detail (existing § Workout Detail). Tap a `Skipped` row → no-op (status pill is the only signal).

**Completed-row visibility windowing:** Completed rows remain visible in this sheet **only on the day they were completed**. After local midnight rolls over, completed rows from the prior day no longer appear — the sheet renders only `ScheduledWorkout`s where `scheduledDate == today` (calendar-local), regardless of their status. This filter is identical for the populated and empty branches.

**Empty state (no `ScheduledWorkout` for today):** Centered Muted Text message: *"No workouts planned for today."* ID `todaysPlanDetailSheet_emptyState`.

> **Phase 8.8 follow-up — `+ Schedule another workout for today` chip removed.** The chip below the list (populated state) and below the empty-state copy (empty state) was removed entirely; users schedule additional workouts via the Plan tab. The identifier `todaysPlanDetailSheet_scheduleMoreButton` is retired and must not be reused.

**Footer:** This sheet has **no** `See Info` / `Configure Settings` entries (Today's Plan widget has neither a See Info Modal nor a Settings Modal). Footer area is empty padding.

**Reactivity:** Sheet subscribes to `PlanService` published changes — when a workout is completed from this sheet (via the Complete button → compact confirmation sheet), the row's status pill updates to `Completed`, the action button updates to the disabled-checkmark state, and the row stays in place. Other rows reorder if their relative `scheduledTime` ordering changed.

**Edit mode:** Tap on the Today's Plan widget is suppressed while the home is in Widget Edit Mode (§ Standard Patterns → Home Widget Tap-to-Open).

**Accessibility:** Sheet title announced first. Each row announces as `{template name}, {status}, {meta row}`. Complete button on planned rows announces as `Complete workout, button`.

### Training Load Detail Sheet

Opened by tapping the Training Load widget. Component: `FortiFitTrainingLoadDetailSheet.swift` in `Design/Components/`.

**Presentation:** iOS modal sheet, `.large` detent, swipe-down dismiss, drag indicator visible, Card Surface bg.

**Header:** Centered title `Training Load Insights`. Close button top-right (`xmark`, Muted Text). ID `trainingLoadDetailSheet_closeButton`.

**Body — scrollable, top-to-bottom:**

1. **Hero block.** Larger version of the Training Load gradient bar (`#10b981` → `#C4F648` → `#B7FF00` → `#ef4444` per CONSTANTS § Training Load Zones), zone label (e.g., `Moderate`), and numeric score below the bar in the format `{score} / 100`. Score color matches the zone. ID `trainingLoadDetailSheet_hero`.

2. **14-day daily score chart.** Swift Charts line chart of daily Training Load score over the last 14 calendar days (today inclusive). Reuses the visual treatment of the existing `trainingLoadTrend` Trends chart but at sheet-block scale — gradient backdrop per CONSTANTS § Trends Chart Visual Tokens → Gradient Anchor (`#3b82f6`), inner plot hairline, smoothed line (`.catmullRom`), latest-point highlight on today's point. **Range is fixed at 14 days — no toggle.** Daily point color matches its zone (low/moderate/high/peak). Y-axis 0–100. ID `trainingLoadDetailSheet_dailyChart`. **Tap-to-select + drag-to-scrub:** the chart supports the same selection interaction as `FortiFitChartDetailView` (Trends chart detail view) — tapping or dragging anywhere over the chart selects the closest data point by date, light haptic on selection change, dimmed non-selected line/points (line 55% opacity, non-selected points 35% opacity), selected point upsized (~96pt symbol), and a vertical `RuleMark` at the selected x. A selection annotation below the chart reads `{score} / 100 · {zone}` (left, zone-colored) and the date (right, Muted). Cleared when the user taps another point or the chart is re-rendered after a cascade. IDs `trainingLoadDetailSheet_chartDataPoint_{index}` per point and `trainingLoadDetailSheet_chartSelectionAnnotation` for the readout.

3. **Contributing workouts block.** Header: `Contributing this week`. List of workouts from the last 7 days that contributed to the current score, sorted by descending stress-load contribution. Each row: workout name (Primary Text 15/700) + date (Muted Text 13px) + percent share of the last-7-day stress-load total (`{percent}%`, Muted Text 13px) + inline horizontal share bar (~56×4pt, Primary Accent Blue fill on Elevated Surface track, capsule shape, filled to `{percent}%`). The absolute stress-load value per row is intentionally suppressed — it created a false expectation that rows sum to the hero score and rendered confusingly as "0 stress load · 5%" after integer rounding. Tap a row → dismiss sheet, navigate to that workout's Workout Detail. Max 5 rows; "See all in Trends →" link at the bottom navigates to Trends → Training Load Trend chart detail. ID `trainingLoadDetailSheet_contributingWorkouts`. Note: user-facing unit is **stress load** (Phase 8.8 rename from "TSS"); internal field is still `tssContribution`.

4. **Week-over-week comparison band.** Single-line `FortiFitCard`: `Stress load · {arrow} {abs(deltaPct)}% vs last week`. `arrow` is `↑` when up, `↓` when down, `—` when flat — matches the directional indicator convention used by the Power Level widget. Delta colored Positive Green when down (less stress), Alert Red when up (more stress) — counter-intuitive but matches recovery framing. The absolute current-week total is intentionally suppressed for consistency with the contributing-workouts rows (which dropped their absolute values for the same reason). ID `trainingLoadDetailSheet_weekComparison`.

5. **Recovery readiness callout.** Larger format of the existing zone advisory copy (CONSTANTS § Training Load Zones → Advisory Text). Renders the readiness variant when no workout has been logged today; the post-training variant otherwise. ID `trainingLoadDetailSheet_recoveryCallout`.

**Footer:** Side-by-side `See Info` · `Configure Settings` per § Standard Patterns → Home Widget Tap-to-Open → Footer button block. IDs `trainingLoadDetailSheet_seeInfoButton`, `trainingLoadDetailSheet_configureSettingsButton`. `See Info` opens the Widget Info Modal (INFO_COPY § Training Load); `Configure Settings` opens the Training Load Settings Modal.

**Per-block empty states (Phase 8.8 — partial data still feels rewarding):**

| Block | Empty trigger | Empty copy |
|---|---|---|
| Hero | Score = 0 (Resting) | Renders the bar at zero with `Resting` label and `0 / 100` value (not technically empty — uses the existing Resting state). |
| 14-day chart | Fewer than 3 days with ≥ 1 workout in the last 14 days | *"Not enough data yet to chart your daily training load. Keep logging."* (matches `trainingLoadTrend` chart threshold copy.) |
| Contributing workouts | No workouts in the last 7 days | *"No workouts in the last 7 days."* |
| Week comparison | Either current or previous week has 0 stress load | Hide block entirely (no comparison meaningful). |
| Recovery callout | Always renders — uses Resting copy if score = 0. |

**Whole-sheet empty state (cold-start):** When the user has fewer than 3 workouts logged in the last 14 days **AND** their training load score is 0, the per-block empty states above render together producing a quiet sheet. No separate hero replacement. Empty copy when literally no workouts have ever been logged: *"Log a few more workouts with exercises to see your training load breakdown."* (per Phase 8.8 requirements — replaces the chart-style empty message in the chart block only; the rest of the sheet uses the per-block table above). ID `trainingLoadDetailSheet_emptyState_coldStart`.

### Weekly Streak Insights Sheet

Opened by tapping the Weekly Streak widget. Component: `FortiFitWeeklyStreakDetailSheet.swift` in `Design/Components/`. **The animated flame is intentionally not rendered in this sheet** — it lives on the widget card. The sheet uses typographic, data, and badge treatments instead.

**Presentation:** iOS modal sheet, `.large` detent, swipe-down dismiss, drag indicator visible, Card Surface bg.

**Header:** Centered title `Streak Insights`. Close button top-right (`xmark`, Muted Text). ID `weeklyStreakDetailSheet_closeButton`.

**Body — scrollable, top-to-bottom:**

1. **Typographic hero.** Massive streak count (Primary Text, ~96pt / 900 weight, optional gradient fill Primary Accent Blue `#3b82f6` → `#93c5fd` per CONSTANTS § Weekly Streak Insights → Hero). Count-up animation on sheet open (0 → currentStreak over 0.6s, ease-out; skipped when `UIAccessibility.isReduceMotionEnabled == true`). Below: `WEEK STREAK` label (Primary Accent Blue, uppercase, 13px / 800, 2px letter spacing). ID `weeklyStreakDetailSheet_hero`.

2. **Stat row.** Three-column `FortiFitCard` row: `Current Streak` (left) · `All-Time Best` (middle, sourced from `StreakService.longestStreak`) · `Total Weeks Logged` (right, total count of historical weeks where target was met). Each column: large value (Primary Text 22/800) + small uppercase label (Muted Text 11/700, 2px letter spacing). ID `weeklyStreakDetailSheet_statRow`.

3. **This Week's Progress arc.** Single concentric progress ring (Primary Accent Blue, ~120pt outer diameter, ~12pt thickness, ~2pt inner gap). Filled arc reflects `current week workouts / targetWorkoutsPerWeek`. Center: `{count} / {target}` stacked over `WORKOUTS THIS WEEK` (Muted Text 11/700, 2px letter spacing). Below the ring: a single Muted Text 13px line: `{days remaining} day(s) left this week` (computed from the current calendar week's Sunday end-of-day). Reuses the Activity Rings ring rendering approach (no new ring primitive). ID `weeklyStreakDetailSheet_thisWeekRing`.

4. **History heatmap.** Calendar-style grid of the last **26 weeks** (fixed — no toggle). 4 columns × ~7 rows (oldest week top-left, dates ascend left-to-right then top-to-bottom; current in-progress week is bottom-right). Each cell ~32×32pt with a 4pt gap. Color ramp per CONSTANTS § Weekly Streak Insights → Heatmap Color Ramp:
   - Untracked / pre-app week → Card Surface + 1px border (`#404040`)
   - Below target (1 ≤ workouts < target) → Primary Accent Blue 25% opacity
   - Target met (workouts ≥ target) → Primary Accent Blue 100% opacity
   - Current week (in-progress) → outlined cell (1px Primary Accent Blue) with fill matching its current count band
   Cell number: day-of-Monday-start (Primary Text 10/600, centered). Tap any cell → `FortiFitTooltip` shows `{n} of {target} workouts · week of {Mon date}` (anchored above the cell, dismisses on outside tap). ID `weeklyStreakDetailSheet_heatmap`. Cell IDs `weeklyStreakDetailSheet_heatmap_cell_{0..25}` align with visual position (0 = top-left = oldest week; 25 = bottom-right = current in-progress week). Note: this is independent of the `StreakService.fetchHeatmap` data contract, which still returns index 0 = most-recent week — the view reverses for rendering.

5. **Milestone shelf.** Horizontal row of 5 SF Symbol badges at tier marks 1 / 4 / 12 / 26 / 52 weeks (per CONSTANTS § Weekly Streak Insights → Milestone Marks). Each badge: `trophy.fill` SF Symbol, ~36pt. Unlocked badges fill Primary Accent Blue; locked badges render outlined `trophy` in Muted Text. The **next-unlocked** badge (lowest tier ≥ `currentStreak`) gets a subtle 1px Primary Accent Blue ring + 6% blue card-surface wash as the visual anchor. Below each badge: small uppercase label (`1 WK`, `4 WKS`, `12 WKS`, `26 WKS`, `52 WKS`, Muted Text 10/700). Tapping a badge does nothing in v1 (passive). ID `weeklyStreakDetailSheet_milestoneShelf`. Per-badge IDs `weeklyStreakDetailSheet_milestone_{1|4|12|26|52}`.

**Footer:** `Configure Settings` text button (centered, alone — Weekly Streak widget has no See Info Modal). Tap → dismiss sheet, open Weekly Streak Settings Modal. ID `weeklyStreakDetailSheet_configureSettingsButton`.

**Per-block empty states (Phase 8.8):**

| Block | Empty trigger | Empty copy |
|---|---|---|
| Hero | `currentStreak == 0` | Render `0` count + flatter messaging beneath: `Hit your weekly target to start a streak.` (sourced from CONSTANTS § Streak Motivational Messages → tier 0; existing copy reused). |
| Stat row | All values 0 | Render zeros — block is informational, never hidden. |
| This Week's Progress | `targetWorkoutsPerWeek == 0` | Hide block entirely. Show inline note in its place: *"Set a weekly workout target in Configure Settings to see this week's progress."* |
| History heatmap | Fewer than 1 week of any workouts | Render the grid with all 26 cells in `Untracked` style + caption *"Log a workout to start your streak history."* |
| Milestone shelf | All locked | Renders normally — locked-only shelf is intentional motivation. |

**Whole-sheet cold-start:** When the user has logged zero workouts ever, the hero shows `0`, the stat row shows `0 / 0 / 0`, This Week's Progress and History heatmap show their per-block empty states, and the milestone shelf is fully locked.

### Power Level Breakdown Sheet

Opened by tapping the Power Level widget. Component: `FortiFitPowerLevelDetailSheet.swift` in `Design/Components/`.

**Presentation:** iOS modal sheet, `.large` detent, swipe-down dismiss, drag indicator visible, Card Surface bg.

**Header:** Centered title `Power Level Insights`. Close button top-right (`xmark`, Muted Text). ID `powerLevelDetailSheet_closeButton`.

**Body — scrollable, top-to-bottom:**

1. **Hero block.** Status label (`Deloading` / `Steady` / `Rising`, status-colored per CONSTANTS § Power Level Statuses) + large directional indicator (`↓` / `—` / `↑`, status-colored, ~48pt) + numeric `{current30dAvg} avg volume` line beneath in the user's weight unit (kg / lbs per `UserSettings.useMiles` adjacency — actually unit is kg under the hood, displayed via `UnitConversion.displayWeight(kg:)`). ID `powerLevelDetailSheet_hero`.

2. **30-day rolling volume chart.** Swift Charts line chart of daily volume sums (Strength + HIIT only) over the last 30 days. Reuses the `workoutVolume` Trends chart visual treatment at sheet-block scale (gradient anchor `#4B2893` Chart Purple per CONSTANTS § Trends Chart Visual Tokens, smoothed line, latest-point highlight). **Range fixed at 30 days — no toggle (matches the algorithm window).** Empty days render no point (gap in line). ID `powerLevelDetailSheet_volumeChart`.

3. **Top exercises driving the trend.** Header: `Driving your trend`. Up to 3 rows, one per top exercise by 30-day volume contribution, with the **≥ 3 in-window sessions filter applied** (per SERVICES § Power Level Algorithm → Top Contributing Exercises). Each row: exercise name (Primary Text 15/700) + `{deltaSign}{deltaPct}% volume vs previous 30d` (status-colored, right-aligned) + inline 30-day sparkline (~80×24pt, Primary Accent Blue, no marks). Tap a row → dismiss sheet, navigate to Trends → Strength Tracker chart detail pre-filtered to that exercise. **No-baseline rendering:** when `PowerLevelTopExercise.previousWindowVolume == 0`, the delta column renders an em-dash (`—`, Muted Text) instead of "+0%" — pairs with the `noBaseline` nudge copy (INFO_COPY § Power Level Nudge Copy → No Baseline) so the row and the message agree that no comparison is yet possible. ID `powerLevelDetailSheet_topExercises`. Per-row IDs `powerLevelDetailSheet_topExerciseRow_{0..2}`.

4. **Window comparison band.** Single-line `FortiFitCard`: `Current 30d: {currentAvg} · Previous 30d: {prevAvg} ({deltaSign}{deltaPct}%)`. Status-colored delta. ID `powerLevelDetailSheet_windowComparison`.

5. **Contextual nudge.** Single-line muted message generated by `PowerLevelService.computeNudge()` (SERVICES § Power Level Algorithm → Nudge Computation). Five archetypes (Deloading / Steady / Rising / ColdStart / NoBaseline) drive the copy; copy templates live in INFO_COPY § Power Level Nudge Copy. Italic Muted Text 14px. ID `powerLevelDetailSheet_nudge`.

**Footer:** `See Info` text button (centered, alone — Power Level widget has no Configure Settings Modal). Tap → dismiss sheet, open Widget Info Modal (INFO_COPY § Power Level). ID `powerLevelDetailSheet_seeInfoButton`.

**Per-block empty states (Phase 8.8):**

| Block | Empty trigger | Empty copy |
|---|---|---|
| Hero | Fewer than 3 Strength/HIIT workouts in the last 30 days | Render the status as `Steady` with `—` indicator + replace numeric line with *"Log a few more Strength or HIIT workouts to see your power level."* |
| Volume chart | Fewer than 2 Strength/HIIT workouts in 30d window | *"Log more Strength or HIIT workouts to display volume trends."* (matches `workoutVolume` chart threshold copy from CONSTANTS § Chart Data Thresholds.) |
| Top exercises | Fewer than 3 sessions on any single exercise in window | *"Log a few more sessions on the same exercises to surface your top drivers."* |
| Window comparison | Either window has 0 qualifying workouts | Hide block entirely. |
| Nudge | < 3 Strength/HIIT workouts in 30d window (cold-start) | *"Log a few more Strength or HIIT workouts to unlock personalized suggestions."* (per Phase 8.8 calculated-nudge fallback.) |

**Whole-sheet cold-start:** When the user has zero Strength or HIIT workouts ever, the sheet renders the hero + per-block empty states inline. No separate hero replacement. Whole-sheet message — same as the hero empty copy.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | All widgets at default/empty: Training Load 0% "Resting", Streak 0 dormant flame, Power Level "No data" message, Today's Plan "No workout planned for today.", Activity Rings shows the appropriate State 1 or State 2 message based on HealthKit + Watch availability. Tapping any widget still opens its detail sheet (which renders its own per-block empty state). |
| Populated | Full dashboard with live data. Tapping any widget opens its detail sheet. |
| Edit Mode | All widgets show "x" buttons; cards draggable; tap outside exits. **Tap-to-open is suppressed** — taps reach only the delete-and-drag chrome. |
| All Widgets Removed | Centered muted message: "Tap the menu to add widgets to your Home screen." Ellipsis, Log Workout, and Recent Workouts remain accessible. |

---

## Workouts (List)

**Purpose:** Training log organized by workout type with expandable cards.

### Layout
Left: blue ellipsis icon. Right: "+" menu button. ✦ divider. One Workout Type card per type with ≥ 1 logged workout. Cards sorted by WorkoutTypeOrder.sortOrder.

### Workouts Ellipsis Menu
One option: **"View Workout Templates"** with SF Symbol `doc.on.doc` to the left → Workout Templates List.

### Workouts "+" Menu
Two options: **"Log Workout"** with SF Symbol `plus.circle` to the left → Log Workout screen. **"Create Workout Template"** with SF Symbol `square.and.pencil` to the left → Create Workout Template screen.

### Workout Type Card (FortiFitWorkoutTypeCard)

Leading workout-type SF Symbol (CONSTANTS § Workout Type SF Symbols, same size + color as the type name) · type name as header (Primary Text 20/900 uppercase, 2px spacing) · count badge right (`8 WORKOUTS` / `1 WORKOUT`, muted 11/700) · trailing chevron (▸ collapsed, ▾ expanded, 0.2s ease rotate). Tap anywhere = toggle expand/collapse (state persists via `WorkoutTypeOrder.isExpanded`; default collapsed). Long-press header → Sort/Filter/Reorder/Delete context menu.

### Expanded Workout Preview Rows

Sorted by active sort (default newest-first). Each row separated by Border 1px:
- **Row 1** — workout name (16px semibold)
- **Row 2** — date row (muted), format `{date} · Apple Workout` when applicable per § Standard Patterns → Peripheral Apple Workout Label
- **Row 3** (optional) — duration / distance, format `{duration} min` and/or `{distance} {unit}`, `·`-separated when both. Row omitted when both absent.
- Trailing chevron (>)

Tap → Workout Detail. Swipe left → red "Delete" → standard delete confirmation → cascade delete + count update. Deleting last workout of a type removes the card and its WorkoutTypeOrder record.

### Pagination

First 30 workouts shown on expand. "Show next 30 workouts (X total)" button (muted centered) when >30 exist; appends next batch and updates dynamically; disappears when all loaded. Collapse/re-expand resets to 30. Sort/filter changes reset pagination.

### Search Bar

Visible only when type has >20 workouts. Below card header, above first preview row. Elevated Surface bg, muted magnifying glass, placeholder "Search workouts". Case-insensitive by name across **all** workouts of the type (not just loaded batch). Replaces paginated view (no Show More while searching). Clearing (×) returns to paginated. "No workouts found." on miss.

### Sort, Filter, Reorder & Delete Context Menu

Long-press card header. Items:

| Item | Sub-options |
|---|---|
| Sort by… | Newest first (default ✓), Oldest first, Alphabetical (A–Z). One active. Selecting re-renders + resets pagination. |
| Filter by… | **Date range:** Last 7d, 30d, 3mo, 6mo, This year, All time (default), Custom (date-picker sheet). **Effort range:** Min/max stepper 1–10 (nil-Effort workouts excluded when active). **Duration range:** preset buckets (<30, 30–60, 60–90, 90+ min) — multi-select OR within, AND across types; hidden for Yoga/Pilates. |
| Reorder Workout Types | Standard Reorder Edit Mode → persists to `WorkoutTypeOrder.sortOrder`. Expand/collapse disabled during reorder. |
| Delete Workout Type | Confirmation modal: "This will permanently delete all X [Workout Type] workouts. This cannot be undone." Cancel / destructive Delete → cascade-deletes all workouts of the type + their ExerciseSets, removes the WorkoutTypeOrder record, fires cascade per SERVICES § Workout Type Deletion. Always visible regardless of sort/filter state. |
| Clear All | Resets sort to Newest first + clears all filters. Visible only when non-default sort or any filter active. |

**Gesture coexistence:** long-press menu is scoped to card *header*; swipe-to-delete on *preview rows* operates independently — no conflict.

**Visual indicators:** sort indicator (↑↓, muted) near count badge when non-default sort active; filter indicator (funnel + count badge) when filters active. Both can appear simultaneously.

**Persistence:** sort/filter stored on WorkoutTypeOrder (`activeSortOption`, `activeFiltersJSON`). Persists per type across sessions.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "Log your first workout to see it here." + blue Log Workout CTA |
| Populated | Workout Type cards sorted by user order |
| Reorder edit mode | Drag handles visible, expand/collapse disabled, tap outside to exit |
| Search — no results | "No workouts found." below search bar |
| Filter — no results | "No workouts match your filters." + "Clear filters" link |

---

## Log Workout

**Purpose:** Form for creating or editing a workout.

### Layout

Back chevron (§ Standard Patterns → Back Navigation Chevron) · Heading "Log Workout" (new) / "Edit Workout" (edit) · top-right blue ellipsis. Ellipsis visibility:
- **New mode:** always visible.
- **Edit mode:** visible only when `workout.workoutType` is Strength Training or HIIT (templates support only those). Hidden on Cardio/Yoga/Pilates/Other. Top-right header in edit mode is `trash | ellipsis` left-to-right.

**Form fields (all modes):**
- Workout Name input
- DatePicker `.dateAndTime` (date defaults to today, constrained today-or-earlier; any time; iOS locale formatting; date → `workout.date`, time → `workout.time`)
- Workout Type dropdown (6 types)
- Post-Workout Effort dropdown + "?" tooltip — each option renders as `[Label] ([Number])` per CONSTANTS § Effort Label Mapping (e.g., `Easy (1)`, `Hard (7)`, `All Out (10)`). Integer stored on `workout.rpe`; label display-only.
- Duration (minutes, optional) — all types, below Effort

**Type-specific fields below duration:**

| Type | Additional fields |
|---|---|
| Strength Training / HIIT | Exercise cards: name input with autocomplete, per-card metadata row (REST PER SET + REPS/TIME toggle — see § Exercise Card Additions below), sets/reps/weight table, + ADD ROW, remove. "+ Add Exercise" button. Each row = one ExerciseSet. |
| Cardio | Distance (km or mi per `useMiles`, optional). No exercises. |
| Yoga / Pilates | No additional fields. |

### Exercise Card Additions (Phase 8.7)

Two per-card controls share a single horizontal row positioned directly above the column header (between the exercise-name input and the data rows). Layout:

```
[Exercise Name input]
[REST PER SET: 90s ⓘ]                          [REPS | TIME]
[SETS  REPS  LBS]
... rows ...
[+ ADD ROW]
```

**REST PER SET field (left):**

- Single rest value per exercise card (not per row). Stored as `restSeconds: Int?` on each `TemplateExerciseSet` / `ExerciseSet` row of this exercise — UI keeps all rows of the same `exerciseName` in lockstep.
- Label: `REST PER SET` (uppercase, 11px / 700 weight / 2px letter spacing — matches existing micro-label treatment).
- Value display: `90s` for sub-minute, `1:30` for ≥1 minute. `—` when nil.
- Tap opens a SwiftUI duration picker. Range 5–600 seconds in 5-second increments (see CONSTANTS.md § Apple Watch Strings → Rest Picker Range).
- Trailing `info.circle` icon (14pt, Muted Text). Tap → SwiftUI `.popover` with copy from INFO_COPY.md § Inline Popover Copy → Rest Per Set. ID `exerciseCard_{index}_restPerSetInfoPopover`.
- Field ID: `exerciseCard_{index}_restPerSetField`.

**REPS/TIME segmented control (right):**

- Two-segment SwiftUI segmented control: `REPS` | `TIME`. Initial position resolves from the exercise dictionary: `displayAsTime ?? exerciseDictionary.isIsometric(exerciseName)` (see WORKOUTKIT.md § 6 and CONSTANTS.md § Isometric Exercise Names).
- User tap on the opposite segment overrides the dictionary default — sets `displayAsTime = true` (for TIME) or `displayAsTime = false` (for REPS) on every row of this exercise card.
- When TIME is active: column header reads `TIME` (replacing `REPS`); each row's input becomes the same duration picker as REST PER SET (same range, same increments). The integer is stored in the `reps` field — interpretation is purely at display and Watch-composition time.
- When REPS is active: column header reads `REPS`; numeric text field input (current behavior).
- **Flip preserves integer values.** A `10` in REPS becomes `10s` in TIME after flip — user adjusts if needed. Toggling back restores the integer interpretation. No data clearing on toggle.
- Field ID: `exerciseCard_{index}_repsTimeToggle`.

**Default selection by exercise name (from CONSTANTS.md § Isometric Exercise Names + § Ambiguous Exercise Default Modes):** Planks, Wall Sit, Dead Hang, Hollow Hold, Side Planks, L-Sit, Bear Hold, etc. → TIME. Battle Ropes, Farmers Walks, Sled Push/Pull, Rowing Machine, Assault Bike → TIME. Bench Press, Squats, Burpees, Box Jumps, etc. → REPS. Unknown / custom exercises → REPS (safe default).

**Effect on Watch sync (Strength Training / HIIT):** these per-row settings are written into the `scheduledWorkoutSnapshot` at scheduling time and into the `ExerciseSet` records on completion. They drive the `IntervalStep` goal type (`.time` vs `.open`) and step display name in the `CustomWorkout` plan composition (see WORKOUTKIT.md § 6).

### Log Workout Ellipsis Menu (New Mode Only)

| Item | SF Symbol | Behavior |
|---|---|---|
| Use workout template | `doc.badge.arrow.up` | Centered selector overlay listing all templates (name + type). Selecting pre-populates name, type, duration, exercises. Date/time → now, Effort empty. All fields editable. Empty: "No saved templates yet." |
| Save as workout template | `square.and.arrow.down` | Grayed out when type isn't Strength/HIIT or name + exercise not yet entered. Naming prompt pre-filled with workout name. Saves to SwiftData + "Template saved!" toast (~2s). Does NOT log the workout. |

### Save Button

"Save Workout" (new) / "Save Changes" (edit). Disabled until name filled. Enabled = blue.

### Edit Mode Behavior

All fields pre-populated. Type dropdown locked. Blue trash icon top-right → standard delete confirmation → deletes workout + ExerciseSets, fires Workout Cascade, navigates back to Workouts. Add row → new ExerciseSet on save; modify → update; remove → delete.

The top-right ellipsis is the **only** ellipsis surface in Edit mode — no per-field ellipsis icons. (HK-linked workouts show inline `info.circle` icons on read-only field labels — separate symbol, separate purpose; see HK-Linked Workouts below.)

### Edit Mode Ellipsis Menu

Visible only on Strength Training or HIIT Edit screens. Single item:

**"Use Template"** (`doc.badge.arrow.up`, ID `editWorkout_useTemplateMenuItem`) → opens the same template selector as new-mode "Use workout template", filtered to templates matching the current `workoutType`. Empty: "No saved templates yet."

Apply rules (in-memory edit state only — nothing persists until Save; Workout Cascade fires on save via `WorkoutService.update()`):

| Field | Apply rule |
|---|---|
| Exercises | **Append** template's `TemplateExerciseSet` rows as new `ExerciseSet`s (preserving existing rows' `sortOrder`; new rows continue from the current max). No dedupe by name. |
| Workout name | Fill if empty; never overwrite an existing name. |
| Duration (non-HK-linked) | Fill if nil/empty; never overwrite. |
| Duration (HK-linked) | **Silently dropped** (HK-owned, read-only). |
| Workout type | Never applied (locked; selector pre-filters to matching type anyway). |
| Effort / date / time / distance | Never applied. Per-session or not carried by templates. |

No confirmation dialog — operation is non-destructive (append-only for exercises, fill-if-empty for fields). No "Save as template" in Edit mode (kept minimal).

### Edit Mode — HealthKit-Linked Workouts

When `healthKitUUID != nil`, three fields are read-only with inline `info.circle` popovers per HEALTHKIT § 7.

| Field | State when linked |
|---|---|
| DatePicker (date/time) | Disabled. Date is HK-owned (`workout.date = HK start date`). Time is user-owned but shares the input; date/time split tradeoff (see below). |
| Duration | Disabled, pre-populated with HK value. |
| Distance (Cardio only) | Disabled, pre-populated with HK value. |
| Workout name, Effort, Session notes, ExerciseSets | **Editable** — user-owned. Adding sets to a linked Cardio import is allowed though uncommon. |

**Inline `info.circle` popover:** trailing each disabled label, 14pt Muted Text. Tap → SwiftUI `.popover` anchored to the icon (~260pt width, Primary Text 13/500) with field-specific copy from CONSTANTS § HealthKit Strings → Log Workout — HealthKit-Linked Field Popovers. Tap-outside dismisses. Vanishes after unlink. IDs `logWorkout_hkFieldInfoIcon_{date|startTime|duration|distance}`.

**Rationale:** users need to know *why* a field is disabled; per-field popovers answer that without a sheet round-trip.

**Date/time split tradeoff:** `time` is user-owned, but DatePicker `.dateAndTime` shares one input, so the whole DatePicker disables. Editing time alone requires unlink first. Acceptable for MVP.

**Use Template + HK-linked:** ellipsis shows on linked Strength/HIIT Edit screens too. Apply rules same as above; only difference is template's duration is silently dropped (already covered in the apply table). Disabled fields and popovers unaffected.

**Save:** identical to non-linked — `WorkoutService.update()` bumps `lastModifiedDate` and fires Workout Cascade.

---

## Create Workout Template

**Purpose:** Build a reusable workout template from scratch, or edit an existing one.

### Layout

Back chevron (§ Standard Patterns → Back Navigation Chevron) · Heading "Create Workout Template" (new) / "Edit Template" (edit). Form fields: Template Name (required), Workout Type dropdown (Strength Training / HIIT only), Duration (optional), exercise cards (identical to Log Workout Strength/HIIT, including the per-card REST PER SET field and REPS/TIME segmented control — see § Log Workout → Exercise Card Additions), "+ Add Exercise". No Effort, no DatePicker, no distance. Per-row `restSeconds` and `displayAsTime` values flow through into `ScheduledWorkout.scheduledWorkoutSnapshot` when the template is later scheduled (see WORKOUTKIT.md § 5, § 6).

"SAVE TEMPLATE" / "Save Changes" button. Disabled until name + ≥1 exercise with sets/reps. Saves to SwiftData, navigates back.

**Edit mode:** Pre-populated from Workout Templates List. Type locked. Top-right: muted trash · blue ellipsis. Trash → standard delete confirmation → cascade-deletes template + TemplateExerciseSets → navigate to Workout Templates List. Back button → Workout Templates.

**Edit Mode Ellipsis Menu:** **"Share Template"** (`qrcode`) → opens the same Share Template QR Modal as Workout Templates List (§ below).

---

## Workout Templates List

**Purpose:** View, edit, delete, and share saved templates.

### Layout
Back chevron (§ Standard Patterns → Back Navigation Chevron). "Workout Templates" heading. Right: "+" button (→ Create Workout Template in new-template mode). Scrollable list sorted by dateCreated (newest first). Each row: template name (16px semibold), workout type (muted), date created (muted), trailing chevron.

Tap row → Create Workout Template in edit mode. Template deletion has no effect on workouts, goals, PRs, streaks, or Training Load.

### Long-Press Context Menu

| Item | SF Symbol | Behavior |
|---|---|---|
| Share Template | `qrcode` | Opens Share Template QR Modal (§ below). |
| Schedule This Template | `calendar.badge.plus` | Opens § Plan → Scheduling Flow with this template pre-selected. |
| Delete Template | — | Standard delete confirmation: `Delete [Template Name]? This cannot be undone.` On confirm cascade-deletes template + TemplateExerciseSets. |

### Share Template QR Modal

Centered modal, dimmed bg, outside-tap or close-button dismiss.

Upper-left: blue share icon (`square.and.arrow.up`) → iOS share sheet with QR code as PNG. Upper-right: standard close button (24×24pt). Center: QR code encoding the template data as a `fitnavi://` URL (see SERVICES § TemplateShareService). Below: template name (Primary Text 15/700 centered) + workout type (Muted Text 13px centered).

QR styling: white-on-dark; Card Surface bg behind the QR module; Border 1px stroke + 12px corner radius around the container; QR ~250pt for comfortable scanning.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "No saved templates yet. Create one from the Workouts screen or save a logged workout as a template." |
| Populated | Scrollable list of template preview cards |

---

## Template Import Prompt

**Purpose:** Confirm and save a workout template received via QR code deep link.

### Trigger

Fires when the app opens via `fitnavi://template?data=...` (scanned QR or tapped link). App not running → launches first then presents prompt; already open → modal over current screen.

### Layout

Centered modal, dimmed bg. Heading "Import Template?" (Primary Text 20/900). Template preview card showing template name (Primary Text 16/700), workout type (Muted Text 13px), exercise count (Muted Text 13px, e.g., "5 exercises").

Action buttons below preview: "Cancel" (muted outline, no action) / "Save Template" (blue filled — creates the template + "Template saved!" toast ~2s, dismisses).

### Duplicate Name Handling

Same-name template exists → auto-rename with numeric suffix: "Push Day" → "Push Day (1)" → "Push Day (2)" etc. Preview shows the final resolved name.

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Malformed or undecodable QR data | Modal displays: "This QR code couldn't be read. It may be damaged or from an incompatible version of FitNavi." with a single "OK" button to dismiss. |
| QR code scanned without FitNavi installed | iOS displays its native system alert (custom URL scheme not registered). Known limitation — a custom fallback page requires Universal Links with a web domain (future enhancement when cloud infrastructure is added). |
| Workout type in QR data is not "Strength Training" or "HIIT" | Treated as malformed data — show the same error message above. |

### States
| State | What the User Sees |
|-------|-------------------|
| Valid template data | Import prompt with template preview + Cancel/Save |
| Invalid/malformed data | Error message with "OK" dismiss button |

---

## Plan

**Purpose:** Schedule workouts in advance for a particular day, week, or month using saved templates. Complete planned workouts with minimal friction.

**Core Principle:** A scheduled workout is an intent, not a record. The `Workout` model object is only created when the user explicitly completes the session. The schedule is tracked by a separate `ScheduledWorkout` model.

### Layout

Header: blue ellipsis (left) · "+" button (right, light haptic, matches Home "+ Log Workout"). ✦ divider. FortiFitSegmentedToggle: "WEEK" (default) / "MONTH". Calendar area below the toggle. Day Detail Area below the calendar.

### Week Strip Calendar (Default)

Continuous horizontal scroll, 7 visible day cells. Scrolls day-by-day (not week-by-week) — each swipe advances one day; visible window slides gradually rather than snapping.

Month indicator above the strip (15/700, Primary Text), updating as the user scrolls. Shows year if not current year. If the visible 7 days span two months, shows both (e.g., "April – May"). No month navigation controls — passive context only.

Cell sizing: 1/7 width, 72pt min height, 6pt internal vertical spacing, 36pt selection-circle diameter.

Each cell:
- Day abbreviation ("MON" — muted uppercase label, 12/700, 2px spacing)
- Date number ("7" — Primary Text, 18/800)
- Dot indicators below date: **blue** = planned `ScheduledWorkout`; **green** = completed (from either a completed `ScheduledWorkout` OR a logged-only `Workout` surfaced per § Logged-Only Workout Surfacing); none = empty. Max 3 visible, "+N" if more. Dot 6pt, 4pt spacing.

Cell states: **selected** = solid Primary Accent Blue circle around the date number (number flips to Background Dark for contrast); **today (not selected)** = blue ring (unfilled); **today + selected** = filled blue circle (selected wins). Tap selects and updates Day Detail Area.

### Month Grid View

Calendar grid, 44pt min tap target. Date number 14/700 centered. Selection circle 30pt (scaled down from week strip). Dot indicators 5pt below the date — same color logic as week strip. Row height 52pt min. Weekday header row ("M T W T F S S") muted uppercase 11/700. Swipe left/right for month navigation.

Selected day uses the same blue filled circle. Tap → selects + updates Day Detail Area; stays in month view.

### Plan Ellipsis Menu

One option: **"View Workout Templates"** (`doc.on.doc`) → SavedTemplatesListView (same view as Workouts ellipsis).

### Day Detail Area

Below the calendar. One card per scheduled or logged workout on the selected day (inclusion rules in § Logged-Only Workout Surfacing). Cards stack vertically.

**Stack order:** Planned and skipped scheduled cards render first, followed by completed scheduled cards and logged-only cards (both treated as "done"). This keeps upcoming work anchored at the top of the day's stack regardless of `scheduledTime`. Sort key implemented in `PlanService.fetchPlanSurface` (SERVICES.md § PlanService → Retrieval).

**Card variants:**

| Variant | Visual | Trailing affordance | Action |
|---|---|---|---|
| Planned scheduled (`FortiFitScheduledWorkoutCard`) | Default styling | — | Full-width blue-outlined "Complete Planned Workout" button |
| Overdue planned (past `scheduledDate`, still "planned") | + muted "OVERDUE" badge below the type pill | — | Same as planned |
| Completed scheduled | Green checkmark, muted styling | `· PLANNED SESSION` to the right of the type pill | Muted "COMPLETED" label replaces the button |
| Logged-only (surfaced per rules below) | Visually identical to completed scheduled | `· LOGGED SESSION` to the right of the type pill | Muted "COMPLETED" label replaces the button |
| Skipped scheduled | Dimmed, strikethrough name, muted border | — | Muted "SKIPPED" label replaces the button |

**Card fields (common):** workout name (Primary Text 16/semibold), workout type pill (muted uppercase, 11px), metadata row with duration, scheduled time (planned only, when set), and "Apple Workout" peripheral label trailing on the metadata row when source is Apple Watch (§ Standard Patterns). Metadata row hidden if all components absent.

**Push to Apple Watch glyph (planned cards only):** `FortiFitWatchSyncGlyph` (§ Standard Patterns → Watch Sync Card Glyph) in the upper-right corner of every `FortiFitScheduledWorkoutCard` whose `status == "planned"` and `scheduledDate >= today`. Renders as active green `applewatch.watchface` when `syncToAppleWatch == true` and gates pass; inactive `applewatch.slash` when push is off; disabled (0.4 opacity) when any gate fails. Skipped, completed, overdue, and logged-only cards do NOT render the glyph — push is only meaningful for future planned sessions. Tap behavior per § Standard Patterns. Identifier: `scheduledWorkoutCard_{index}_watchSyncGlyph` (kept for code-level continuity).

**Tap behavior:**
- Planned / Skipped: no tap navigation (button is the primary action).
- Completed scheduled: tap → Workout Detail (resolved via `completedWorkoutId`).
- Logged-only: tap → Workout Detail for the underlying `Workout`.

Days with no surfaced workouts → empty detail area. The header "+" is the sole scheduling entry.

### Logged-Only Workout Surfacing

A `Workout` surfaces on Plan (as a green dot and a logged-only card under `workout.date`) iff **both**:
1. No `ScheduledWorkout` has `completedWorkoutId == workout.id` (already represented by the scheduled card — would duplicate).
2. `workout.hiddenFromPlan == false`.

Failing either → invisible to Plan. Implementation in SERVICES § PlanService → Retrieval.

Plan empty state fires only when **no** `ScheduledWorkout` records exist AND no non-hidden `Workout` records exist — any surfaced card or dot counts as non-empty.

### Scheduling Flow

**Entry points:** (1) "+" button in Plan header. (2) Long-press a template in Workout Templates List → "Schedule This Template."

**Flow:**
1. **Workout Template Selection** — label "Workout Template". Sheet up showing saved templates (reuses SavedTemplatesListView as a picker). Each row: template name, workout type, exercise count. Tap to select.
2. **Date Selection** — pre-filled if entered from a specific day. Otherwise date picker. Today or later only — past dates not schedulable.
3. **Scheduled Time toggle** — when on, exposes a time-of-day picker. When off, no scheduled time. Default off. Independent of the Push to Apple Watch toggle — time is optional regardless of push state.
4. **Recurrence (optional)** — None (default) / Weekly / Biweekly. Selecting auto-generates `ScheduledWorkout`s for the next 12 weeks, all sharing the same `recurrenceGroupId`.
5. **Push to Apple Watch toggle (Phase 8.7.1+)** — see § Push to Apple Watch Toggle below for full behavior. Position: directly under the Recurrence segmented control, above the "Plan Workout" CTA.
6. **"Plan Workout" button** — full-width primary action at bottom. Saves the `ScheduledWorkout` (and its recurrence siblings, if any), and if Push is on, registers the plan with the Watch via `WatchScheduleService.schedule(_:)`. On success the sheet dismisses and a "Workout Planned" toast (~2s, top-anchored Capsule, primaryAccent fill, white `bodySmall` text; fade + slide via opacity/offset matching the Removed from Plan toast) appears on the host screen — Plan or Workout Templates List, depending on entry point.

Validation: template required; date today or future. Multiple workouts per day allowed.

### Push to Apple Watch Toggle (Phase 8.7.1)

The primary entry point for pushing workouts to Apple Watch. SwiftUI `Toggle` row with a trailing `info.circle` icon. ID `scheduleWorkout_pushToAppleWatchToggle`; popover ID `scheduleWorkout_pushToAppleWatchInfoPopover`.

**Default value at sheet open** (resolves once, when the sheet appears):

| Master state | WorkoutKit auth | Toggle default | Toggle interactive? |
|---|---|---|---|
| `syncPlanToAppleWatchEnabled == true` | Granted | On | Yes |
| `syncPlanToAppleWatchEnabled == false` | Any | Off | No (greyed, 0.4 opacity) |
| `syncPlanToAppleWatchEnabled == true` | Denied | Off | No (greyed, 0.4 opacity) |

**When greyed (master off or auth denied):** Caption directly beneath the toggle row, muted text per `bodySmall` treatment. Master-off case: *"Push to Apple Watch is off in Settings"* (`AppConstants.AppleWatch.scheduleWorkout_masterOffCaption`). Auth-denied case: *"Apple Health permission required — open iOS Settings"* (`AppConstants.AppleWatch.scheduleWorkout_authDeniedCaption`). Tap on the disabled toggle surfaces the existing Master Sync Off Popover (§ Standard Patterns). Master-off path deep-links to in-app Settings; auth-denied path deep-links to iOS Settings via `UIApplication.openSettingsURLString`.

**When the user toggles Push ON or OFF:** No side effects on the Scheduled Time toggle. Time and Push are independent controls. When Push is on and no `scheduledTime` is set, `WatchScheduleService` falls back to noon (12:00 PM) for the WorkoutKit API call — Apple Watch does not surface the time to users.

**`info.circle` popover copy:** see INFO_COPY.md § Inline Popover Copy → Watch Sync Toggle. Reused across Plan Workout and Edit Planned Workout.

**On Save:**

- `ScheduledWorkout.syncToAppleWatch` is set from the toggle's final value.
- Defensive server-side gate validation (master on, auth granted, ≥1 exercise, scheduledDate >= today). Validation failure should be impossible given the UI gating; if it occurs (race / form bypass), force `syncToAppleWatch = false` and surface a soft error toast: *"Couldn't push to Apple Watch — check Settings."* (`AppConstants.AppleWatch.scheduleWorkout_validationFailedToast`).
- After SwiftData save, if `syncToAppleWatch == true`, call `WatchScheduleService.schedule(_:)` per existing Phase 8.7 logic. New `appleWorkoutPlanId` UUID stamped on first sync.
- For recurring schedules, the inheritance logic is unchanged — every instance in the new `recurrenceGroupId` gets the same `syncToAppleWatch` value and `scheduledTime`, applied to each instance's own date.

### Complete Planned Workout Flow

1. Tap "Complete Planned Workout" on a card.
2. **Date Resolution** (see below) — resolve any date prompt first.
3. **Compact confirmation sheet** slides up (Card Surface bg, Border, dimmed overlay):
   - Workout name at top (non-editable context line, Primary Text 16/700).
   - **Effort** — horizontal row of 1–10 pills, matches Log Workout. Optional, no default.
   - **Duration** — FortiFitInput with "min" suffix. Optional. Pre-filled from template's `durationMinutes` if available.
   - **"Save Workout"** (full-width, blue-filled).
   - **"Modify Exercises"** (full-width, blue-outlined) → full Log Workout pre-populated from template snapshot.
4. **On Save:** creates `Workout` from template snapshot (name, type, exercises/sets/reps/weights) + Effort + duration from sheet. Marks slot completed, stores new `Workout.id` on `completedWorkoutId`. Dismiss + "Workout completed." toast.
5. **On Modify Exercises:** dismisses compact sheet, opens Log Workout new-mode pre-populated from snapshot, carrying through the `ScheduledWorkout` ID. Save → same completion logic. Back-out without saving → slot stays "planned".

Sheet dismiss (close button / outside tap) does not complete the workout.

### Date Resolution Logic

| Scheduled date | Prompt | Outcome |
|---|---|---|
| Today | None | Workout stamped today |
| Past | "This workout was planned for [scheduled date]. Log for [scheduled date] or today?" → [Scheduled date] / Today | Either choice → confirmation sheet with corresponding date |
| Future | "This workout is planned for [future date]. Log for today instead?" → "Log for Today" / "Cancel" | Log for Today → confirmation sheet, workout saved today. Cancel → returns to Plan, slot stays planned. No option to keep the future date — post-dating prohibited to prevent phantom entries in stress, streak, and PR calculations. |

### Long-Press Context Menu

Long-press a Day Detail card (uses Standard Long-Press Tease). Menu varies by card type:

| Card type | Menu items |
|---|---|
| Planned scheduled | **Edit Workout** (`pencil`) — opens § Edit Planned Workout pre-populated from this `ScheduledWorkout`. **Skip Workout** (sets status "skipped", dims card, no `Workout` created — reversible via "Restore Workout"). **Remove from Plan** (standard delete confirmation; deletes `ScheduledWorkout`. Recurring instances trigger the "This workout only / This and future" prompt first). |
| Skipped scheduled | **Edit Workout** (same as planned). **Restore Workout** (status back to "planned"). **Remove from Plan** (same as planned). |
| Completed scheduled | **Remove from Plan** — dual-action (see below). Underlying `Workout` preserved. |
| Logged-only | **Remove from Plan** — non-destructive ("Remove [Workout Name] from Plan? The workout will remain in your log." — Cancel / Remove, no destructive-red styling). Sets `workout.hiddenFromPlan = true`. Card + dot disappear; workout intact in Workouts and algorithms. Toast "Removed from Plan. [Undo]" (~4s) flips back on Undo. |

**"Remove from Plan" dual-action (completed scheduled only):** A completed scheduled card is backed by both a `ScheduledWorkout` and a linked `Workout`. Deleting the schedule alone would re-surface the workout as a logged-only card (per § Logged-Only Workout Surfacing). So this action atomically (1) deletes the `ScheduledWorkout`, (2) sets `workout.hiddenFromPlan = true`. User sees a single disappearance. Schedule/recurrence lineage is permanently lost; the workout can only reappear via "Show on Plan" in Workout Detail (then as a logged-only card). Confirmation + toast match the logged-only flow. Undo flips `hiddenFromPlan` back; the `ScheduledWorkout` is **not** restored. SERVICES § PlanService → Remove from Plan for full logic.

For recurring completed instances, the "This workout only / This and future workouts" prompt applies first. **This and future** = dual-action on this instance, plus delete future **planned** `ScheduledWorkout`s in the same `recurrenceGroupId` (past completed/skipped untouched).

### Editing Recurring Workouts

Edit/delete on a recurring instance prompts **"This workout only"** or **"This and future workouts"**. "This and future" applies to this instance + all future instances in the same `recurrenceGroupId` with `scheduledDate` ≥ this instance's date. Past completed/skipped workouts are never retroactively altered.

### States

| State | What the user sees |
|---|---|
| Empty | "Schedule your first workout to start planning." Fires only when no `ScheduledWorkout` records exist AND no non-hidden `Workout` records exist. "+" accessible. |
| Populated | Calendar with dot indicators + cards in Day Detail |
| Week view | Default — continuous day-by-day scroll, month indicator, detail below |
| Month view | Condensed grid — tap day selects + updates detail (stays in month view) |
| Selected day | Blue filled circle on date number (both views) |
| Completed | Green checkmark + muted "COMPLETED" label (both completed scheduled and logged-only cards) |
| Skipped | Dimmed card, strikethrough name, muted "SKIPPED" label |
| Overdue | Planned card + muted "OVERDUE" badge |

---

## Edit Planned Workout

**Purpose:** Modify a scheduled workout's exercises, name, date, time, duration, and Apple Watch push intent. The `ScheduledWorkout` is the source of truth for everything Watch-relevant — edits here freely deviate from the originating template, and pushed cards re-sync to Watch on save (see WORKOUTKIT.md § 7, § 13).

### Trigger

Long-press a planned or skipped `FortiFitScheduledWorkoutCard` on the Plan screen → context menu → **Edit Workout** (`pencil`). Opens this screen pre-populated from the `ScheduledWorkout`'s decoded `scheduledWorkoutSnapshot` plus the record's name, date, time, and duration fields.

### Layout

Back chevron (§ Standard Patterns → Back Navigation Chevron) · Heading "Edit Planned Workout" (top-leading, Primary Text per heading typography). Top-trailing: blue `FortiFitWatchSyncGlyph` (§ Standard Patterns → Watch Sync Card Glyph) — same component as on the Plan card, mirroring the per-card `syncToAppleWatch` flag. ID `editScheduledWorkout_watchSyncToggle`.

Form fields, top-to-bottom:

- Workout Name input — pre-filled from `ScheduledWorkout.workoutName`. Editable.
- DatePicker `.date` — pre-filled from `ScheduledWorkout.scheduledDate`. Constrained to today-or-future (past dates not allowed; would invalidate Watch sync). ID `editScheduledWorkout_dateField`.
- Scheduled Time toggle — pre-filled from `ScheduledWorkout.scheduledTime` (toggle on with picker if set, off if nil). Optional. Not required for Watch push (service falls back to noon). ID `editScheduledWorkout_timeField`.
- Workout Type — read-only display of `ScheduledWorkout.workoutType`. Locked (changing type would orphan the snapshot).
- Duration (minutes) — pre-filled from `ScheduledWorkout.durationMinutes`. Editable. Optional.
- Exercise cards — pre-populated from the decoded snapshot. Identical to Log Workout's exercise card UI (including the new REST PER SET field and REPS/TIME segmented control — see § Log Workout → Exercise Card Additions). User can add, modify, remove rows; reorder; rename exercises. All edits flow through decode-edit-re-encode of `scheduledWorkoutSnapshot`.
- "+ Add Exercise" button — same as Log Workout / Create Workout Template.

**"Push to Apple Watch" toggle behavior** (renamed from "Sync to Apple Watch" in Phase 8.7.1): mirrors the card glyph (§ Standard Patterns) and the Plan Workout Push toggle (§ Plan → Push to Apple Watch Toggle). When master is off, tap shows the Master Sync Off Popover. `info.circle` next to the toggle (ID `editScheduledWorkout_watchSyncInfoPopover`) shows a SwiftUI `.popover` with copy from INFO_COPY.md § Inline Popover Copy → Watch Sync Toggle. Time and Push are independent controls — toggling Push on/off has no side effect on the Scheduled Time toggle.

### Save Button

"Save Changes" (full-width, bottom). Disabled until name is filled and ≥1 exercise has sets and reps. ID `editScheduledWorkout_saveButton`. Tap fires the save flow below.

### Save Flow

1. Re-encode the edited exercises into `scheduledWorkoutSnapshot`.
2. Update `workoutName`, `scheduledDate`, `scheduledTime`, `durationMinutes` on the `ScheduledWorkout` record.
3. **Recurrence prompt** (if `recurrenceGroupId != nil`):
   - Confirmation dialog: title "Apply changes to all future workouts?" / message "This is part of a recurring schedule. You can apply your changes to this workout only or to this workout and all future ones in the series." / "This Workout Only" (default) / "This and Future Workouts".
   - **Date changes always force "This Workout Only"** — applying a date change to a series doesn't have a coherent meaning. If the user changed the date, the prompt's secondary action is suppressed and only "This Workout Only" appears, with a small footnote: "Date changes apply to this workout only."
   - "This and Future Workouts" applies the snapshot, name, time, and duration changes to this instance plus all future instances in the same `recurrenceGroupId` (`scheduledDate >= this instance's date`). Past completed/skipped instances untouched.
   - IDs `editScheduledWorkout_recurrencePrompt_thisOnly`, `editScheduledWorkout_recurrencePrompt_thisAndFuture`.
4. **Watch sync re-sync** (after SwiftData save): if the saved `ScheduledWorkout` has `syncToAppleWatch == true` and gates pass, `WatchScheduleService.resync(_:)` is called — `removePlan(uuid)` followed by `schedule(plan, at:)` with the same `appleWorkoutPlanId`. For "this and future," each affected synced instance is re-synced individually with its own UUID. See WORKOUTKIT.md § 7, § 13.
5. Dismiss the screen and pop back to Plan.

### Field Editability Table

| Field | Editable? | Notes |
|---|---|---|
| Name | Yes | User-controlled |
| Workout type | No | Locked. Changing would orphan the snapshot. |
| `scheduledDate` | Yes | Per-instance only for recurring (forces "This Workout Only"). Today or future. |
| `scheduledTime` | Yes | Optional. Required for Watch sync. |
| `durationMinutes` | Yes | Optional |
| Exercises (snapshot) | Yes | Add, modify, remove, reorder; per-row rest seconds and reps/time toggle |
| `recurrenceRule` | No | Recurrence rule changes via Remove + Re-schedule, not via Edit |
| `syncToAppleWatch` | Yes | Mirrors card glyph |

### States

| State | What the User Sees |
|-------|-------------------|
| Initial load | Form pre-populated from snapshot + ScheduledWorkout fields. Glyph reflects current push state. |
| Recurring instance | On Save, prompt asks "This Workout Only / This and Future." |
| Master push off | Glyph rendered disabled (0.4 opacity); tap shows Master Sync Off Popover. |
| Empty exercises (after user removed all rows) | Save button disabled. Glyph would render disabled (gate fails) on save attempt. |
| Save error (Watch push failure) | Save still completes (SwiftData write succeeds); error toast appears for the Watch portion only. Per-card flag retained per WORKOUTKIT.md § 11. |

---

## Workout Detail

**Purpose:** Full breakdown of a single workout session.

### Layout

Header: Back chevron (§ Standard Patterns → Back Navigation Chevron) · "Workout" label · workout name (blue) · `{date} · {time} · {type}` (muted; time omitted when nil).

Top-right icon tray (right-to-left): blue ellipsis (rendered only if ≥1 ellipsis item applies) · muted trash · muted edit · blue share. Share → renders Share Image Card and presents iOS share sheet. Edit → Log Workout in edit mode. Trash → standard delete confirmation → cascade delete → back to Workouts.

**Source indicator (HK-linked only)**, on its own row directly below the type row when `workout.healthKitUUID != nil`. Format `{sourceName} [glyph]` — source name only, no activity-type prefix; glyph trails *only* for Apple Watch. Label treatment, 14px Muted Text. Tappable → opens Source Indicator Info Sheet. ID `workoutDetail_healthSourceIndicator`.

Source name resolution (`HealthKitClient.sourceName(for:)` per SERVICES § HealthKitClient): Apple Watch → `Apple Workout`; other recognized → `HKSource.name` (Strava, Peloton, etc.); unresolvable → `another app`. Never a raw bundle ID. Leading glyph (`FortiFitHealthGlyph` — running figure on green) renders only for Apple Watch source; other sources render no glyph.

**Ellipsis menu** (icon visible only when ≥1 item applies):

| Item | Visibility | Behavior |
|---|---|---|
| Save as workout template (`square.and.arrow.down`) | Strength Training / HIIT only | Naming prompt pre-filled with workout name → saves template (name, type, duration, exercises; not Effort/date/time/notes) → "Template saved!" toast |
| Show on Plan (`calendar.badge.plus`) | `workout.hiddenFromPlan == true` | Flips flag to `false`. No confirmation. Toast: "Showing on Plan." |
| Unlink from Apple Health (`link.badge.minus`) | `workout.healthKitUUID != nil` | Confirmation dialog (copy owned by `AppConstants.HealthKit.unlinkConfirm*` per CONSTANTS § HealthKit Strings — title "Unlink workout from Apple Health?", message warns the action deletes Apple Health–sourced summary data and is one-way) → on Unlink applies SERVICES § HealthKit Unlink (clears six HK-only summary fields + conditionally `rpe`, fires Workout Cascade, writes `WorkoutMatchRejection`) → toast "Unlinked from Apple Health." Renders below other items. |

✦ divider. **"Summary" header** (sentence case). 2-column grid of bordered stat cards (`FortiFitStatCard`); each card opens the Metric Detail Sheet (§ below).

**Stat card structure:**
- Container: Card Surface bg, Border 1px, 12px corner radius, 16h × 14v internal padding.
- Top row: SF symbol (left, metric color per CONSTANTS § Stat Card Colors) + sentence-case label (Primary Text 13/700) + `chevron.right` (top-right, Muted Text).
- Below: metric value at 24px/800, color = icon color per CONSTANTS § Stat Card Colors. For numeric values, unit renders inline in smaller Secondary Text (e.g., `142 bpm`) — unit stays muted regardless of value color. Effort value color is dynamic per CONSTANTS § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red).
- Tap: 0.15s opacity dim → opens Metric Detail Sheet. IDs per TESTING.

**Field order** (top-to-bottom, left-to-right):

1. Effort
2. Duration
3. Distance (Cardio only)
4. Avg HR · Max HR (paired side-by-side when both non-nil)
5. Active kcal · Total kcal (paired side-by-side when both non-nil)
6. Elevation Ascended
7. Exercise Minutes

**Visibility:** each card renders only when its value is non-nil; pairs collapse to a single card when one is missing. No empty placeholders. Manual workouts collapse to 2–3 cards; HK-linked can show up to 9. Indoor/Outdoor removed entirely from Summary.

**Per-field display:**

| Field | Label | Value Display |
|---|---|---|
| Effort | Effort | Label per CONSTANTS § Effort Label Mapping (e.g., `Hard`); underlying integer preserved on `workout.rpe` but not displayed |
| Duration | Duration | `45 min` |
| Distance | Distance | `5.2 km` or `3.2 mi` per `useMiles` |
| Avg HR | Avg HR | `142 bpm` |
| Max HR | Max HR | `168 bpm` |
| Active kcal | Active kcal | `487 kcal` |
| Total kcal | Total kcal | `612 kcal` |
| Elevation Ascended | Elevation | `240 ft` or `73 m` per `useMiles` |
| Exercise Minutes | Exercise min | `32 min` |

Icons: CONSTANTS § Workout Detail Summary Icons (user-entered fields) and § Workout Detail Health Data Icons (HK-imported fields).

**After Summary** (Strength/HIIT only, conditional): "Exercises" header + exercise list (name, sets, weight). Header + list hidden entirely when `exerciseSets.isEmpty` (regardless of manual vs HK-imported origin). Reappears once an exercise is added.

✦ divider. **"Session Notes"** header + edit icon. Note card, or textarea + SAVE button when editing.

### Source Indicator Info Sheet

Opens via tap on the Workout Detail Source Indicator row. iOS modal sheet, `.large` detent (or custom `.height(...)` sized to content — never `.medium`), swipe-down dismiss.

**Vertical structure:**

| Block | Content |
|---|---|
| 1. Header icon | Centered HealthKit-pink `heart.fill` (32pt) — system-level Apple Health brand mark, not the per-source glyph. |
| 2. Title | "Imported from Apple Health" (Primary Text 18px semibold, centered). |
| 3. Lead sentence | "This workout was imported from Apple Health." (Secondary Text 14px centered, `.fixedSize(horizontal: false, vertical: true)`). |
| 4. Two-row callout | Stacked FortiFitCard rows (12px corner radius, 12px internal padding, 8px between rows). Each row: leading SF Symbol + multi-line body. **Row 1** — `pencil.slash` (Muted Text) + body "Date, Start Time, Effort, and Duration are read-only here. Edit in Apple Health, or unlink to edit in FitNavi." (first sentence Primary Text 14/600, second Muted Text 13/500). ID `sourceInfoSheet_readOnlyCallout`. **Row 2** — `arrow.uturn.backward.slash` (Alert Red) + body "Unlinking is permanent. Apple Health summary data will be deleted, and future Apple Health edits won't sync." (same dual-treatment). ID `sourceInfoSheet_permanentUnlinkCallout`. |
| 5. Primary action | Full-width "Done" button (blue-outlined). Dismisses. ID `sourceInfoSheet_doneButton`. Largest visual element — safe path gets the prominence per iOS convention. |
| 6. Destructive link | "Unlink from Apple Health" centered text-style link (Alert Red 14/600, 12px top spacing). Tap → confirmation dialog (next row). ID `workoutDetail_healthUnlinkButton` (preserves Phase 8 identifier per HEALTHKIT § 19). |
| 7. Confirmation dialog | Title "Unlink workout from Apple Health?" Message "This will delete all Apple Health–sourced summary data for this workout, and you won't be able to link it back. This can't be undone." Actions: destructive "Unlink" + cancel "Cancel". On Unlink → `HealthKitSyncService.unlink(workout:)` (HEALTHKIT § 14; clears six HK-only summary fields + conditionally `rpe`, fires Workout Cascade, writes a `WorkoutMatchRejection`) → dismiss + "Unlinked from Apple Health." toast. IDs `sourceInfoSheet_unlinkConfirmButton`, `sourceInfoSheet_unlinkCancelButton`. |
| 8. Footer metadata | 16px top spacer, then muted reference rows (12/600, Muted Text): `Activity Type · {workout.healthKitActivityType}` / `Source · {sourceName}` / `Imported · {formatted workout.dateCreated}` (omit if missing) / `Last synced · {relative}` (sourced from `HealthKitSyncService.lastSyncDate(for:)`; omit if never synced). ID `sourceInfoSheet_lastSyncedRow`. |

**Why footer placement:** keeps the destructive-link warning adjacent to its control; metadata is reference, not decision-relevant.

Dismiss: swipe down, outside tap, or "Done".

### Metric Detail Sheet

Tap any Summary stat card → opens `FortiFitMetricDetailSheet`. Component takes the tapped `Workout` and a `WorkoutMetric` enum case (SERVICES § WorkoutMetricService). All aggregates pulled from `WorkoutMetricService` — never queries SwiftData directly.

Presentation: iOS modal sheet, `.medium` detent, swipe-down dismiss, Card Surface bg, drag indicator visible.

Header: no centered title (hero block serves as the de facto title — keeps content-focused). Close button top-right: plain `xmark` Muted Text 16px, no bg/border. ID `metricDetailSheet_closeButton` (shared across metrics).

Body (scrollable, 20h × 24t padding) — four blocks top-to-bottom:

**1. Hero block** (mirrors the tapped stat card, scaled up):
- Top row: same SF symbol + label as the card (icon in metric color per CONSTANTS § Stat Card Colors; label Primary Text 13/700; no chevron).
- Below: value at 32px/900, color = icon color. Numeric fields render unit inline in smaller Secondary Text (e.g., `142 bpm`); unit stays muted regardless of value color.
- **Effort exception:** hero shows the label (e.g., `Hard`) at hero size in the band-mapped color, then a smaller `(7)` underneath — Secondary Text 15/600, always muted.

**2. Comparative context block** (two lines, Secondary Text 14/600 left-aligned):
- Line 1: `Your typical [Workout Type] session — [comparison value]` (e.g., `Your typical Strength Training session — Moderate (5.4)` for Effort; `… — 52 min` for Duration).
- Line 2: delta — `Harder than typical`, `+12 min vs typical`, `5 fewer kcal than typical`. Muted by default; Primary Accent Blue for positive-direction deltas on PR-eligible metrics when the workout is highest-ever.
- Comparison window: all-time across same-`workoutType` workouts with the metric set. Computed by `WorkoutMetricService.comparativeAverage(for:workoutType:)`.

**3. 30-day sparkline block** (FortiFitCard container, ~120pt height):
- Swift Charts `LineMark` over the same `workoutType`'s last 30 days. X/Y axes have no tick labels (range implied by caption).
- Line color: metric-specific per CONSTANTS § Stat Card Colors.
- **Effort exception:** per-segment color — each segment colored by its endpoint's effort band per CONSTANTS § Effort Color Mapping. Implementation: segmented `LineMark` series or `foregroundStyle(by:)` with a categorical effort-band scale.
- Current workout's point: ~6pt filled circle, Primary Accent Blue (uniform across all metrics — always locatable). Other points: Secondary Text, ~3pt.
- Caption: muted `Last 30 days · [Workout Type]`.

**4. Personal Best chip (conditional):** Renders only when `WorkoutMetricService.isPersonalBest(for:workout:)` returns true. Inline pill, Primary Accent Blue 15%-opacity bg + Primary Accent Blue text, 12px corner, 8h × 4v padding. Copy: `Personal best for [Workout Type]` (11/700). 16px top margin from sparkline. PR-eligible metrics: Distance, Active Calories, Total Calories, Elevation Ascended only — `isPersonalBest` returns false for Effort, HR, Duration, Exercise Minutes by service contract.

**Empty / insufficient data:**
- Comparative context: < 3 same-type workouts (excluding this one) with the metric → replace both lines with muted `Not enough data yet — log a few more sessions.`
- Sparkline: < 3 data points in 30 days → same muted message, chart container hidden.
- PR chip: not rendered when false; no placeholder.

**Accessibility:** title announced first; hero, comparative, sparkline (with summary trait), and PR chip follow. Close button reads "Close, button". Stat card chevron has `accessibilityHint("Opens metric details")`.

### Share Image Card

Tap the share icon → renders the workout as a styled PNG via SwiftUI `ImageRenderer` at @3x → presents iOS share sheet (`UIActivityViewController`). Self-contained card using FitNavi tokens, legible standalone outside the app.

**Card content:** workout name, date/time (time omitted when `workout.time == nil`), workout type, 2-column stat-card grid (mirrors the Workout Detail Summary), exercise list (Strength/HIIT only).

**Stat-card grid** mirrors Workout Detail Summary — same fields, order, icons, labels, value formats, color treatment (CONSTANTS § Stat Card Colors, § Effort Label Mapping, § Effort Color Mapping). Differences for the image:
- Static — no chevron, no tap.
- Smaller card sizing scaled for the 390pt-wide image.
- Cards render only when their value is non-nil; manual workouts collapse to 2–3 cards.

**Exercise cap:** max 10 exercises displayed; overflow shows muted `+X more exercises` line.

**Excluded:** session notes, navigation chrome (back, icon tray).

**Card styling tokens:** CONSTANTS § Share Image Card Styling (bg, borders, padding, header/footer, name, date, stat cards, exercise rows, dividers, image dimensions).

**Edge cases:**

| Scenario | Behavior |
|---|---|
| All optional fields nil | No stat cards; image shows name, date, type, and exercises (if any) |
| > 10 exercises | First 10 + `+X more exercises` (muted) |
| Bodyweight exercise (nil weight) | Displays as `{sets} × {reps} (BW)` |
| Very long workout name | Truncated with ellipsis at 2 lines max |
| Very long exercise name | Truncated with ellipsis at 1 line |
| Share sheet cancelled | No action; dismiss cleanly |
| Image render fails | Brief toast: "Couldn't generate image. Try again." (~2s) |

---

## Trends

**Purpose:** Visualize training trends with customizable chart layout.

### Chart Card System

Standard Sortable Card System (§ Standard Patterns) backed by `TrendsChart` records. Default seed: **Strength Tracker, Training Frequency, Personal Records, Training Load Trend**. Charts auto-update on workout log/edit/delete. An added chart not yet meeting its data threshold renders its empty-state message.

### Layout

Header: blue ellipsis (left). ✦ divider. Chart cards render vertically per Standard Sortable Card System.

### Trends Ellipsis Menu

One option: **"Add Charts"** (`chart.xyaxis.line`) → Add Charts Menu overlay (`FortiFitAddChartMenu`, mirrors `FortiFitAddWidgetMenu`).

### Chart Card Context Menu (Long Press)

| Item | SF Symbol | Behavior |
|---|---|---|
| See Info | `info.circle` | Opens See Info Modal (§ Standard Patterns) populated from INFO_COPY § Chart Info Modal Copy. Title `About [Chart Display Name]`. |
| Reorder Charts | — | Standard Reorder Edit Mode → persists to `TrendsChart.sortOrder`. |
| Delete Chart | — | Standard delete confirmation: `Delete [Chart Display Name]? This cannot be undone.` |

### Chart Definitions

| Chart (id) | Definition |
|---|---|
| **Strength Tracker** (`strengthTracker`) | Exercise dropdown + 30D/60D/90D toggles. Line chart of weight over time + latest value. |
| **Training Frequency** (`trainingFrequency`) | Bar chart of weekly sessions (8 weeks). Blue dashed target reference line + legend. |
| **Personal Records** (`personalRecords`) | Exercise dropdown listing only exercises with ≥1 PR event (§ PR Definition). Shows previous + current PR + dates as a 2-bar comparison (§ PR Layout). |
| **Training Load Trend** (`trainingLoadTrend`) | Line chart, one dot per day colored by zone (Low/Moderate/High/Peak). Blue dashed 7-day rolling average + zone-colored background bands + legend. |
| **Workout Volume** (`workoutVolume`) | Line chart of session volume (sets × reps × weight) for Strength/HIIT workouts. 30D/60D/90D toggles. Each dot = one workout. |
| **Effort Trend** (`rpeTrend`) | Bar chart of weekly average Effort (8-week rolling window). Horizontal dashed reference at Effort 7. |
| **Workout Type Breakdown** (`workoutTypeBreakdown`) | Donut (`SectorMark`) of workout-type proportions. Toggles: 30D / 60D / 90D / All Time. Segment colors per CONSTANTS § Workout Type Chart Colors. Type+count segment labels, legend below. |
| **Session Duration** (`sessionDuration`) | Bar chart of weekly average duration (8-week rolling). Horizontal dashed reference at `targetMinutesPerWorkout`. Only includes workouts with recorded duration. Legend with "Target" label. |

**Visual treatment:** Every chart in the table above is wrapped in `FortiFitChartCard` and inherits the shared gradient backdrop, inner plot hairline, header summary block, latest-point highlight, rounded bar tops, smoothed line interpolation, and donut center label (Workout Type Breakdown only) defined in § Standard Patterns → Trends Chart Card Visual Treatment. Per-chart anchor color and hero / caption formula are listed in CONSTANTS.md § Trends Chart Visual Tokens — never hardcoded in views.

### PR Definition

A **Personal Record (PR) event** occurs when a new max `weightKg` for an `exerciseName` exceeds the previous max across all earlier workouts. The first workout logging an exercise sets the baseline — not a PR (a PR requires a prior value to surpass). Collect distinct max `weightKg` values per `exerciseName`, ordered chronologically; record a PR each time a new chronological max exceeds all previous. Bodyweight exercises (nil `weightKg`) are excluded.

### PR Layout

**Exercise dropdown** at the top of the card — lists only exercises with ≥1 PR event, sorted alphabetically; default = first alphabetically.

**PR summary row** below dropdown — two columns: "PREVIOUS RECORD" (left, value + muted date) and "CURRENT RECORD" (right, value in Primary Accent Blue + muted date). Values formatted per `useLbs`.

**Bar chart** — Swift Charts `BarMark` with two bars: Previous Record (Elevated Surface bg + Border stroke) and Current Record (Primary Accent Blue, value annotation above bar). Y-axis weight per `useLbs`, origin at 0; X-axis "Previous" / "Current".

### PR Edge Cases

| Scenario | Behavior |
|----------|----------|
| Exercise has exactly 1 logged workout (baseline only, no PR) | Exercise excluded from dropdown |
| Exercise logged multiple times but weight never increased | Exercise excluded from dropdown (no PR event) |
| Exercise has exactly 1 PR event | Displayed: bars compare baseline vs. first PR |
| Exercise has multiple PR events | Displayed: bars compare second-most-recent PR vs. most recent PR |
| All PRs deleted via workout deletion | Exercise removed from dropdown. If no exercises remain, show empty state |
| Workout edit changes weight | PR timeline recalculated. Dropdown and chart update accordingly |
| `weightKg` is nil (bodyweight exercise) | Excluded from PR tracking |

### Chart Data Thresholds
| Chart | Minimum Data | Empty Message |
|-------|-------------|--------------|
| Strength Tracker | 2 workouts with selected exercise + recorded weight | "Log more workouts to display strength trends" |
| Training Frequency | 1 full Mon–Sun week with ≥ 1 workout | "Complete your first full week to see frequency trends" |
| Personal Records | 1 exercise with ≥ 1 PR event | "Log more workouts to display personal records" |
| Training Load Trend | 3 days with ≥ 1 workout in last 14 days | "Log more workouts to display load trends" |
| Workout Volume | 2 Strength Training or HIIT workouts with ≥ 1 ExerciseSet | "Log more Strength or HIIT workouts to display volume trends" |
| Effort Trend | 1 full Mon–Sun week with ≥ 1 workout with recorded Effort | "Log workouts with effort ratings to display effort trends" |
| Workout Type Breakdown | 2 workouts of any type | "Log more workouts to display your training breakdown" |
| Session Duration | 1 full Mon–Sun week with ≥ 1 workout with recorded duration | "Log workouts with duration to display session length trends" |

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | All charts show empty state messages |
| Partial | Charts meeting threshold render; others show empty message |
| Populated | All charts with full data and controls |
| Reorder edit mode | line.3.horizontal SF symbol drag handles visible on all chart cards; cards draggable; context menu disabled; tap outside to exit |
| All Charts Removed | Centered muted message: "Tap the menu to add charts to your Trends screen." Ellipsis remains accessible. |

### Expand Affordance

Every chart card on the Trends screen renders a left-chevron-style expand button at the top-trailing edge of the card (mirrors the chevron treatment on Workout Detail's `FortiFitStatCard`). Tapping pushes the corresponding `FortiFitChartDetailView` onto the navigation stack — see § Trends Chart Detail. The button uses identifier `trendsChart_{chartId}_expandButton`. Long-press context menu (See Info, Reorder, Delete) on the card body is unchanged.

---

## Trends Chart Detail

**Purpose:** Per-chart expanded view that gives users a larger canvas, wider time ranges, comparison-period delta, tap/scrub data-point inspection, See Info access, and lateral swipe between charts.

### Entry & Navigation

Pushed onto the navigation stack by the chart card's expand button (§ Trends → Expand Affordance). Standard iOS right-to-left push transition. Back navigation via the Back Navigation Chevron (§ Standard Patterns) at top-leading. Edge-swipe-back is **not** wired up on this screen — horizontal swipes are reserved for the paging `TabView` that cycles between charts in `sortOrder` (see § Swipe Paging), and the two gestures would conflict.

### Layout (top-to-bottom)

| Slot | Content |
|---|---|
| Top bar | Back chevron (leading) · chart title (centered) · See Info `info.circle` (trailing, identifier `trendsChartDetail_{chartId}_seeInfoButton`) |
| Header summary block | Hero value + caption + comparison-delta band — see CONSTANTS.md § Trends Chart Detail View → Header Summary (Detail Variant) |
| Range toggles | Per-chart eligible toggles (D / W / M / 6M / 1Y / All Time) per CONSTANTS.md § Trends Chart Detail View → Range Toggle by Chart Type |
| Plot area | Larger variant of `FortiFitChartCard` plot area — same gradient, hairline, latest-point highlight, smoothed line, rounded bars; full-numeric Y-axis labels (no `K`/`M` abbreviation) |
| Selection layer | Tap-to-select on every data point + scrub-to-select on line charts — see § Selection & Scrubbing |
| Footer (per-chart) | Chart-specific extras (PR timeline labels, donut legend table, etc. — see Per-Chart Detail Variants) |

### Selection & Scrubbing

Tapping a `BarMark` or line-chart data point selects it; non-selected marks fade to 35% opacity; a floating annotation appears above the selected mark with auto-flip near the chart top edge. Drag along a line chart scrubs continuously: a vertical `RuleMark` follows the finger, the annotation updates live, and a light haptic fires on each new snapped data point. Drag-release leaves the last-touched point selected (no auto-deselect on lift). Selection clears on range-toggle change, swipe-paging to a different chart, or back navigation.

Selection availability per chart type lives in CONSTANTS.md § Trends Chart Detail View → Selection State.

### Swipe Paging

Horizontal swipe (left/right) within the detail view pages between the user's other Trends charts in `TrendsChart.sortOrder`. Wraps at both ends. Active chart's identity is preserved across back-and-re-enter from the same card.

### Per-Chart Detail Variants

Most charts are a faithful larger version of the compact card with selection + scrubbing. Two charts get structural changes available only on the detail view:

| Chart (id) | Detail Variant |
|---|---|
| `personalRecords` | Replaces the 2-bar comparison with a **full PR timeline** — line chart over `TrendsChartService.fullPRTimeline(for: exerciseName)`. Each PR event is a labeled point: date, weight (per `useLbs`), and delta from prior PR. Identifier `trendsChartDetail_personalRecords_timelinePoint_{index}`. The compact card stays unchanged. |
| `workoutTypeBreakdown` | Donut occupies the upper half; lower half adds a **sortable legend table** with columns `Type · Count · % · Avg Duration`. Sort cycles count desc → count asc → alphabetical on tap of any header. Row identifier `trendsChartDetail_workoutTypeBreakdown_legendRow_{index}`; sort-header identifier `trendsChartDetail_workoutTypeBreakdown_legendSortHeader_{column}`. |
| All others | Compact card's structure, larger sizing, full-numeric Y-axis, expanded range toggles. |

### See Info

Inline `info.circle` icon at top-trailing opens the standard See Info Modal (§ Standard Patterns) populated from INFO_COPY.md § Chart Info Modal Copy for the chart type. Same modal as the long-press path on the compact card.

### Empty State

Mirrors the compact card: when the chart's data threshold (§ Chart Data Thresholds) isn't met, the gradient, hairline, header summary, and plot marks all hide; the existing centered muted empty message renders. Range toggles, See Info, and back chevron remain available.

### Accessibility

Push focuses the chart title first (announces title + summary together as a single label). Selection callout announces as a separate label scoped to the selected mark. Range toggles announce as a `Tab` group. Swipe-paging respects VoiceOver's two-finger flick gestures.

---

## Goals

**Purpose:** Track strength, repetition, speed/distance, and weekly workout frequency targets.

### Layout
Left: blue ellipsis icon (functional — opens Goals ellipsis menu). Right: "+" button. ✦ divider. "Your Targets" header.

**Card stack order:** In-progress goals (progress < 100%) render before completed goals (progress >= 100%) — completed goals sink to the bottom of the list. Within each group, manual `sortOrder` from Reorder Edit Mode is preserved. Mirrors the completed-card sink convention used on the Plan tab and the Today's Plan Detail Sheet.

### Goal Card Design

Each card has a three-section left column (goal details) and a large progress ring right-justified on the trailing side. Rings are ~120–140pt diameter, right-justified consistently across all goal types — even dual-arc Speed and Distance rings (no legend-induced centering).

**Three-section left column** — sentence-case Primary Accent labels (11/700, 2px spacing) over Primary Text values:

| Label | Value |
|---|---|
| Header (varies by type — see below) | Goal name (e.g., "Bench Press", "5K Run") |
| Target | Type-dependent (table below) |
| Progress | Type-dependent (table below) |

**Header labels** (strings live in CONSTANTS § Goal Card Header Labels — never hardcoded):

| Goal type | Sub-case | Header label |
|---|---|---|
| Strength PR | — | STRENGTH GOAL |
| Repetitions PR | — | REPS GOAL |
| Speed and Distance | Both targets set | SPEED GOAL |
| Speed and Distance | Duration only | ENDURANCE GOAL |
| Speed and Distance | Distance only | DISTANCE GOAL |
| Number of Weekly Workouts | — | FREQUENCY GOAL |

**Target / Progress values:**

| Goal type | Target | Progress |
|---|---|---|
| Strength PR | `225 lbs` | `100 / 225 lbs` |
| Repetitions PR | `25 reps` | `10 / 25 reps` |
| Speed/Distance (distance only) | `5 miles` | `2.00 / 5.00 mi` |
| Speed/Distance (duration only, endurance) | `30 minutes` | `45 / 30 min` |
| Speed/Distance (both — speed target) | `5 miles in 30 minutes` | Two stacked lines: `2.00 / 5.00 mi` over `45 / 30 min` |
| Number of Weekly Workouts | `3 workouts / week` | `14 / 3` |

**Progress ring** (trailing, ~120–140pt). Centered inside the ring: the goal-type SF Symbol silhouette at dynamic opacity (see CONSTANTS § Goal Silhouette Opacity — 10% at 0% → ~40% at 100%, bumped to 50–60% on completion). The overall percentage is *not* rendered inside the ring — it surfaces via the ring-tap tooltip (§ below). Applies to all goal types including dual-arc.

| Goal type | SF Symbol | Ring |
|---|---|---|
| Strength PR | `figure.strengthtraining.traditional` | Single ring, goal's `colorIndex` |
| Repetitions PR | `figure.strengthtraining.traditional` | Single ring, goal's `colorIndex` |
| Speed/Distance | `figure.run` | Dual-arc when both targets set; single ring otherwise (purple if distance-only, cyan if duration-only) |
| Weekly Workouts | `calendar` | Single ring, goal's `colorIndex` |

**Dual-arc ring (Speed/Distance with both targets):** Two concentric arcs — outer = distance (purple `#4B2893`), inner = duration (light cyan `#8FE6F6`). Shared center symbol. Legend never inline; surfaced via ring-tap tooltip.

**Ring tap tooltip:** Tap toggles a subtle overlay tooltip just below the ring, arrow-pointer up. Overlay (not inline) — doesn't push card content. Re-tap or outside tap dismisses. Animation 0.15s opacity fade.

| Goal type | Tooltip contents |
|---|---|
| Single-ring goals (incl. single-target Speed/Distance) | Overall progress percentage only (e.g., "44%"). Primary Text, ~18–20pt 800 weight. |
| Dual-arc Speed/Distance | Three stacked: (1) overall percentage headline (lower of distance% and duration% after clamping), (2) Distance legend row (purple dot + "Distance"), (3) Duration legend row (cyan dot + "Duration"). Legend rows use Secondary Text 11/700/2px-spacing. |

Completed (100%) ring still surfaces the tooltip — value is "100%". Dual-arc completed shows the full legend alongside "100%".

**Accessibility:** overall progress percentage is in each card's accessibility label so VoiceOver users hear it without discovering the tap. Dual-arc cards' accessibility label also describes the Distance/Duration color mapping.

**Completed state treatment** (goal at 100%):
- Positive Green border, faint Positive Green wash (3% opacity) across card surface — matches the completed-card convention used on the Plan tab and the Today's Plan Detail Sheet.
- "COMPLETED [Formal Date]" micro-label centered at top (Secondary Text, 11/700, 2px spacing, uppercase). Date from `Goal.lastCelebratedDate` (e.g., "COMPLETED APR 17, 2026").
- Ring fully filled.
- Silhouette tinted Primary Accent Blue at 85–100% opacity ("lit up"). Applies to all goal-type silhouettes.
- 0.2–0.3s ease crossfade on the silhouette transition, synchronized with border/wash/label appearing. Independent of the Completion Pulse Animation.
- No "✦ VICTORY ✦" label — replaced by the COMPLETED micro-label + visual treatment.

**Completion Pulse Animation:** On Goals screen entry, if any goal's `lastCelebratedDate == today`, the ring fires a 1–1.5s soft Primary Accent halo glow that settles back into the static completed state. Once per visit; re-triggers only on screen re-entry while still today.

**Card Tease Animation:** Standard Long-Press Tease (§ Standard Patterns).

### Expandable Card with Sparkline

Gray chevron always visible at the bottom center of each goal card — points down when collapsed, up when expanded. Tap → reveals a 30-day sparkline.

Expanded section structure (always present, regardless of data state):
1. **"LAST 30 DAYS" header** — left-aligned, muted 11/700 uppercase 2px-spacing.
2. **Sparkline chart area** — Swift Charts, full content width.
3. **Footer note** — muted italic, content per the data-state table below.

| Data state | Chart | Footer note |
|---|---|---|
| Populated (≥2 snapshots) | Swift Charts `LineMark`. One point per workout day plotting the day's best-of-day session value (top set weight for Strength PR, highest reps for Reps PR, best matching-workout `overallProgress %` for Speed/Distance, end-of-day count for Weekly Workouts; see SERVICES § GoalSnapshotService → Per-Workout Value Computation). Reflects per-session performance including regressions/light sessions — not just PR events. Days with no matching workout carry forward the previous value. Only days that exist are plotted (no zero-padding for goals with <30 days of history). | "Goal progress over the last 30 days" |
| Brand-new (0–1 snapshots) | Skeleton flat dashed line at chart midpoint, full width (Border color, `StrokeStyle(dash: [4, 4])`). No data point, no axis ticks. | "Log a workout to start tracking progress" |

Once the goal has 2+ snapshots, the chart transitions to the real line on next expand (no special animation).

**Other rules:** multiple cards can be expanded simultaneously · 0.3s ease expand/collapse + sparkline fade-in on expand · default collapsed · after "Reset Goal Progress" all snapshots are wiped, sparkline returns to brand-new skeleton until new in-scope workouts produce snapshots (SERVICES § Reset Goal Progress, § Reset Scoping) · data source: `GoalSnapshot` (PRD § Data Model, SERVICES § GoalSnapshotService).

Goal auto-update behavior (including speed-target logic): SERVICES § Goal Auto-Update.

### Goals Ellipsis Menu

| Item | SF Symbol | Behavior |
|---|---|---|
| Filter Goals | `line.3.horizontal.decrease.circle` | Submenu: **Active** (below 100%), **Completed** (at 100%), **All** (default ✓). Checkmarks indicate selection. Resets to "All" on every app launch — not persisted. |
| Expand / Collapse All | `rectangle.expand.vertical` (when most cards collapsed → label "Expand All") / `rectangle.compress.vertical` (when most expanded → label "Collapse All") | Toggles all goal cards. Symbol swaps with the label. |

### Long-Press Context Menu

| Item | Behavior |
|---|---|
| Delete Goal | Standard delete confirmation: `Delete [Goal Title] goal? This cannot be undone.` On confirm: removes goal + cascade-deletes GoalSnapshot records + re-indexes `sortOrder`. |
| Reset Goal Progress | Confirmation: `Reset [Goal Title] progress to zero? This cannot be undone.` On confirm: zeros current values + clears `lastCelebratedDate`. **Hidden entirely for Weekly Workouts** (runtime-derived value, can't be manually reset). Long-press only — not in the ellipsis menu. |
| Reorder Goals | Standard Reorder Edit Mode. Always visible regardless of goal count. |

### Reorder Edit Mode
Per § Standard Patterns: Standard Reorder Edit Mode. Persists to `Goal.sortOrder`.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "Set your first goal to start tracking." + ADD button |
| Populated | Full goal list with three-section left columns and large right-justified progress rings |
| Goal Completed | Positive Green border, faint green wash (3% opacity), "COMPLETED [Date]" micro-label at top center, ring fully filled with silhouette tinted Primary Accent Blue at 85–100% opacity (crossfades in over 0.2–0.3s) |
| Completion Pulse | Brief glow/pulse animation on ring when user navigates to Goals screen with a goal whose `lastCelebratedDate` = today (once per visit) |
| Ring Tap Tooltip | Overlay below ring, surfaced on ring tap. Single-ring goals show overall progress percentage; dual-arc Speed and Distance shows percentage headline + Distance/Duration legend. Dismissed by re-tap or outside tap. |
| Card Expanded | "LAST 30 DAYS" header above sparkline chart area. Populated goals show real line chart with "Goal progress over the last 30 days" footer note. Brand-new goals show a flat dashed skeleton line with "Log a workout to start tracking progress" footer note |
| Filtered (Active) | Only goals below 100% shown |
| Filtered (Completed) | Only Completed goals shown |
| Reorder edit mode | Drag handles (≡) visible on all goal cards; cards draggable; context menu disabled; tap outside to exit |

---

## Create Goal

**Purpose:** Create a new goal.

### Layout

Back chevron (§ Standard Patterns → Back Navigation Chevron) · "Create Goal" heading · Goal Type selector: "STRENGTH PR" (default), "REPETITIONS PR", "SPEED AND DISTANCE", "NUMBER OF WEEKLY WORKOUTS".

| Type | Fields | Validation |
|---|---|---|
| Strength PR | Exercise dropdown (Bench Press, Barbell Squats, Deadlifts, Overhead Press, Barbell Rows, Incline Bench Press, Custom) — Custom uses autocomplete name input. Current weight / Target weight side by side. | Exercise + target weight > 0 |
| Repetitions PR | Same exercise dropdown + Custom + autocomplete. Current reps / Target reps side by side. | Exercise + target reps > 0 |
| Speed and Distance | Goal name input. Workout Type dropdown restricted to **Cardio** and **HIIT** only (the only types meaningful for speed/distance/duration tracking — Strength Training, Yoga, Pilates, Other are excluded). Optional Current/Target distance (km or mi per `useMiles`). Optional Current/Target duration (minutes). Both targets = speed target (completion requires both); duration alone = endurance (higher = better). Distance stored as km. | Name + ≥1 target > 0 |
| Number of Weekly Workouts | Target shown read-only from `targetWorkoutsPerWeek` (UserSettings). Muted italic note below: *"This goal tracks your weekly workout target. To change the target, long-press the Weekly Streak widget on the Home screen and tap Configure Settings."* No editable fields — target controlled via Weekly Streak Settings Modal. Auto-updates from current week's workout count (Mon–Sun). | Always valid; save enabled immediately |

"Save Goal" button at bottom. **Singleton constraint:** only one Weekly Workouts goal can exist; if one already exists, that option in the Goal Type selector is grayed out with a muted "Already added" label.

**Edit mode:** Same view, entered by tapping a goal card. On save, if the goal's `resetDate` is non-nil it's cleared to nil — treating a definition edit as deliberate re-baselining that brings previously out-of-scope workouts back into scope (SERVICES § Reset Scoping, § Reset Goal Progress). Clearing also triggers `GoalSnapshotService.rebuildSnapshots(goal:)` to repopulate the sparkline. No explicit "this will bring old workouts back" warning — the interaction is treated as intentional. Workout Type, Exercise, and Current fields are read-only in edit mode.

---

## Settings

**Purpose:** Configure unit preferences and manage Apple Health integration.

### Layout

Back chevron (§ Standard Patterns → Back Navigation Chevron) · "Settings" heading.

**General** section: Weight Unit (KG/LBS toggle) · Distance Unit (KM/MILES toggle). Changes take effect immediately.

✦ divider.

**Apple Health & Devices** section: HealthKit integration controls and Apple Watch scheduling. See HEALTHKIT § 16 (settings architecture), § 17 (authorization), WORKOUTKIT.md § 9 (authorization), and § 10 (UI surfaces). Both cards live under a single heading — **no separate "Apple Watch" header**.

### Apple Health & Devices — Apple Health Card

Toggle: "Connect to Apple Health" — FortiFitSegmentedToggle styled like the General toggles but functionally on/off, not a unit selector. ID `settings_appleHealthToggle`.

Description below toggle (muted, 13/700): *"Import workouts from Apple Watch and other Health-connected apps. Linked workouts appear automatically and can't be fully unlinked in bulk."*

Status line below description (muted, 11/700, uppercase, 2px spacing) and conditional buttons — content per the state table below.

### Apple Health Card — State Table

Four possible states driven by (toggle on/off) × (iOS authorization status):

| Toggle | iOS Auth | Status Line | Visible Buttons | Behavior on Toggle Tap |
|---|---|---|---|---|
| Off | Any (including not-yet-requested) | *(hidden — no status shown)* | None | Flipping on triggers authorization request (if not yet granted/denied); otherwise simply re-enables sync using cached authorization. |
| On | Granted | `CONNECTED · LAST SYNC {relative time}` OR `CONNECTED · NEVER SYNCED YET` | **"Sync Now"** (blue outlined, full-width) — accessibility identifier `settings_appleHealthSyncNowButton`. Tap → triggers immediate `HealthKitSyncService.importPendingWorkouts()`. Shows transient "Syncing…" label on button until complete, then updates status line. | Flipping off immediately suspends all sync activity. Existing linked workouts retain `healthKitUUID`. Confirmation alert: "Turn off Apple Health sync? Imported workouts will remain in FitNavi but new workouts from Apple Health won't appear automatically. Cancel / Turn Off." |
| On | Denied | `PERMISSION DENIED IN IOS SETTINGS` | **"Open iOS Settings"** (blue outlined, full-width) — accessibility identifier `settings_appleHealthOpenSettingsButton`. Tap → deep-links via `UIApplication.openSettingsURLString`. | Same as granted — confirmation alert, then flip off. |
| On | Not yet requested | *(transient, typically <1s)* | None during transient state | The authorization prompt fires immediately; this state resolves to granted or denied within a second. UI doesn't need to handle the transient case explicitly — just render the previous state until the prompt resolves. |

### Relative Time Formatting for Status Line

The "Last sync" timestamp follows iOS's relative date conventions:
- <1 min → "JUST NOW"
- 1–59 min → "X MIN AGO"
- 1–23 hr → "X HR AGO"
- 1–6 days → "X DAYS AGO"
- >7 days → "ON {date}" (e.g., "ON APR 15")

Source: `UserSettings.healthKitLastSyncDate`. Updated after every successful sync by `HealthKitSyncService`.

### Toggle-On Flows

**First-time toggle-on:** FitNavi calls `HealthKitClient.requestAuthorization()` → iOS presents the native prompt (HEALTHKIT § 17) → user grants or denies → control returns to FitNavi. On grant: status updates to "CONNECTED · NEVER SYNCED YET", catch-up sync fires immediately, status updates to "CONNECTED · JUST NOW" on completion. On deny: status shows "PERMISSION DENIED IN IOS SETTINGS"; toggle stays on (user's expressed intent), but no sync runs; "Open iOS Settings" button appears.

**Subsequent toggle-off → toggle-on:** No re-authorization prompt (iOS caches the original grant). Sync resumes immediately from the persisted `HKQueryAnchor`; any upstream changes during the off period processed in the next catch-up sweep.

### Confirmation Alert Copy

Turn-off confirmation: Title "Turn off Apple Health sync?" / Message "Imported workouts will remain in FitNavi but new workouts from Apple Health won't appear automatically." / "Cancel" + destructive-red "Turn Off".

### Apple Health & Devices — Apple Watch Card

Sibling card to Apple Health within the same section — **no separate section header, no FortiFitDivider between them**. See WORKOUTKIT.md § 9 (authorization) and § 10 (UI surfaces) for full context.

Toggle: "Push planned workouts to Apple Watch" — FortiFitSegmentedToggle styled like the General toggles but functionally on/off, not a unit selector. ID `settings_appleWatchToggle`. First flip-on triggers `WorkoutScheduler.shared.requestAuthorization()` (just-in-time pattern — see WORKOUTKIT.md § 9).

Description below toggle (muted, 13/700): *"Push planned workouts from your Plan tab to your Apple Watch. Pushed workouts appear in the Workout app's Scheduled section and complete automatically when finished. Requires watchOS 11 or later."*

**No status line, no "Sync Now" button, no "Last sync" timestamp** — WorkoutKit operations are imperative one-shots tied to per-card toggles and reconciliation, with no useful "manual sync" or "connected" semantics to surface. Conditional button (e.g., "Open iOS Settings" on denied) per the state table below.

### Apple Watch Card — State Table

Four possible states driven by (toggle on/off) × (WorkoutKit authorization status):

| Toggle | WK Auth | Status Line | Visible Buttons | Behavior on Toggle Tap |
|---|---|---|---|---|
| Off | Any (including not-yet-requested) | *(hidden — no status shown)* | None | Flipping on triggers `WorkoutScheduler.shared.requestAuthorization()` if not yet determined; otherwise re-enables sync using the cached authorization state. On grant, reconciliation runs (WORKOUTKIT.md § 7). |
| On | Granted | *(none)* | None | Flipping off → confirmation alert (see below). On confirm: every `ScheduledWorkout` with `syncToAppleWatch == true` has its plan removed from any paired Watch via `WatchScheduleService.removePlan(_:)`. Per-card flags retained for restoration. |
| On | Denied | `PERMISSION DENIED IN IOS SETTINGS` | **"Open iOS Settings"** (blue outlined, full-width) — ID `settings_appleWatchOpenSettingsButton`. Tap → `UIApplication.openSettingsURLString` deep-link. | Same as granted — confirmation alert, then flip off. |
| On | Not yet requested | *(transient — typically <1s)* | None during transient state | Authorization prompt fires immediately; resolves to granted or denied. UI shows previous state until the prompt resolves. |

### Apple Watch Card — Toggle-On Flows

**First-time toggle-on:** FitNavi calls `WorkoutScheduler.shared.requestAuthorization()` → iOS presents the native dialog → user grants or denies → control returns to FitNavi. On grant: status updates to "CONNECTED", reconciliation runs (re-schedules every `ScheduledWorkout` with `syncToAppleWatch == true` and gates passing). On deny: status shows "PERMISSION DENIED IN IOS SETTINGS"; toggle stays on (user's expressed intent), no plans are scheduled, "Open iOS Settings" button appears.

**Subsequent toggle-off → toggle-on:** No re-authorization prompt (iOS caches the decision). Reconciliation runs immediately; previously-synced cards re-register their plans on the Watch.

### Apple Watch Card — Confirmation Alert Copy

Turn-off confirmation: Title "Turn off Push to Apple Watch?" / Message "All scheduled workouts currently pushed to your Apple Watch will be removed. You can turn it back on anytime — your push preferences will be remembered." / "Cancel" + destructive-red "Turn Off".

### States

| State | What the User Sees |
|-------|-------------------|
| Initial load (General section) | KG/LBS and KM/MILES toggles reflect current preferences |
| Apple Health off | Toggle off, description visible, no status line, no buttons |
| Apple Health on — connected | Toggle on, description, "CONNECTED · …" status, "Sync Now" button |
| Apple Health on — denied | Toggle on, description, "PERMISSION DENIED IN IOS SETTINGS" status, "Open iOS Settings" button |
| Sync in progress (Apple Health) | Same as Apple Health connected state, but "Sync Now" button shows transient "Syncing…" label and is disabled until complete |
| Apple Watch push off | Toggle off, description visible, no status line, no buttons |
| Apple Watch push on — connected | Toggle on, description, "CONNECTED" status, no buttons |
| Apple Watch push on — denied | Toggle on, description, "PERMISSION DENIED IN IOS SETTINGS" status, "Open iOS Settings" button |

---

## Match Prompt Sheet

**Purpose:** Resolve lower-confidence deduplication matches between HealthKit-imported workouts and existing FitNavi workouts. See HEALTHKIT.md § 13 and SERVICES.md § WorkoutMatcher for the matcher logic that produces pending matches.

### Trigger

Modal sheet on app foreground transition when `WorkoutMatcher.pendingMatches()` returns ≥1 pairing. One sheet per match; multiple queue sequentially (next presents after previous resolves). Foreground transition is the *sole* automatic trigger — never on navigation, tap, or settings toggle. Always dismissible via "Decide Later" (leaves match in queue) — user never trapped.

### Layout

iOS modal sheet, `.large` detent (or custom `.height(...)` sized to content — never `.medium`, which truncates the body paragraph). Swipe-down maps to "Decide Later".

- **Header:** "Possible Match" (Primary Text 20/900, centered).
- **Body paragraph:** *"Apple Health imported a workout that looks similar to one you already logged. Would you like to link them?"* (Secondary Text 14px centered, `.fixedSize(horizontal: false, vertical: true)` to prevent vertical clip).
- **Side-by-side summary cards** (two FortiFitCards):

  | Field | Left card (HealthKit) | Right card (FitNavi) |
  |---|---|---|
  | Header label | HealthKit-pink heart (`heart.fill`) + "FROM APPLE HEALTH" (HealthKit Pink, 11/700 uppercase, 2px spacing) | "YOUR LOG" (Primary Accent Blue, same treatment) |
  | Type | Workout type pill (FortiFit category mapped from HK type) | Workout type pill |
  | Title | `healthKitActivityType` (Primary Text 14/semibold) | `workout.name` (Primary Text 14/semibold) |
  | Time | Start time (e.g., "7:02 PM", muted 13px) | `workout.time` (muted 13px) |
  | Duration | If present (muted 13px) | If present (muted 13px) |
  | Other | Distance (per `useMiles`) · avg HR · active kcal — each muted 13px when present | Effort (e.g., "Effort 7") · ExerciseSets count — each muted 13px when present |

  Both header labels must wrap to a second line rather than truncate — `.lineLimit(nil)` + `.fixedSize(horizontal: false, vertical: true)` + `.minimumScaleFactor(1.0)`. Heart/dot stays on the first wrapped line's baseline.

- **Primary action row** (three vertically stacked buttons):

  | Button | Style | ID | Action |
  |---|---|---|---|
  | "Link these workouts" | Full-width blue-filled | `matchPromptSheet_linkButton` | `WorkoutMatcher.resolvePending(decision: .link)` → SERVICES § WorkoutMatcher → Link Application → dismiss + "Workouts linked." toast (~2s) |
  | "Keep separate" | Full-width blue-outlined | `matchPromptSheet_keepSeparateButton` | `WorkoutMatcher.resolvePending(decision: .keepSeparate)` → creates `WorkoutMatchRejection` → dismiss, no toast |
  | "Decide later" | Text-only link (muted) | `matchPromptSheet_decideLaterButton` | `WorkoutMatcher.resolvePending(decision: .decideLater)` → leaves match in queue → dismiss, no toast |

  **Ordering rationale:** Link is primary — most common correct answer when the matcher has already filtered for same-type, same-day, within-4-hours. Keep Separate secondary (deliberate but less common). Decide Later de-emphasized (low-commitment punt).

### Post-Resolution Behavior

- **Link:** HK-owned fields copy from snapshot to the FitNavi Workout per SERVICES § WorkoutMatcher → Link Application; user-owned fields preserved; `lastModifiedDate` bumped; Workout Cascade fires. Workout now appears HK-linked everywhere.
- **Keep Separate:** `WorkoutMatchRejection` persists the `(healthKitUUID, workoutId)` pair; future sync won't re-propose. HK workout proceeds to auto-create as a separate FitNavi Workout if not already created.
- **Decide Later:** Match stays queued; re-prompts next foreground. No auto-create yet — HK workout remains in candidate pool.

### Sequential Multi-Match

3 pending matches → 3 sequential sheets. Each resolves independently. No batch-resolve in MVP.

### Accessibility

Button IDs above. VoiceOver traversal: header → cards left-to-right → buttons top-to-bottom. No custom accessibility actions needed.

### States

| State | What the user sees |
|---|---|
| Match queued | Sheet presents on foreground; summary cards + three actions |
| Resolving (transient) | After tap: dismiss; toast or next sheet appears |
| No pending matches | No sheet — normal app state |
