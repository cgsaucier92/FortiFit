# SCREENS.md: FitNavi Screen Definitions

> Full layout descriptions, state tables, and interaction details for every screen.
> For data models, see `PRD.md` Section 5. For algorithms, see `SERVICES.md`. For constants, see `CONSTANTS.md`.

---

## Standard Patterns

These patterns are referenced throughout. Implement once, reuse everywhere.

**Delete Confirmation:** Alert title "Delete [Item Name]?" with body "This cannot be undone." Two actions: "Cancel" (default) and "Delete" (destructive, red). Cancel dismisses without action.

**Ellipsis Menu:** Blue ellipsis icon (16px). Tapping opens dropdown menu. Menu dismisses on outside tap.

**Long-Press Tease:** Cards that support long-press context menus (Workout Type cards, Home widgets, Goal cards, Trends chart cards, Saved Template cards, Scheduled Workout cards) share a single tease animation — a slight lift/scale on press hold that signals an imminent context menu. Implementation reuses the Home widget tease — do not invent a new animation curve.

**Standard Reorder Edit Mode:** Activated from a context menu option named "Reorder [Items]". Behavior:
- Drag handles (≡) appear on the right side of each card (muted #737373, 16px).
- Long-press anywhere on a card (handle or body) to pick up. Held card elevates with shadow; other cards animate to make room (0.2s ease). Drop snaps the card into place.
- New order saved automatically — the corresponding `sortOrder` field is re-indexed starting from 0 and persisted to SwiftData on drop.
- Cards maintain full styling during reorder mode and drag.
- Long-press context menu is disabled during reorder mode (no accidental delete while dragging).
- Exit by tapping anywhere outside a card. Drag handles disappear. No "Done" button.
- With a single card, reorder mode can be entered but drag has no visible effect.

Home widgets use a variant of this pattern that combines delete + drag in a single edit mode — see § Home Screen (Widget Edit Mode).

**Standard Sortable Card System:** The Home widget grid and the Trends chart list are both sortable card systems backed by SwiftData records (`HomeWidget`, `TrendsChart`) with a `sortOrder` field. Shared behavior:
- On first launch (no records exist), default cards are seeded in a defined order. After seeding, the user has full control.
- Cards render vertically in ascending `sortOrder`.
- **Add Menu:** Opened from the screen's ellipsis menu. Centered overlay with dimmed background. Scrollable list of all card types from AppConstants. Each row: display name (primary text), brief description (muted), "Add" button. Already-added types show a muted "Added" label instead. Tapping "Add" creates a record at max `sortOrder` + 1, dismisses the overlay, and renders the card immediately with live data (or the appropriate empty state if data thresholds are not met). Dismiss via outside tap or close button.
- **Delete:** Long-press card → context menu → "Delete [Item]" → standard delete confirmation. Removes only the sortable record; no underlying workout data affected. Remaining cards re-index `sortOrder`.
- **Reorder:** Long-press card → context menu → "Reorder [Items]" → enters Standard Reorder Edit Mode.
- **All Removed state:** Centered muted message inviting the user to add items via the ellipsis menu. Ellipsis and any non-card screen chrome remain accessible.

Each screen specifies only its seed defaults, card definitions, and any deviations from this pattern.

**Scroll Fade Header:** Every screen with scrollable content uses a floating header overlay that creates a fade effect as content scrolls beneath it. Structure:

- `ZStack(alignment: .top)` containing: (1) `ScrollView` with `.scrollClipDisabled()`, (2) a fixed header `VStack` rendered on top.
- Scroll content uses `.padding(.top, headerHeight)` where `headerHeight` is measured dynamically via a `GeometryReader` overlay on the header.
- Header background: `FortiFitColors.background.opacity(0.90)`. Below the header, a 30pt `LinearGradient` fades from the same color to `.clear`, with `.allowsHitTesting(false)`.
- Header contains only top-level action buttons (back, ellipsis, plus, share/edit/delete). Screen headings (`FortiFitScreenHeading`) remain in scroll content.
- FortiFitDivider in the header is **per-screen**: kept on form/detail screens (Log Workout, Create Template, Schedule Workout), removed on list/tab screens (Home, Workouts, Plan, Trends, Goals, Saved Templates, Add Goal, Workout Detail).
- Empty states use `.padding(.top, headerHeight)` so they sit below the floating header.

**Peripheral Apple Workout Glyph:** A small inline glyph rendered alongside workout metadata on compact surfaces to indicate the workout was recorded via Apple's Workout app on Apple Watch. Component: `FortiFitHealthGlyph.swift` (see PRD.md § Project Structure → Design/Components/) — implementation already encapsulates the visual treatment.

**Rendering scope (Apple Watch source only):** the glyph renders **only when** `workout.healthKitUUID != nil` AND `workout.healthKitSourceBundleID` resolves to Apple Watch's source bundle (i.e., `HealthKitClient.sourceName(for:)` returns `Apple Workout`). HK-imported workouts from other sources (Strava, Peloton, etc.) do **not** render this glyph on peripheral surfaces. Future per-source glyphs may be added later — for now, non-Apple-Watch HK workouts look identical to manual workouts on these compact surfaces.

**Position:** Trailing metadata on the workout's date row, separated by ` · ` from the date. The glyph is always the last token on the date row. Duration and distance (if present) render on a separate third row below the date row — they are never on the same row as the glyph.

Examples:
- `Apr 23, 2026 · [glyph]` (date row with glyph)
- `45 min` (third row — duration)
- `Apr 23, 2026` (date row without glyph, manual workout)

**Used on (per the scope rule above):**
- Home → Recent Workouts list rows
- Workouts tab → Expanded Workout Preview Rows
- Plan tab → Logged-only workout cards and completed scheduled workout cards linked to an Apple Watch–sourced Workout

**Not used on:** Workout Detail (which uses the full Source Indicator row instead — see § Workout Detail), Log Workout (which uses disabled fields + inline `info.circle` popovers instead — see § Log Workout § Edit Mode — HealthKit-Linked Workouts), Trends, Goals, any widget body. The peripheral glyph is scoped exclusively to compact workout-metadata surfaces.

**See Info Modal:** Shared modal sheet that explains a single feature (a chart, a widget, etc.) in user-friendly depth. Opened via a long-press context-menu item labeled "See Info" with SF Symbol `info.circle`. Used by Trends chart cards (Strength Tracker, Training Frequency, etc.) and by Home widgets (Training Load, Power Level). Reuses one component across both surfaces.

**Component:** `FortiFitSeeInfoModal.swift` (see PRD.md § Project Structure → Design/Components/). Takes a generic content struct (`title: String`, `intro: String`, `sections: [(heading: String, body: String)]`). Caller supplies the content from the appropriate per-surface lookup in CONSTANTS.md.

**Presentation:** iOS modal sheet (sheet presentation, `.large` detent). Swipe-down to dismiss. Background uses Card Surface `#1a1a1a`.

**Header:** Centered title — "About [Subject]" (e.g., "About Strength Tracker", "About Training Load"). Primary Text `#e5e5e5`, 20px, 900 weight, sentence case, centered. Title style matches the Match Prompt Sheet header (see § Match Prompt Sheet).

**Close button:** Top-right corner, 24x24pt circular, `#2d2d2d` bg, `#404040` border, muted `×`. Same close-button pattern used by the Saved Templates QR Modal and Settings widget modals. Accessibility identifier `seeInfoModal_closeButton` (shared across all uses of this modal).

**Body:** Scrollable. Standard 20px horizontal padding, 24px top padding below the header. Content rendered top-to-bottom:

1. **Intro paragraph** — first paragraph below the title. Secondary Text `#a3a3a3`, 14px, 600 weight, left-aligned, normal line height. No section heading above it.
2. **Sections** — each section is a heading + body paragraph(s):
   - Section heading: Primary Text `#e5e5e5`, 15px, 800 weight, sentence case, left-aligned, normal letter-spacing. 24px top margin (separates sections), 8px bottom margin before its body. Follows the standard heading typography rule (see PRD.md § 2 Design Language → Typography).
   - Body: Secondary Text `#a3a3a3`, 14px, 600 weight, left-aligned. Normal paragraph spacing.
   - Body may include a markdown-style bulleted list when the source copy provides one (e.g., zone breakdowns, status thresholds). Each bullet renders as a row in a `VStack` with a leading `•` glyph and 8pt left indent. Bullet text inherits body styling. Bullets are detected in the source string by line prefix `- ` and rendered by the component — keep parsing logic in the component, not in the constants.
3. **Footer:** none. Sheet ends after the last section's body, with standard bottom safe-area padding.

**Content sources:** all visible strings are read from `AppConstants` — never hardcoded in views. Each surface that opens this modal has its own copy section in CONSTANTS.md:
- **Trends chart cards** → CONSTANTS.md § Chart Info Modal Copy
- **Home widgets** → CONSTANTS.md § Widget Info Modal Copy

**Accessibility:** modal title is announced first by VoiceOver, followed by intro and section headings/bodies in order. Close button reads "Close, button". Section headings traverse as headers (`accessibilityAddTraits(.isHeader)`).

---

## Home Screen

**Purpose:** Central hub showing training status, quick stats, and access to logging. Fully customizable widget layout.

### Widget Card System
Per § Standard Patterns: Sortable Card System, backed by `HomeWidget` records. Default seed order (first launch only): **Training Load, Weekly Streak**. The previously-seeded Workout Info widget has been removed from the product entirely — see § Widget Definitions below and CONSTANTS.md § Widget Types. Home's edit mode is a variant of the standard — see § Widget Edit Mode below.

### Layout
Top: Left: blue ellipsis icon (functional — opens Home ellipsis menu). Right: blue gear icon (→ Settings). ✦ divider. Widget cards render vertically by `sortOrder`. Full-width blue-outlined "+ Log Workout" button below last widget. "Recent Workouts" header, then list of 5 most recent workouts. Each row has three lines: (1) workout name, (2) date with trailing Apple Workout glyph when Apple-Watch-sourced (see § Standard Patterns → Peripheral Apple Workout Glyph) — e.g., `Apr 23, 2026 · [glyph]`, (3) duration if recorded (e.g., `45 min`). Trailing chevron (>). Other HK sources and manual workouts render no peripheral glyph. Duration row is omitted when not set. Recent Workouts list and "+ Log Workout" are unaffected by widget customization.

### Home Ellipsis Menu
One option: **"Add Widgets"** with SF Symbol `plus.rectangle.on.rectangle` to the left → opens Add Widgets Menu overlay.

### Add Widgets Menu
Per § Standard Patterns: Sortable Card System → Add Menu.

### Widget Context Menu (Long Press)
Long-pressing any widget card (uses Standard Long-Press Tease) opens a context menu. Items render top-to-bottom in the order below. "Complete Workout", "See Info", and "Configure Settings" are conditional — they only appear on the widgets and in the states noted.

**"Complete Workout":** SF Symbol `checkmark.circle` to the left of the label (see CONSTANTS.md § Widget Context Menu SF Symbols). Visible **only on the Today's Plan widget**, and **only when one or more uncompleted `ScheduledWorkout` records exist for today** (i.e., the same condition that drives the left column's workout name and silhouette). Tapping opens the same compact confirmation sheet used by the Plan tab's Complete Planned Workout flow (see SCREENS.md § Plan → Complete Planned Workout Flow). On confirm, the widget's left column repopulates with the next planned workout for today — same auto-repopulation logic as before. When no uncompleted scheduled workout exists today (no plans, all completed, or every plan has been skipped), the menu item is **hidden entirely** — never rendered as a disabled/grey item. Accessibility identifier `homeWidget_todaysPlan_completeWorkoutMenuItem`.

**"See Info":** SF Symbol `info.circle` to the left of the label (see CONSTANTS.md § Widget Context Menu SF Symbols). Visible only on Training Load and Power Level widgets — opens the See Info Modal (see § Standard Patterns) populated from CONSTANTS.md § Widget Info Modal Copy for that widget. Not rendered on Weekly Streak or Today's Plan widgets.

**"Configure Settings":** SF Symbol `gear` to the left of the label. Visible only on Training Load and Weekly Streak widgets — opens that widget's existing settings modal (Training Load Settings Modal or Weekly Streak Settings Modal — see § Widget Definitions). Not rendered on Power Level or Today's Plan widgets.

**"Reorder Widgets":** Enters Widget Edit Mode (see below). Always visible regardless of widget count.

**"Delete Widget":** Standard delete confirmation for the long-pressed widget. Removes the `HomeWidget` record, removes the card, re-indexes remaining `sortOrder`. No underlying workout data affected.

**Resulting menus by widget type:**
- **Training Load:** See Info → Configure Settings → Reorder Widgets → Delete Widget (4 items)
- **Power Level:** See Info → Reorder Widgets → Delete Widget (3 items)
- **Weekly Streak:** Configure Settings → Reorder Widgets → Delete Widget (3 items)
- **Today's Plan (with uncompleted plan today):** Complete Workout → Reorder Widgets → Delete Widget (3 items)
- **Today's Plan (no uncompleted plan today):** Reorder Widgets → Delete Widget (2 items)

### Widget Edit Mode
Entered via the context menu's "Reorder Widgets" item. Unlike the standard reorder pattern, Home combines delete + drag in a single edit mode:
- "x" button appears in top-right of each widget (24x24pt circular, #2d2d2d bg, #404040 border, muted "×"). Tapping deletes the `HomeWidget` record, removes the card, re-indexes remaining `sortOrder`.
- Cards are draggable with the same drag physics as Standard Reorder Edit Mode (0.2s ease, sortOrder re-indexed on drop).
- Cards maintain full styling during edit and drag.
- Long-press context menu is disabled during edit mode.
- Exit by tapping outside any widget. "x" buttons fade out (0.15s).

### Widget Definitions

**Training Load** (`trainingLoad`): Blue-bordered card. "Training Load" header. In-depth explanation accessible via long-press → **"See Info"** (see § Widget Context Menu) opens the See Info Modal (see § Standard Patterns) populated from CONSTANTS.md § Widget Info Modal Copy. Settings access via long-press → **"Configure Settings"** opens the **Training Load Settings Modal** (see below). Zone label (e.g., "Moderate"), gradient progress bar (LOW→HIGH), context-aware advisory text below. Advisory shows readiness variant (no workout today) or post-training variant (trained today). See `CONSTANTS.md` for advisory text table and `SERVICES.md` for algorithm. Score updates in real time on workout log/edit/delete.

**Training Load Settings Modal:** Centered modal with dimmed background. "Configure Training Load" heading + "?" tooltip (explains experience affects decay rate and stress capacity). Training Experience card (3-position slider: Beginner/Intermediate/Advanced). Target Workout Duration card (slider 0–300 min) — fallback duration for Training Load algorithm. All changes take effect immediately. Experience level change recalculates Training Load. Dismiss via close button or outside tap.

**Weekly Streak** (`weekStreak`): "Weekly Streak" card. Settings access via long-press → **"Configure Settings"** (see § Widget Context Menu) opens the **Weekly Streak Settings Modal** (see below). Left: animated blue flame SVG scaling by tier. Right: streak count (32px, 900 weight), "WEEK STREAK" label (blue uppercase), motivational message (muted italic). See `CONSTANTS.md` for flame tiers and messages, `SERVICES.md` for algorithm. Flame flickers (1.2s outer, 0.9s inner loops).

**Weekly Streak Settings Modal:** Centered modal with dimmed background. "Configure Streak Widget" heading. Target Workouts per Week card (slider 0–99). Used exclusively by Streak algorithm. All changes take effect immediately. Target workouts change recalculates streak retroactively. Dismiss via close button or outside tap.

**Power Level** (`powerLevel`): Blue-bordered card. "Power Level" header. In-depth explanation accessible via long-press → **"See Info"** (see § Widget Context Menu) opens the See Info Modal (see § Standard Patterns) populated from CONSTANTS.md § Widget Info Modal Copy. Status label (Deloading/Steady/Rising), directional indicator (↓/—/↑ with status-specific color), contextual message (muted italic). See `CONSTANTS.md` for messages, `SERVICES.md` for algorithm.

**Today's Plan** (`todaysPlan`): "Today's Plan" header. Card interior is split into two columns — workout info on the left, calendar square on the right.

**Left column (workout info):** If one or more planned workouts exist today, shows the first uncompleted workout — template name only (primary text). The previous "Complete Workout" inline button and the muted workout-type pill below the name have been removed entirely; completion now lives in the long-press context menu (see § Widget Context Menu — "Complete Workout"), and the workout type is conveyed by the background silhouette described below. If additional planned workouts remain beyond the one displayed, a muted note "X more planned" appears below the workout name (11px, 700 weight, muted text). When a workout is completed via the context menu, the widget automatically repopulates with the next planned workout on the same day. If all today's workouts are completed: "All planned workouts completed." (muted, with green checkmark). If no workouts scheduled today: "No workout planned for today." (muted text).

**Background silhouette (left column):** When a planned workout exists today, render the workout type's SF Symbol from CONSTANTS.md § Workout Type SF Symbols (`dumbbell.fill` for Strength, `figure.highintensity.intervaltraining` for HIIT, `figure.mixed.cardio` for Cardio, `figure.yoga` for Yoga, `figure.pilates` for Pilates, `figure` for Other) as a background watermark behind the workout name. Treatment:
- Color: Muted Text `#737373` at **20% opacity** (`.opacity(0.2)`).
- Size: intentionally **larger than the left column** so the symbol bleeds top and bottom of the card — target ~140pt symbol size against a column ~100pt tall. Use `.scaledToFit()` then explicit `.frame(width: 140, height: 140)` so the bleed is consistent across workout types regardless of the symbol's intrinsic aspect ratio.
- Alignment: centered vertically and horizontally within the left column. Use `ZStack(alignment: .center)` with the silhouette as the back layer and the workout name + "X more planned" caption as the front layer.
- Clipping: the card itself clips overflow (existing FortiFitCard behavior — `.clipShape(RoundedRectangle(cornerRadius: …))`) so the bleed renders as a tasteful watermark, not a layout bug.
- Empty / "all completed" / "no workout planned" states: the silhouette **does not render**. The background only appears when there is a specific scheduled workout to associate it with. Accessibility identifier: `homeWidget_todaysPlan_silhouette` (renders only when present so tests can assert presence/absence by state).

**Right column (calendar square):** Always visible in all states. Rounded rectangle container styled after the iOS Calendar icon in FitNavi colors. Top bar: Primary Accent Blue (#3b82f6) background with the day abbreviation (e.g., "MON") in white text, uppercase, bold. Body area: dark surface (#1a1a1a or elevated #2d2d2d) with the month and date number rendered large and prominent in primary text (#e5e5e5). Blue and green dot indicators appear below the date number matching Plan tab dot logic — blue dot = planned `ScheduledWorkout`, green dot = completed from either a completed `ScheduledWorkout` OR a logged-only `Workout` surfaced on Plan (see SCREENS.md § Plan → Logged-Only Workout Surfacing for the inclusion rule). The left column's workout info, the "Complete Workout" context-menu item, the silhouette, and the "No workout planned for today." / "All planned workouts completed." messaging remain scoped exclusively to `ScheduledWorkout` records — logged-only workouts do **not** appear in the left column.

Included in default widget set — also available via Add Widgets menu.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | All widgets at default/empty: Training Load 0% "Resting", Streak 0 dormant flame, Power Level "No data" message, Today's Plan "No workout planned for today." |
| Populated | Full dashboard with live data |
| Edit Mode | All widgets show "x" buttons; cards draggable; tap outside exits |
| All Widgets Removed | Centered muted message: "Tap the menu to add widgets to your Home screen." Ellipsis, Log Workout, and Recent Workouts remain accessible. |

---

## Workouts (List)

**Purpose:** Training log organized by workout type with expandable cards.

### Layout
Left: blue ellipsis icon. Right: "+" button. ✦ divider. One Workout Type card per type with ≥ 1 logged workout. Cards sorted by WorkoutTypeOrder.sortOrder.

### Workouts Ellipsis Menu
Two options: **"CREATE WORKOUT TEMPLATE"** with SF Symbol `square.and.pencil` to the left → Create Template screen. **"VIEW SAVED TEMPLATES"** with SF Symbol `doc.on.doc` to the left → Saved Templates List.

### Workout Type Card (FortiFitWorkoutTypeCard)
- Leading SF Symbol representing the workout type (see CONSTANTS.md § Workout Type SF Symbols), rendered at the same size and color as the type name text, with standard spacing between icon and name.
- Type name as header (primary text #e5e5e5, 20px, 900 weight, uppercase, 2px spacing).
- Count badge on right (e.g., "8 WORKOUTS" / "1 WORKOUT" — muted, 11px, 700 weight, uppercase).
- Trailing chevron: ▸ collapsed, ▾ expanded (0.2s ease rotation).
- Tap anywhere toggles expand/collapse. Default: collapsed. State persists via `WorkoutTypeOrder.isExpanded`.
- Long-press header → Sort, Filter, Reorder & Delete context menu (see below).

### Expanded Workout Preview Rows
Sorted newest-first (or by active sort). Each row separated by #404040 border:
- **Row 1 — Workout Name** — 16px semibold.
- **Row 2 — Date row** — muted text. Format: `{date} · {Apple Workout glyph if Apple-Watch-sourced}`. The glyph is the trailing token when present, per § Standard Patterns → Peripheral Apple Workout Glyph (renders only when source is Apple Watch).
- **Row 3 — Duration / Distance** (optional) — muted text. Format: `{duration} min` and/or `{distance} {unit}`, `·`-separated when both are present. Row is omitted entirely when neither duration nor distance is set.
- Trailing chevron (>).

Tap row → Workout Detail. Swipe left → red "Delete" → standard delete confirmation → cascade delete, PR recalc, Workout Type card count update. Deleting last workout of a type removes the card and its WorkoutTypeOrder record.

### Pagination
First 30 workouts shown when expanded. "Show next 30 workouts (X total)" button at bottom (muted, centered, same border style) if >30 exist. Appends next batch, button updates dynamically, disappears when all loaded. Collapse/re-expand resets to initial 30. Sort/filter changes reset pagination.

### Search Bar
Visible only when type has >20 workouts. Appears below card header, above first preview row. Elevated surface (#2d2d2d), muted magnifying glass, placeholder "Search workouts". Case-insensitive by workout name across ALL workouts of that type (not just loaded batch). Replaces paginated view — no "Show More" while searching. Clearing (via "×" button) returns to default paginated view. "No workouts found." when no matches.

### Sort, Filter, Reorder & Delete Context Menu
Long-press card header to open.

**Sort by...** sub-menu: Newest first (default, checkmarked), Oldest first, Alphabetical (A–Z). One active at a time. Selecting re-renders immediately, resets pagination.

**Filter by...** sub-menu (multiple filters, AND logic between filter types):
- **Date range:** Last 7 days, Last 30 days, Last 3 months, Last 6 months, This year, All time (default), Custom range (date picker sheet with start/end, Cancel/Apply).
- **Effort range:** Min/max stepper 1–10. Nil Effort workouts excluded when active.
- **Duration range:** Preset buckets — Under 30 min, 30–60 min, 60–90 min, 90+ min. Multiple selectable (OR within, AND with other filters). Hidden for Yoga/Pilates.

**Reorder Workout Types:** Enters Standard Reorder Edit Mode (see § Standard Patterns). Persists to `WorkoutTypeOrder.sortOrder`. Expand/collapse is additionally disabled during reorder.

**Delete Workout Type:** Tapping opens a confirmation modal: "This will permanently delete all X [Workout Type] workouts. This cannot be undone." — where X is the total workout count for that type and [Workout Type] is the type name (e.g., "Strength Training", "Yoga"). Two actions: "Cancel" (default) and "Delete" (destructive, red). On confirm: all workouts of that type are deleted along with their ExerciseSets (cascade), the WorkoutTypeOrder record is removed, and the card disappears. Full cascading recalculations are triggered for every deleted workout — see `SERVICES.md` § Workout Type Deletion. This is always visible in the context menu regardless of sort/filter state.

**Clear All:** Resets sort to Newest first, removes all filters. Only shown when non-default sort or any filter is active.

**Gesture Coexistence:** The long-press context menu is scoped to the card *header area* (type name, count badge, chevron). Swipe-to-delete on individual *preview rows* within expanded cards (see Expanded Workout Preview Rows above) operates independently — both gestures coexist without conflict.

**Visual Indicators:** Sort indicator (↑↓ icon, muted) near count badge when non-default sort active. Filter indicator (funnel + count badge) when filters active. Both can appear simultaneously.

**Persistence:** Sort/filter stored on WorkoutTypeOrder (activeSortOption, activeFiltersJSON). Persists per workout type across sessions.

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
← BACK. Top right: blue ellipsis. In **new-workout mode** the ellipsis is always visible. In **edit mode** the ellipsis is conditional — visible only when `workout.workoutType` is Strength Training or HIIT (the only types templates support); hidden for Cardio / Yoga / Pilates / Other Edit screens. When visible in edit mode, the ellipsis sits to the right of the trash icon — the top-right header in edit mode reads `trash | ellipsis` left-to-right (see § Edit Mode Behavior). Heading: "Log Workout" (new) / "Edit Workout" (edit).

Workout Name input. Single SwiftUI `DatePicker` with `.dateAndTime` components — date defaults to today, constrained to today or earlier; any time selectable; format follows iOS locale (12/24-hour). Date stored on `workout.date`, time on `workout.time`.

Workout Type dropdown (6 types). Post-Workout Effort dropdown + "?" tooltip — each option renders as `[Label] ([Number])` (e.g., `Easy (1)`, `Easy (2)`, `Light (3)`, `Light (4)`, `Moderate (5)`, `Moderate (6)`, `Hard (7)`, `Hard (8)`, `All Out (9)`, `All Out (10)`) per CONSTANTS.md § Effort Label Mapping. The integer is stored on `workout.rpe`; the label is display-only. Duration field (minutes, optional) — shown for all types, below Effort.

**Type-specific fields below duration:**
- **Strength Training / HIIT:** Exercise cards (name input with autocomplete, sets/reps/weight table, + ADD ROW, remove). "+ Add Exercise" button. Each table row = one ExerciseSet.
- **Cardio / Sprints:** Distance field (km or mi per useMiles, optional). No exercises.
- **Yoga / Pilates:** No additional fields. No distance.

### Log Workout Ellipsis Menu (New Mode Only)
**"Use workout template"** with SF Symbol `doc.badge.arrow.up` to the left → Centered selector overlay listing all templates (name + type). Selecting pre-populates form (name, type, duration, exercises). Date/time default to now, Effort empty. All fields editable. Shows "No saved templates yet." when empty.

**"Save as workout template"** with SF Symbol `square.and.arrow.down` to the left → Grayed out when type isn't Strength/HIIT or when name + exercise not yet entered. Opens naming prompt (pre-filled with workout name). Saves template to SwiftData + "Template saved!" toast (auto-dismiss ~2s). Does NOT log the workout.

### Save Button
"Save Workout" (new) / "Save Changes" (edit). Disabled until name filled. Enabled = blue.

### Edit Mode Behavior
All fields pre-populated. Heading: "Edit Workout". Workout type dropdown locked. Blue trash icon (16px) in top-right → standard delete confirmation → deletes workout + ExerciseSets, cascade recalcs (PR, goals, Training Load, streak, Workout Type card), navigates to Workouts list. Adding exercise = new ExerciseSet on save. Modifying row = update ExerciseSet. Removing row = delete ExerciseSet.

**Top-right header layout:** `trash | ellipsis` left-to-right. The ellipsis is conditional — present only on Strength Training or HIIT Edit Workout screens (the only types templates support). Hidden on Cardio / Yoga / Pilates / Other Edit screens. Same conditionality applies whether the workout is HK-linked or not. The ellipsis is the **only** ellipsis surface on the Edit Workout screen — no per-field ellipsis icons appear next to form fields. (HK-linked workouts continue to show inline `info.circle` popovers next to read-only field labels per § Edit Mode — HealthKit-Linked Workouts; those are a separate symbol with a separate purpose and are unaffected by this change.)

### Edit Mode Ellipsis Menu

Visible only on Strength Training or HIIT Edit Workout screens. Single item:

**"Use Template"** with SF Symbol `doc.badge.arrow.up` to the left → opens the same centered template-selector overlay used by the Log Workout new-mode "Use workout template" item (see § Log Workout Ellipsis Menu (New Mode Only) above), with one filter applied: the list shows only templates whose `workoutType` matches the current workout's `workoutType`. Empty-state copy reused: "No saved templates yet." Accessibility identifier `editWorkout_useTemplateMenuItem`.

Behavior on selection — applies to the in-memory edit state only; nothing persists until "Save Changes" is tapped. The Workout Cascade fires on save through `WorkoutService.update()` exactly as it does for any edit. Apply rules:

- **Exercises:** the template's `TemplateExerciseSet` rows are **appended** to the end of the existing `ExerciseSet` list as new `ExerciseSet` records (preserving the existing `sortOrder` of in-place rows; new rows get `sortOrder` values continuing from the current max). No dedupe by name — duplicates are the user's call to clean up.
- **Workout name:** if `workout.name` is empty, fill from the template's name. If `workout.name` is already set, the template's name is **never** applied — name is identity, not configuration.
- **Duration (non-HK-linked workouts):** if `workout.durationMinutes` is nil/empty, fill from the template's duration. If a duration is already set, the template's duration is **never** applied.
- **Duration (HK-linked workouts):** never applied. The field is HK-owned and read-only — see § Edit Mode — HealthKit-Linked Workouts and HEALTHKIT.md § 7. The template-derived duration is silently dropped.
- **Workout type:** never applied (locked in Edit Mode; the selector filter ensures the template matches anyway).
- **Effort, date, time, distance:** never applied. Effort is per-session; date/time/distance aren't carried by templates (templates are Strength/HIIT-only and have no distance, and dates are user-set per session).

No "Save as workout template" item in Edit Mode — keeping the menu minimal. New-mode behavior unchanged.

No confirmation dialog before applying — the operation is non-destructive (append-only for exercises; fill-if-empty for fields; nothing the user already entered is lost).

### Edit Mode — HealthKit-Linked Workouts

When the workout being edited has `healthKitUUID != nil`, three fields become read-only. Each field's label shows an inline `info.circle` popover explaining why it's disabled. See HEALTHKIT.md § 7 for field ownership rationale.

**Read-only fields (when linked):**
- **DatePicker (date/time)** — disabled. Date portion is HK-owned (`workout.date = HK start date`). Time component stays editable as a user-owned field via the date/time split (see below).
- **Duration input** — disabled, pre-populated with HK value.
- **Distance input** (Cardio only) — disabled, pre-populated with HK value.

**Inline `info.circle` popover (per-field):**
Each disabled HK-owned field shows an `info.circle` SF Symbol (14pt, Muted Text `#737373`) trailing the field's label. Tapping the icon opens a SwiftUI `.popover` anchored to the icon, with field-specific copy (see CONSTANTS.md § HealthKit Strings → Log Workout — HealthKit-Linked Field Popovers). Popover contents are a single short paragraph (Primary Text `#e5e5e5`, 13px, 500 weight, ~260pt width) explaining what the field shows, why it's read-only, and how to recover edit access. Popover dismisses on tap-outside. After unlink, the fields become editable and the popovers disappear. Accessibility identifiers: `logWorkout_hkFieldInfoIcon_{date|startTime|duration|distance}`.

**Rationale:** Users need to know WHY a field is disabled. The inline `info.circle` answers that question per-field without forcing a sheet round-trip, reducing friction and increasing trust by making the field's provenance scannable.

**Date/time split:** The DatePicker widget in FortiFit uses `.dateAndTime` mode. Since `date` is HK-owned but `time` is user-owned, this field is conceptually split — but because both share a single input, the entire DatePicker is disabled when linked. A user who needs to adjust the time alone still has to unlink first. Acceptable tradeoff for MVP; revisit if users complain.

**Fields that remain editable when linked:**
- Workout name
- Effort
- Session notes
- ExerciseSets (for Strength / HIIT)

These are user-owned per § 7. Adding ExerciseSets to a linked Cardio workout imported from Apple Watch is allowed but not expected in practice.

**Use Template menu item — interaction with HK-linked workouts:** the Edit Mode ellipsis (see § Edit Mode Ellipsis Menu above) is visible on Strength Training and HIIT HK-linked workouts, just like on non-linked ones. Tapping "Use Template" opens the same selector and applies the template under the same rules with one HK-aware exception: the template's duration is **silently dropped** because `durationMinutes` is HK-owned and read-only. Exercises append normally; name fills if `workout.name` is empty. The HK-linked field popovers and disabled state are unaffected by template application — the disabled fields stay disabled, and the popovers stay anchored to their `info.circle` icons. See SCREENS.md § Edit Mode Ellipsis Menu for the full apply-rule table.

**Save button:** Behaves identically to non-linked save. Triggers `WorkoutService.update()`, which bumps `lastModifiedDate` and fires the Workout Cascade.

**Accessibility:** Inline `info.circle` icons use identifiers `logWorkout_hkFieldInfoIcon_{date|startTime|duration|distance}`. See TESTING.md § Accessibility Identifiers.

---

## Create Template

**Purpose:** Build a reusable workout template from scratch, or edit an existing one.

### Layout
← BACK. Heading: "Create Template" (new) / "Edit Template" (edit). Template Name input (required). Workout Type dropdown — Strength Training and HIIT only. Duration (optional). Exercise cards identical to Log Workout for Strength/HIIT. "+ Add Exercise" button. No Effort, no DatePicker, no distance.

"SAVE TEMPLATE" / "Save Changes" button. Disabled until name + at least one exercise with sets/reps entered. Saves to SwiftData, navigates back.

**Edit mode:** Opened from Saved Templates List. All fields pre-populated. Workout type locked. Top-right icons: muted trash icon (16px), blue ellipsis icon (16px) to right of trash. Trash → standard delete confirmation → cascade-delete template + TemplateExerciseSets, navigate to Saved Templates List. Back button in left hand corner navigates to Saved Templates.

**Edit Mode Ellipsis Menu:** "Share Template" with QR code icon (SF Symbol `qrcode`) to the left. Tapping opens the same Share Template QR Modal as on the Saved Templates List (see Saved Templates List § Share Template QR Modal).

---

## Saved Templates List

**Purpose:** View, edit, delete, and share saved templates.

### Layout
← BACK. "Saved Templates" heading. Right: "+" button (→ Create Template in new-template mode). Scrollable list sorted by dateCreated (newest first). Each row: template name (16px semibold), workout type (muted), date created (muted), trailing chevron.

Tap row → Create Template in edit mode. Template deletion has no effect on workouts, goals, PRs, streaks, or Training Load.

### Long-Press Context Menu
Long-pressing any template card opens a context menu (uses Standard Long-Press Tease). Three options:

**"Share Template":** QR code icon (SF Symbol `qrcode`) to the left of the label. Tapping opens the Share Template QR Modal (see below).

**"Schedule This Template":** Calendar icon (SF Symbol `calendar.badge.plus`) to the left of the label. Tapping opens the Plan scheduling flow (see SCREENS.md § Plan, Scheduling Flow) with this template pre-selected.

**"Delete Template":** Tapping opens the standard delete confirmation ("Delete [Template Name]? This cannot be undone."). On confirm: template + TemplateExerciseSets cascade-deleted from SwiftData.

### Share Template QR Modal
Centered modal with dimmed background. Dismissible via outside tap or close button.

**Layout:** Upper-left: blue share icon (16px, `square.and.arrow.up`, #3b82f6) — tapping presents iOS share sheet with the QR code as a PNG image. Upper-right: muted "×" close button (24x24pt circular, #2d2d2d bg, #404040 border, muted "×"). Center: generated QR code image encoding the full template data as a `fitnavi://` URL (see `SERVICES.md` § TemplateShareService). Below QR code: template name (Primary Text, 15px, 700 weight, centered) and workout type (Muted Text, 13px, centered).

**QR code styling:** White-on-dark QR code. Card Surface (#1a1a1a) background behind the QR module. Border (#404040) 1px stroke, 12px corner radius around the QR container. QR code renders at a size that comfortably scans from a phone screen (~250pt).

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "No saved templates yet. Create one from the Workouts screen or save a logged workout as a template." |
| Populated | Scrollable list of template preview cards |

---

## Template Import Prompt

**Purpose:** Confirm and save a workout template received via QR code deep link.

### Trigger
Activated when the app opens via a `fitnavi://template?data=...` URL (scanned QR code or tapped link). If the app is not running, it launches first, then presents the prompt. If the app is already open, the prompt appears as a modal over the current screen.

### Layout
Centered modal with dimmed background. "Import Template?" heading (Primary Text, 20px, 900 weight). Template preview card below the heading showing:

- Template name (Primary Text, 16px, 700 weight)
- Workout type (Muted Text, 13px)
- Exercise count (Muted Text, 13px, e.g., "5 exercises")

Two action buttons below the preview: "Cancel" (default, muted outline) and "Save Template" (blue, filled). Cancel dismisses with no action. Save creates the template in SwiftData and shows a "Template saved!" toast (~2s auto-dismiss, matching existing toast pattern), then dismisses the modal.

### Duplicate Name Handling
If a template with the same name already exists, the imported template is auto-renamed by appending a numeric suffix: "Push Day" → "Push Day (1)". If "Push Day (1)" also exists, increment to "Push Day (2)", and so on. The preview card in the prompt shows the final resolved name so the user sees what will be saved.

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
Left: blue ellipsis icon (functional — opens Plan ellipsis menu). Right: "+" button (light haptic on tap, matching the "+ Log Workout" button on Home). ✦ divider. FortiFitSegmentedToggle: "WEEK" (default) / "MONTH". Calendar area below toggle. Day detail area below calendar.

### Week Strip Calendar (Default)
Continuous horizontal scroll showing 7 visible day cells at a time. Scrolls day-by-day (not week-by-week) — each swipe advances one day in either direction. The visible window slides gradually rather than snapping in 7-day increments.

**Month indicator:** A month name label appears above the week strip (15px, 700 weight, primary text), updating dynamically as the user scrolls. Shows the year if not the current year. If the visible 7 days span two months, both are shown (e.g., "April – May"). No month-by-month navigation controls — the indicator is passive context only.

**Day cell sizing:** Each cell is evenly distributed across screen width (1/7 of available width minus horizontal padding). Minimum cell height: 72pt. Internal vertical spacing: 6pt between day abbreviation, date number, and dot indicators. Blue selection circle: 36pt diameter, centered on the date number.

Each day cell shows:
- Day abbreviation (e.g., "MON") — muted uppercase label (12px, 700 weight, 2px spacing).
- Date number (e.g., "7") — primary text (18px, 800 weight).
- Dot indicators below date: blue dot = planned `ScheduledWorkout`, green dot = completed — from either a completed `ScheduledWorkout` OR a logged-only `Workout` that is surfaced per § Day Detail Area § Logged-Only Workout Surfacing. No dot = empty. Multiple workouts on one day show multiple dots (max 3 visible, "+N" if more). Dot size: 6pt diameter, 4pt spacing between dots.

**Day cell states:**
- **Selected day:** Date number displayed inside a solid Primary Accent Blue (#3b82f6) filled circle. Number text becomes Background Dark (#0a0a0a) for contrast.
- **Today (when not selected):** Blue border ring (unfilled) around the date number to orient the user.
- **Today AND selected:** Filled blue circle (selected state takes precedence over today's border ring).
- **Other days:** No circle or ring treatment.

Tapping a day cell selects it and shows its scheduled workouts in the day detail area below.

### Month Grid View
Calendar grid with generous cell sizing for comfortable tap targets. Each day cell: minimum 44x44pt (Apple HIG touch target). Date number: 14px, 700 weight, centered. Blue selection circle: 30pt diameter, scaled down from the week strip but still prominent. Dot indicators: 5pt diameter, positioned below the date number. Dot color logic matches the week strip (blue = planned `ScheduledWorkout`, green = completed from either source — see § Week Strip Calendar). Row height: 52pt minimum to accommodate date number + dots with breathing room. Weekday header row ("M T W T F S S") in muted uppercase, 11px, 700 weight. Month navigation via swipe left/right between months.

Selected day uses the same blue filled circle treatment as the week strip. Tapping a day selects it and shows its scheduled workouts in the day detail area below — the user stays in month view.

### Plan Ellipsis Menu
One option: **"Saved Templates"** with SF Symbol `doc.on.doc` to the left → navigates to the existing SavedTemplatesListView (same view accessible from the Workouts ellipsis menu).

### Day Detail Area
Below the calendar. Renders one card per scheduled or logged workout on the selected day (see § Logged-Only Workout Surfacing for inclusion rules). Cards stack vertically.

**Scheduled workout card (FortiFitScheduledWorkoutCard):**
- Workout name (primary text, 16px semibold).
- Workout type pill (muted, uppercase, 11px).
- Estimated duration (muted, if available from template).
- Scheduled time (muted, if set).
- **"Complete Planned Workout"** button (full-width, blue-outlined, consistent with "+ Log Workout" button style on Home).

**Logged-only workout card:**
Rendered for each `Workout` that surfaces per § Logged-Only Workout Surfacing. Visually identical to a completed scheduled workout card (grey fill, green border, green checkmark, muted "COMPLETED" label). Fields:
- Workout name (primary text, 16px semibold). No leading glyph — Apple Workout glyph (when applicable) renders trailing on the metadata row below.
- Workout type pill (muted, uppercase, 11px) followed by ` · LOGGED SESSION` metadata to the right of the pill (11px, 700 weight, uppercase, muted text — matches pill label styling but sits outside the pill boundary). `· LOGGED SESSION` is the source affordance and appears **only** on logged-only cards, not on completed scheduled cards.
- Metadata row: duration (when `workout.durationMinutes` is set) and Apple Workout glyph (when source is Apple Watch — see § Standard Patterns → Peripheral Apple Workout Glyph), separated by ` · `. Glyph is the trailing token. Either or both may be omitted; row is hidden entirely when both are absent.
- Muted "COMPLETED" label with green checkmark in place of any action button.

Days with no scheduled or logged-only workouts show no content in the detail area. The "+" button in the Plan header is the sole entry point for scheduling.

**Overdue planned workouts** (scheduled date in the past, status still "planned"): Card shows a muted "OVERDUE" badge (11px, 700 weight, uppercase, muted text) below the workout type pill.

**Completed scheduled workouts:** Card visually marked with green checkmark and muted styling. Next to the workout type name is `· PLANNED SESSION`. "Complete Planned Workout" button replaced with muted "COMPLETED" label. `· PLANNED SESSION` is the source affordance and appears **only** on scheduled-only cards, not on completed logged cards. If the linked `Workout` was Apple-Watch-sourced, the Apple Workout glyph renders trailing on the same metadata row as duration, per § Standard Patterns → Peripheral Apple Workout Glyph (same rules as logged-only cards).

**Skipped workouts:** Card visually dimmed (muted text, strikethrough on workout name, muted border). Button replaced with muted "SKIPPED" label.

**Tap behavior:**
- **Planned card:** No tap navigation (the "Complete Planned Workout" button is the primary action).
- **Skipped card:** No tap navigation.
- **Completed scheduled card:** Tap anywhere on the card → navigates to Workout Detail for the linked `Workout` (resolved via `completedWorkoutId`).
- **Logged-only card:** Tap anywhere on the card → navigates to Workout Detail for the underlying `Workout`.

### Logged-Only Workout Surfacing

The Day Detail Area and calendar dot indicators include logged-only `Workout` records alongside `ScheduledWorkout` records. A `Workout` surfaces on Plan (as a green dot and a logged-only card under its `workout.date`) if and only if **both** conditions are met:
1. No `ScheduledWorkout` has `completedWorkoutId == workout.id` (workouts linked to a scheduled slot are already represented by their `ScheduledWorkout` — surfacing them separately would duplicate them).
2. `workout.hiddenFromPlan == false`.

Workouts failing either condition are invisible to the Plan screen. See SERVICES.md § PlanService → Retrieval for the fetch implementation.

Empty state applies only when **no** `ScheduledWorkout` records exist AND no non-hidden `Workout` records exist — the Plan screen treats any surfaced card or dot (scheduled or logged) as non-empty.

### Scheduling Flow

**Entry points:** (1) Tap "+" button in Plan tab header. (2) Long-press a template in Saved Templates List → "Schedule This Template."

**Flow:**
1. **Template Selection:** Sheet slides up showing saved templates (reuses SavedTemplatesListView as a selection interface). Each row: template name, workout type, exercise count. Tap to select.
2. **Date Selection:** If entered from Plan on a specific day, that date is pre-filled. Otherwise, date picker appears. Date must be today or later — past dates are not schedulable.
3. **Time (Optional):** Optional time-of-day picker. Defaults to no specific time.
4. **Recurrence (Optional):** Recurrence picker: None (default), Weekly, Biweekly. Selecting a recurrence auto-generates `ScheduledWorkout` records for the next 12 weeks. All share the same `recurrenceGroupId`.
5. **Confirmation:** Summary card showing template name, date, time, recurrence. Summary card sits under a "Summary" header. "Schedule Workout" button saves and dismisses.

**Validation:** Template must be selected. Date must be today or in the future. Multiple workouts can be scheduled for the same day.

### Complete Planned Workout Flow

1. User taps **"Complete Workout"** on a scheduled workout card.
2. **Date Resolution** (see below) — if date prompt is needed, resolve first.
3. **Compact Confirmation Sheet** slides up (elevated surface #1a1a1a, border #404040, dimmed background overlay):
   - Workout name displayed at top (non-editable, for context, primary text 16px 700 weight).
   - **Effort** — horizontal row of numbered pills (1–10), consistent with Log Workout Effort input. Optional. No default value.
   - **Duration** — FortiFitInput with "min" suffix label. Optional. Pre-filled from template's `durationMinutes` if available.
   - **"Save Workout"** button (full-width, blue filled, prominent).
   - **"Modify Exercises"** button below "Save Workout" (full-width, blue-outlined secondary style). Routes to full Log Workout view pre-populated from template snapshot.
4. **On "Save Workout":** Creates `Workout` from template snapshot (name, type, exercises/sets/reps/weights) plus Effort and duration from sheet. Marks `ScheduledWorkout` as completed, stores new `Workout.id` in `completedWorkoutId`. Dismisses sheet. Toast: "Workout completed." (~2s auto-dismiss).
5. **On "Modify Exercises":** Dismisses compact sheet. Opens Log Workout in new-workout mode, pre-populated from template snapshot. `ScheduledWorkout` ID carried through. On save in Log Workout: same completion logic (mark slot completed, link workout ID). On back-out without saving: slot remains "planned".

Dismiss compact sheet via close button or outside tap (does not complete the workout).

### Date Resolution Logic

When a user taps "Complete Planned Workout," the system determines the workout date:

**Scheduled date is today:** No prompt. Workout stamped with today's date.

**Scheduled date is in the past:** Prompt: "This workout was planned for [scheduled date]. Log for [scheduled date] or today?" Two options: [Scheduled date] or Today. Either proceeds to compact confirmation sheet.

**Scheduled date is in the future:** Prompt: "This workout is planned for [future date]. Log for today instead?" Two options: "Log for Today" (proceeds to compact confirmation sheet, workout saved with today's date) or "Cancel" (returns to Plan, slot remains planned). No option to keep the future date — post-dating is prohibited to prevent phantom entries in stress, streak, and PR calculations.

### Long-Press Context Menu

Long-pressing a card in the Day Detail Area opens a context menu (uses Standard Long-Press Tease). Menu contents vary by card type:

**Planned scheduled card:**
- **"Skip Workout":** Sets status to "skipped". Card visually dims. No `Workout` record created. Reversible — long-press the skipped card → "Restore Workout" sets status back to "planned".
- **"Remove from Plan":** Standard delete confirmation ("Remove [Workout Name] from Plan? This cannot be undone."). On confirm: `ScheduledWorkout` record deleted. For recurring instances, the standard "This workout only / This and future workouts" prompt applies first (see § Editing Recurring Workouts).

**Skipped scheduled card:**
- **"Restore Workout":** Sets status back to "planned".
- **"Remove from Plan":** Same confirmation and behavior as on a planned card.

**Completed scheduled card:**
- **"Remove from Plan":** Dual-action (see below). The underlying `Workout` record is preserved — only its visibility on Plan is removed.

**Logged-only card:**
- **"Remove from Plan":** Non-destructive confirmation ("Remove [Workout Name] from Plan? The workout will remain in your log." — Cancel / Remove, no destructive-red styling). On confirm: `workout.hiddenFromPlan` set to `true`. Card and dot disappear from Plan. Workout remains fully intact on the Workouts screen and in all algorithms. Toast: "Removed from Plan. [Undo]" (~4s auto-dismiss). Tapping Undo flips the flag back to `false`.

**"Remove from Plan" dual-action (completed scheduled cards only):**
Because a completed scheduled card is backed by both a `ScheduledWorkout` and a linked `Workout` — and because the dedup rule in § Logged-Only Workout Surfacing would immediately re-surface the `Workout` as a logged-only card if only the `ScheduledWorkout` were deleted — "Remove from Plan" on a completed scheduled card performs both steps atomically:
1. Delete the `ScheduledWorkout` record.
2. Set `workout.hiddenFromPlan = true` on the linked `Workout`.

The user sees a single disappearance. Schedule/recurrence lineage is permanently lost; the workout can only reappear on Plan as a logged-only card via the "Show on Plan" action in Workout Detail. See SERVICES.md § PlanService → Remove from Plan for full service logic. Confirmation and toast match the logged-only flow ("Remove [Workout Name] from Plan? The workout will remain in your log.", non-destructive styling, "Removed from Plan. [Undo]" toast). Undo reverses both steps — the `ScheduledWorkout` record is **not** restored (it was deleted), and a fresh `hiddenFromPlan = false` flip makes the card reappear as a **logged-only** card. This is acceptable behavior — the user understands "Remove from Plan" on a completed workout is a lineage-destroying action.

For recurring completed instances, the standard "This workout only / This and future workouts" prompt applies:
- **This workout only:** Dual-action on just this instance.
- **This and future:** Dual-action on this instance, plus delete all future **planned** `ScheduledWorkout`s in the same `recurrenceGroupId`. Past completed and skipped instances are untouched (consistent with the existing recurrence delete rule).

### Editing Recurring Workouts

When a user edits or deletes a recurring workout, prompt: **"This workout only"** or **"This and future workouts"**. "This workout only" modifies/deletes the single instance. "This and future workouts" modifies/deletes this instance and all future instances sharing the same `recurrenceGroupId` with `scheduledDate` ≥ this instance's date. Past completed/skipped workouts are never retroactively altered.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "Schedule your first workout to start planning." Shown only when no `ScheduledWorkout` records exist AND no non-hidden `Workout` records exist. "+" button accessible. |
| Populated | Calendar with dot indicators, scheduled/logged workout cards in day detail |
| Week view | Default. Continuous day-by-day scrollable strip with month indicator and day detail below |
| Month view | Condensed month grid. Tap day → selects day and shows detail below (stays in month view) |
| Selected day | Blue filled circle on date number in both week and month view |
| Completed day | Green checkmark on card, muted "COMPLETED" label. Applies to both completed scheduled cards and logged-only cards. |
| Logged-only card | Visually identical to completed scheduled card, with ` · LOGGED` metadata to the right of the workout type pill as source affordance |
| Skipped day | Dimmed card, strikethrough name, muted "SKIPPED" label |
| Overdue | Planned card with muted "OVERDUE" badge |

---

## Workout Detail

**Purpose:** Full breakdown of a single workout session.

### Layout
← BACK. "Workout" label, name (blue), date, time, workout type (muted, e.g., "Mar 17, 2026 · 2:35 PM · Strength Training"). When time is nil (pre-feature workout), omit time component.

**Source indicator (HK-linked workouts only):** Rendered on its own row directly below the workout type row when `workout.healthKitUUID != nil`. Format: `{sourceName} [glyph]` — source name only, no activity type prefix. The Apple Workout glyph trails as the last token **only when the source is Apple Watch**. Styled as secondary/muted text using the app's Label treatment (14px, 700 weight, 2px letter-spacing, Muted Text color).

Source name is resolved dynamically at render time via `HealthKitClient.sourceName(for:)` (see SERVICES.md § HealthKitClient → sourceName resolution). Resolution rule:
- Apple Watch source bundle ID → `Apple Workout`
- Other known sources → their `HKSource.name` (e.g., `Strava`, `Peloton`)
- Unknown / unresolvable → `another app` (graceful fallback — never displays a raw bundle ID)

**Trailing glyph:** the Apple Workout glyph (component `FortiFitHealthGlyph.swift` — running figure on green circular background) renders trailing the source name **only when source is Apple Watch**. Other sources render with no trailing glyph; users distinguish them by the source name alone. Future updates may add per-source glyphs (Strava, Peloton, etc.) — when that happens, the same trailing-glyph slot is used.

Example renderings:
- `Apple Workout [glyph]` (Apple Watch source)
- `Strava` (Strava source — no glyph)
- `Peloton` (Peloton source — no glyph)

The row is tappable — tapping anywhere on the row opens the **Source Indicator Info Sheet** (see below). Row has accessibility identifier `workoutDetail_healthSourceIndicator` (see TESTING.md).

Top-right icons: blue share icon (16px, `square.and.arrow.up`, #3b82f6), muted edit icon (16px), muted trash icon (16px). Blue ellipsis icon (16px) to right of trash, shown when at least one ellipsis menu item applies (see Ellipsis Menu below). Share → renders workout as styled image card and presents iOS share sheet (see Share Image Card below). Edit → Log Workout in edit mode. Trash → standard delete confirmation → cascade delete, back to Workouts list.

**Ellipsis Menu:** Items appear conditionally based on workout type and state. The ellipsis icon itself is shown only when at least one item is visible.

- **"Save as workout template"** with SF Symbol `square.and.arrow.down` to the left → naming prompt (pre-filled with workout name) → saves template (name, type, duration, exercises — NOT Effort, date, time, notes) → "Template saved!" toast (~2s). Visible only for Strength Training / HIIT workouts.
- **"Show on Plan"** with SF Symbol `calendar.badge.plus` to the left → flips `workout.hiddenFromPlan` from `true` to `false`. No confirmation alert (non-destructive, trivially reversible). Toast: "Showing on Plan." (~2s auto-dismiss). Visible only when `workout.hiddenFromPlan == true`. Applies to all workout types — if this is the only applicable item (e.g., a hidden Cardio workout), the ellipsis icon appears with just this single option. When both items apply (a hidden Strength/HIIT workout), "Show on Plan" is rendered immediately below "Save as workout template".
- **"Unlink from Apple Health"** with SF Symbol `link.badge.minus` to the left → confirmation alert: "Unlink this workout from Apple Health? Imported values (duration, distance, heart rate, etc.) will be retained as editable fields. Cancel / Unlink." On confirm: applies § HealthKit Unlink (clears `healthKitUUID`, `healthKitSourceBundleID`, `healthKitActivityType`; retains numeric values; bumps `lastModifiedDate`; no cascade). Toast: "Unlinked from Apple Health." (~2s). Visible only when `workout.healthKitUUID != nil`. Renders below all other items in the menu. See HEALTHKIT.md § 14 and SERVICES.md § HealthKit Unlink.

✦ divider. "Summary" header (sentence case). Below the header, the Summary block renders as a **2-column grid of bordered stat cards** — one card per non-nil metric. Each card is independently tappable and opens the **Metric Detail Sheet** (see § Metric Detail Sheet below).

**Stat card structure (`FortiFitStatCard.swift`):**

- Container: Card Surface `#1a1a1a` background, `#404040` 1px border, 12px corner radius, internal padding (16px horizontal, 14px vertical).
- Top row: SF symbol (left) + sentence-case micro-label (immediately to the right of the symbol) + right-pointing chevron (`chevron.right`) in the top-right corner. The chevron signals tap affordance and matches the chevron treatment used on workout preview rows. **Icon** is rendered in the metric's color per CONSTANTS.md § Stat Card Colors (e.g., Duration purple, HR red, calories orange, distance teal, Effort multi-color palette). **Label** is Primary Text `#e5e5e5`, 13px, 700 weight, normal letter-spacing. **Chevron** stays Muted Text `#737373` at the same weight.
- Below the top row: the metric **value** in heading typography — 24px, 800 weight, sentence case (for label-style values like Effort) or numeric (for everything else), color matches the icon color per CONSTANTS.md § Stat Card Colors. For numeric values, the unit renders inline immediately after the number in smaller muted text (Secondary Text `#a3a3a3`, 13px, 600 weight) — e.g., `142 bpm` where `142` is hero-sized and `bpm` is muted-and-smaller. The unit color stays muted regardless of the value color. Value left-aligned with the label. **Effort value color is dynamic**: maps from `workout.rpe` integer per CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red).
- Tap state: subtle 0.15s opacity dim on press; tap opens the Metric Detail Sheet for that field.
- Accessibility: each card has its own identifier — see TESTING.md.

**Field order (top to bottom, left to right in the 2-column grid):**

1. Effort
2. Duration
3. Distance (Cardio only)
4. Avg HR · Max HR (each its own card; render side-by-side on one row when both are non-nil)
5. Active kcal · Total kcal (each its own card; render side-by-side when both non-nil)
6. Elevation Ascended
7. Exercise Minutes

**Visibility rule:** each card renders only when its underlying value is non-nil. Pairs (Avg HR + Max HR; Active + Total) gracefully collapse to a single card if only one of the pair is set. The grid wraps left-to-right, top-to-bottom — no empty placeholders, no fixed row count. Manual workouts naturally collapse to 2–3 cards (Effort + Duration, plus Distance for Cardio); HK-linked workouts can show up to 9 cards.

**Per-field display values:**

| Field | Label | Value Display |
|---|---|---|
| Effort | Effort | Descriptive label per CONSTANTS.md § Effort Label Mapping (e.g., `Hard`). The underlying integer is preserved on `workout.rpe` but not displayed on the card. |
| Duration | Duration | `45 min` (number + inline muted unit) |
| Distance | Distance | `5.2 km` or `3.2 mi` per `useMiles` |
| Avg HR | Avg HR | `142 bpm` |
| Max HR | Max HR | `168 bpm` |
| Active kcal | Active kcal | `487 kcal` |
| Total kcal | Total kcal | `612 kcal` |
| Elevation Ascended | Elevation | `240 ft` or `73 m` per `useMiles` |
| Exercise Minutes | Exercise min | `32 min` |

**Indoor/Outdoor:** removed entirely from Summary.

**Icons:** see CONSTANTS.md § Workout Detail Summary Icons (Effort symbol updated from `heart.gauge.open` to `chart.bar.fill`) and § Workout Detail Health Data Icons (HK-imported field icons unchanged).

**After Summary (for Strength/HIIT only, conditional):** "Exercises" header (sentence case) + exercise list (name, sets, weight). The header and list are **hidden entirely** when `workout.exerciseSets.isEmpty`. Applies regardless of how the workout was created (manual or HK-imported with empty sets). Header reappears as soon as the user adds an exercise via Edit Workout.

✦ divider. "Session Notes" header + edit icon. Note card or textarea when editing + SAVE button.

### Source Indicator Info Sheet

Opened via:
1. Tapping the Source Indicator row on Workout Detail.

Rendered as an iOS modal sheet (sheet presentation, swipe-down to dismiss).

**Detent:** uses `.large` (or a custom `.height(...)` detent sized to fit content). Do not use `.medium` — the new layout doesn't fit cleanly there.

**Vertical structure (top to bottom):**

1. **Header icon.** Centered HealthKit-pink heart SF Symbol (`heart.fill`, 32pt). Header icon stays the heart symbol — it's the system-level Apple Health brand mark, not the per-workout source glyph.
2. **Title.** "Imported from Apple Health" (primary text, 18px semibold, centered).
3. **Lead sentence.** "This workout was imported from Apple Health." (secondary text, 14px, centered, `.fixedSize(horizontal: false, vertical: true)`). One sentence — it sets context. The detail moves into the callout block.
4. **Two-row callout.** A vertical stack of two FortiFitCard rows (Card Surface `#1a1a1a`, `#404040` 1px border, 12px corner radius, 12px internal padding, 8px vertical spacing between rows). Each row is `HStack(alignment: .top, spacing: 12)` of an SF Symbol leading + a multi-line body label trailing. Symbol stays on baseline of the first body line.
   - **Row 1 — read-only fields.** Symbol `pencil.slash` (16pt, Muted Text). Body: "Date, Start Time, Effort, and Duration are read-only here. Edit in Apple Health, or unlink to edit in FitNavi." (Primary Text 14px 600 weight on the first line "Date, Start Time, Effort, and Duration are read-only here.", Muted Text 13px 500 weight on the second sentence). Accessibility identifier `sourceInfoSheet_readOnlyCallout`.
   - **Row 2 — one-way unlink warning.** Symbol `arrow.uturn.backward.slash` (16pt, Alert Red `#ef4444`). Body: "Unlinking is permanent. Future Apple Health edits won't sync to this workout." (Primary Text 14px 600 weight on first sentence, Muted Text 13px 500 weight on second). Accessibility identifier `sourceInfoSheet_permanentUnlinkCallout`.
5. **Primary safe action.** Full-width "Done" button — primary blue-outlined style (Primary Accent `#3b82f6` border + label, 12px corner radius). Dismisses the sheet. Accessibility identifier `sourceInfoSheet_doneButton`. This is the visually largest action so the safe path matches the iOS convention.
6. **Demoted destructive link.** "Unlink from Apple Health" rendered as a centered text-style link below the Done button — Alert Red `#ef4444`, 14px, 600 weight, no fill, no border, 12px top spacing. Tap → opens a SwiftUI `.confirmationDialog` (see step 7). Accessibility identifier stays `workoutDetail_healthUnlinkButton` (preserves Phase 8 identifier per HEALTHKIT.md § 19).
7. **Confirmation dialog (.confirmationDialog).** Title "Unlink this workout?" Message "You won't be able to link it back to Apple Health, and changes you make to it in Apple Health won't appear here anymore." Actions: destructive "Unlink" + cancel "Cancel". On Unlink → invokes `HealthKitSyncService.unlink(workout:)` per HEALTHKIT.md § 14 (which now writes a `WorkoutMatchRejection` — see § 14) → sheet dismisses → toast "Unlinked from Apple Health." (~2s). Accessibility identifiers `sourceInfoSheet_unlinkConfirmButton` and `sourceInfoSheet_unlinkCancelButton`.
8. **Footer metadata block.** Below the destructive link, separated by a 16px top spacer, render reference data as muted footer rows (left-label / right-value, both 12px, 600 weight, Muted Text `#737373`):
   - "Activity Type · {workout.healthKitActivityType}"
   - "Source · {sourceName}" (resolved via `HealthKitClient.sourceName(for:)` per § Source indicator — Apple Watch → `Apple Workout`, recognized sources → friendly name, unresolvable → `another app`. Never renders a raw bundle ID.)
   - "Imported · {formatted workout.dateCreated}" (omit if not captured).
   - "Last synced · {relative time, e.g., "5 min ago", "2 hours ago", "yesterday"}" — sourced from `HealthKitSyncService.lastSyncDate(for:)`. Helps the user trust that values are current. Omit if no sync has run since import. Accessibility identifier `sourceInfoSheet_lastSyncedRow`.

**Why footer placement:** the metadata is reference data, not decision-relevant. Putting it after the destructive action keeps the warning copy adjacent to the destructive control and prevents the user from skimming past it.

**Dismiss:** Swipe down, tap outside the sheet, or tap "Done."

### Metric Detail Sheet

Modal sheet opened by tapping any stat card in the Workout Detail Summary grid. Provides per-metric context — value display, comparative average against the user's typical session of the same Workout Type, 30-day sparkline, and an optional Personal Best chip.

**Component:** `FortiFitMetricDetailSheet.swift` (see PRD.md § Project Structure → Design/Components/). Takes the tapped `Workout` and a `WorkoutMetric` enum case (see SERVICES.md § WorkoutMetricService). Pulls all aggregate data from `WorkoutMetricService` — never queries SwiftData directly.

**Presentation:** iOS modal sheet (sheet presentation, `.medium` detent). Swipe-down to dismiss. Background uses Card Surface `#1a1a1a`. Drag indicator visible at top.

**Header:** No centered title — the hero block (below) serves as the de facto title. Removing the redundant `[Metric] details` heading keeps the sheet content-focused.

**Close button:** Plain `xmark` SF Symbol in the top-right corner — Muted Text `#737373`, 16px, no circular background or border. Tap dismisses the sheet. Accessibility identifier `metricDetailSheet_closeButton` (shared across all metrics).

**Body:** Scrollable. Standard 20px horizontal padding, 24px top padding below the close button. Four blocks rendered top-to-bottom (every block conditionally adapts when data is insufficient — see Empty States below):

**1. Hero block** (mirrors the tapped stat card, scaled up):

- Top row: same SF symbol + sentence-case micro-label as the tapped card. **Icon** in the metric's color per CONSTANTS.md § Stat Card Colors (multi-color palette for Effort). **Label** is Primary Text `#e5e5e5`, 13px, 700 weight. No chevron in this context.
- Below: the metric value at hero size — 32px, 900 weight, sentence case for label-style values, numeric for everything else. **Color matches the icon color** per CONSTANTS.md § Stat Card Colors. **Effort value color is dynamic** per CONSTANTS.md § Effort Color Mapping (1–4 green, 5–6 yellow, 7–10 red).
- For **Effort specifically**: hero shows the descriptive label (`Hard`) at hero size in the band-mapped color; a smaller line below shows the underlying integer in parentheses (`(7)`) — Secondary Text `#a3a3a3`, 15px, 600 weight, **stays muted regardless of the value color**.
- For numeric fields: unit renders inline immediately after the number in smaller muted text (e.g., `142 bpm`); the unit stays muted regardless of the value color.

**2. Comparative context block:**

- Two lines in body typography (Secondary Text `#a3a3a3`, 14px, 600 weight, left-aligned).
- Line 1: `Your typical [Workout Type] session — [comparison value]` (e.g., `Your typical Strength Training session — Moderate (5.4)` for Effort, `Your typical Strength Training session — 52 min` for Duration).
- Line 2: a delta line describing how this workout compares — `Harder than typical`, `+12 min vs typical`, `+4 bpm vs typical`, `5 fewer kcal than typical`, etc. Color is Muted Text by default; uses Primary Accent Blue for positive-direction deltas (only on PR-eligible metrics — see § 4 below) when the workout is the highest-ever.
- **Comparison window:** all-time across all logged workouts of the same Workout Type with the relevant metric set. Computed by `WorkoutMetricService.comparativeAverage(for:workoutType:)`.

**3. 30-day sparkline block:**

- Swift Charts `LineMark` rendering of this metric across the same Workout Type's last 30 days of sessions. X-axis: dates (no tick labels — date range implied by caption). Y-axis: value range (auto-scaled, no tick labels).
- **Line color** is metric-specific per CONSTANTS.md § Stat Card Colors (Duration purple, Distance teal, HR red, calories orange).
- **Effort sparkline** is the exception: it uses **per-segment color**, where each line segment's color is determined by its endpoint's effort value per CONSTANTS.md § Effort Color Mapping. A 30-day Effort sparkline can therefore show multiple colors as effort varied across sessions. Implementation: render multiple `LineMark` series segmented by effort band, or use Swift Charts' `foregroundStyle(by:)` modifier with a categorical effort-band scale.
- This workout's data point is highlighted: filled circle, larger radius (~6pt), Primary Accent Blue color (the highlighting color is uniform across all metrics — distinct from the line color so the user can always locate the current session). Other points: Secondary Text color, smaller radius (~3pt).
- Caption below the chart: muted `Last 30 days · [Workout Type]`.
- Chart container: Card Surface `#1a1a1a`, `#404040` 1px border, 12px corner radius, 16px internal padding, ~120pt height.

**4. Personal Best chip (conditional):**

- Renders only when `WorkoutMetricService.isPersonalBest(for:workout:)` returns true for the metric.
- Inline pill: Primary Accent Blue (`#3b82f6`) at 15% opacity background, Primary Accent Blue text. 12px corner radius. Padding 8px horizontal, 4px vertical.
- Copy: `Personal best for [Workout Type]`. Primary Accent Blue, 11px, 700 weight, sentence case.
- Positioned below the sparkline block with 16px top margin.

**PR-eligible metrics:** Distance, Active Calories, Total Calories, Elevation Ascended. The chip never renders for Effort, Avg HR, Max HR, Duration, or Exercise Minutes — `isPersonalBest` returns false for those by service contract.

**Empty / insufficient data states (per block):**

- **Comparative context:** when fewer than 3 logged workouts of the same Workout Type have the metric set (excluding this workout), replace both lines with muted `Not enough data yet — log a few more sessions.`
- **30-day sparkline:** when fewer than 3 data points are available across the last 30 days, replace the chart with the same muted message and hide the chart container.
- **Personal Best chip:** simply not rendered when `isPersonalBest` is false. No empty placeholder.

**Accessibility:** sheet title is announced first by VoiceOver, followed by hero block, comparative context lines, sparkline (with summary trait), and the PR chip if present. Close button reads "Close, button". The chevron on the originating stat card has `accessibilityHint("Opens metric details")`.

### Share Image Card

Tapping the share icon renders the workout as a styled PNG image card and presents the iOS share sheet (`UIActivityViewController`). The image is a self-contained card using FitNavi's design tokens, designed to be legible as a standalone image outside the app.

**Card content:** workout name, date/time, workout type, **2-column stat-card grid** (mirrors the Workout Detail Summary grid), exercise list (Strength/HIIT only).

**Stat-card grid:** Renders the same fields, in the same order, with the same icons, labels, value formats, **and color treatment** as the Workout Detail Summary grid (see § Workout Detail and CONSTANTS.md § Stat Card Colors). Differences for the share image:

- Static — no chevron, no tap behavior.
- Smaller card sizing scaled appropriately for the 390pt-wide image.
- Effort renders as the descriptive label (e.g., `Hard`) per CONSTANTS.md § Effort Label Mapping — same as Workout Detail. The Effort icon uses the multi-color palette (green/yellow/red bars) and the Effort value color maps from `workout.rpe` per CONSTANTS.md § Effort Color Mapping — identical behavior to the on-screen card.
- Cards render only when their underlying value is non-nil. Manual workouts collapse to 2–3 cards.

When `workout.time` is nil, the time component is omitted from the date line.

**Exercise cap:** Maximum 10 exercises displayed. If the workout has more than 10, the first 10 are shown followed by a muted "+X more exercises" line (e.g., "+3 more exercises").

**Excluded from image:** Session notes, navigation chrome (back button, icon tray).

**Card styling:** See `CONSTANTS.md` § Share Image Card Styling for the full token table (background, border, padding, header/footer, workout name, date, stat cards, exercise rows, dividers, image dimensions).

**Rendering:** SwiftUI `ImageRenderer` at @3x scale. If rendering fails, show a brief toast: "Couldn't generate image. Try again." (auto-dismiss ~2s, matching existing toast pattern).

**Edge cases:**

| Scenario | Behavior |
|----------|----------|
| All optional fields nil (no Effort, no duration, no distance) | No stat cards rendered; image shows name, date, type, and exercises (if any) |
| Workout has >10 exercises | First 10 shown + "+X more exercises" in muted text |
| Exercise with nil weight (bodyweight) | Displays as `{sets} × {reps} (BW)` |
| Very long workout name | Truncated with ellipsis at 2 lines max |
| Very long exercise name | Truncated with ellipsis at 1 line |
| Share sheet cancelled by user | No action; dismiss cleanly |
| Image render fails | Brief error toast (~2s) |

---

## Trends

**Purpose:** Visualize training trends with customizable chart layout.

### Chart Card System
Per § Standard Patterns: Sortable Card System, backed by `TrendsChart` records. Default seed order (first launch only): **Strength Tracker, Training Frequency, Personal Records, Training Load Trend**. All charts auto-update when workouts are logged, edited, or deleted. Charts appear independently as data thresholds are met — an added chart that doesn't yet meet its data threshold renders its empty-state message.

### Layout
Top: Left: blue ellipsis icon (functional — opens Trends ellipsis menu). ✦ divider. Chart cards render vertically per § Standard Patterns: Sortable Card System.

### Trends Ellipsis Menu
One option: **"Add Charts"** with SF Symbol `chart.xyaxis.line` to the left → opens Add Charts Menu overlay.

### Add Charts Menu
Per § Standard Patterns: Sortable Card System → Add Menu. Component: `FortiFitAddChartMenu` (mirrors `FortiFitAddWidgetMenu`).

### Chart Card Context Menu (Long Press)
Activated by long-pressing any chart card (uses Standard Long-Press Tease). Items render top-to-bottom in this order — all three apply to every chart type:

**"See Info":** SF Symbol `info.circle` to the left of the label (see CONSTANTS.md § Trends Chart Context Menu SF Symbols). Opens the See Info Modal (see § Standard Patterns) for that chart, populated from CONSTANTS.md § Chart Info Modal Copy.

**"Reorder Charts":** Enters Standard Reorder Edit Mode. Always visible regardless of chart count.

**"Delete Chart":** Per § Standard Patterns: Sortable Card System → Delete. Confirmation: "Delete [Chart Display Name]? This cannot be undone."

### Reorder Edit Mode
Per § Standard Patterns: Standard Reorder Edit Mode. Persists to `TrendsChart.sortOrder`.

### Chart Info Modal
Per § Standard Patterns: See Info Modal. Content source: CONSTANTS.md § Chart Info Modal Copy. Title format: "About [Chart Display Name]" (e.g., "About Strength Tracker").

### Chart Definitions

**Strength Tracker** (`strengthTracker`): Exercise dropdown, 30D/60D/90D toggles, line chart of weight over time, latest value.

**Training Frequency** (`trainingFrequency`): Bar chart of weekly sessions (8 weeks), blue dashed target reference line, legend.

**Personal Records** (`personalRecords`): Exercise dropdown listing only exercises with at least one PR event (see PR Definition below). On selection, displays most recent PR value + date and previous record value + date. Visualized as a bar chart comparing previous record vs. current record (see PR Layout below).

**Training Load Trend** (`trainingLoadTrend`): Line chart, one dot per day colored by zone (Low/Moderate/High/Peak), blue dashed 7-day rolling average, zone-colored background bands, zone legend.

**Workout Volume** (`workoutVolume`): Line chart of total session volume (sets × reps × weight) over time for Strength Training and HIIT workouts. 30D/60D/90D toggles. Each data point = one workout. Blue line with data point dots.

**Effort Trend** (`rpeTrend`): Bar chart of weekly average Effort (8-week rolling window, same as Training Frequency). Horizontal dashed reference line at Effort 7. Includes workouts with and without recorded Effort.

**Workout Type Breakdown** (`workoutTypeBreakdown`): Donut chart (`SectorMark`) showing proportion of each workout type. Time range toggles: 30D / 60D / 90D / All Time. Each segment colored by workout type (see CONSTANTS.md § Workout Type Chart Colors). Segments labeled with type name + count. Legend below chart.

**Session Duration** (`sessionDuration`): Bar chart of weekly average workout duration (8-week rolling window). Horizontal dashed reference line at `targetMinutesPerWorkout` from UserSettings (primarytext color token). Only includes workouts with recorded duration. Legend along horizontal axis with dashed line indicator and text "Target". 

### PR Definition
A **Personal Record (PR) event** occurs when a new maximum `weightKg` for a given `exerciseName` exceeds the previous maximum across all earlier workouts. The first workout logging an exercise establishes the baseline — it is **not** a PR. A PR requires a prior value to surpass.

For a given `exerciseName`, collect all distinct max `weightKg` values across workouts ordered chronologically by `workout.date`. A PR is recorded each time a new chronological maximum exceeds all previous maximums. Exercises where `weightKg` is nil (bodyweight) are excluded from PR tracking.

### PR Layout

**Exercise Dropdown:** Top of the chart card. Lists only exercises with ≥ 1 PR event. Sorted alphabetically. Default selection: first exercise alphabetically.

**PR Summary Row:** Below dropdown. Two columns side by side:

| Column | Content |
|--------|---------|
| Left: "PREVIOUS RECORD" | Previous record value (formatted per `useLbs`) + date (muted, short format) |
| Right: "CURRENT RECORD" | Most recent PR value (formatted per `useLbs`, Primary Accent Blue) + date (muted, short format) |

**Bar Chart:** Swift Charts `BarMark`. Two bars side by side:

| Bar | Color | Label |
|-----|-------|-------|
| Previous Record | Elevated Surface (#2d2d2d) with Border stroke (#404040) | 
| Current Record | Primary Accent Blue (#3b82f6) | Value annotation above bar |

Y-axis: weight (kg or lbs per `useLbs`). X-axis: two category labels — "Previous" and "Current". Y-axis origin at 0.

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

---

## Goals

**Purpose:** Track strength, repetition, speed/distance, and weekly workout frequency targets.

### Layout
Left: blue ellipsis icon (functional — opens Goals ellipsis menu). Right: "+" button. ✦ divider. "Your Targets" header.

### Goal Card Design

Each goal card is divided into two regions: a **three-section left column** (goal details) and a **large circular/radial progress ring** right-justified on the trailing side (visual state).

**Three-Section Left Column:** Three sentence-case headers stacked vertically, each using Primary Accent (`#3b82f6`) color for the label and Primary Text (`#e5e5e5`) for the value below. Labels use the existing uppercase-adjacent style but in sentence case (11px, 700 weight, 2px letter-spacing). Values below each label use the standard Primary Text treatment.

| Label | Value |
|-------|-------|
| **Header (type-dependent — see Header Labels table below)** | Goal name (e.g., "Bench Press", "5K Run", "Weekly Workouts") |
| **Target** | Target value with unit, type-dependent (see below) |
| **Progress** | Current / target value with unit, type-dependent (see below) |

**Header Labels by goal type:** The first header is not a static "Goal" label — it varies by goal type (and, for Speed and Distance, by which targets are set) to make the goal's nature scannable at a glance. Labels use the same sentence-case label treatment as Target and Progress (11px, 700 weight, 2px letter-spacing, Primary Accent `#3b82f6`). Strings live in `CONSTANTS.md` § Goal Card Header Labels — do not hardcode in views.

| Goal Type | Sub-case | Header Label |
|-----------|----------|--------------|
| Strength PR | — | STRENGTH GOAL |
| Repetitions PR | — | REPS GOAL |
| Speed and Distance | Both distance and duration targets set | SPEED GOAL |
| Speed and Distance | Duration only | ENDURANCE GOAL |
| Speed and Distance | Distance only | DISTANCE GOAL |
| Number of Weekly Workouts | — | FREQUENCY GOAL |

**Target and Progress values by goal type:**

| Goal Type | Target Value | Progress Value |
|-----------|-------------|----------------|
| Strength PR | e.g., "225 lbs" | e.g., "100 / 225 lbs" |
| Repetitions PR | e.g., "25 reps" | e.g., "10 / 25 reps" |
| Speed and Distance (distance only) | e.g., "5 miles" | e.g., "2.00 / 5.00 mi" |
| Speed and Distance (duration only, endurance) | e.g., "30 minutes" | e.g., "45 / 30 min" |
| Speed and Distance (both — speed target) | e.g., "5 miles in 30 minutes" (conversational phrasing) | Two stacked lines: "2.00 / 5.00 mi" on top, "45 / 30 min" below |
| Number of Weekly Workouts | e.g., "3 workouts / week" | e.g., "14 / 3" |

**Circular Progress Ring (trailing side, right-justified):** Approximately **double the size of earlier iterations** (~120–140pt diameter). All goal cards align their rings to the trailing edge consistently — Speed and Distance rings must right-justify identically to PR rings (no centering caused by a legend below).

Centered inside the ring is a single element: the **Goal-type SF Symbol silhouette** at dynamic opacity (see § Silhouette Opacity in CONSTANTS.md).

The overall progress percentage is NOT rendered inside the ring — it is surfaced via a tap-to-reveal tooltip (see § Ring Tap Behavior below). This applies to all goal types, including dual-arc Speed and Distance.

**SF Symbol Mappings:**

| Goal Type | SF Symbol | Ring Color |
|-----------|-----------|------------|
| Strength PR | `figure.strengthtraining.traditional` | Goal's assigned color (cycling via `colorIndex`) |
| Repetitions PR | `figure.strengthtraining.traditional` | Goal's assigned color |
| Speed and Distance | `figure.run` | Dual-arc or single ring (see below) |
| Number of Weekly Workouts | `calendar` | Goal's assigned color |

**Silhouette Opacity Scaling:** Starts at **10% at 0% progress**, scaling linearly up to **~40% at 100% progress**. Completed state bumps opacity to **50–60%**. See `CONSTANTS.md` § Goal Silhouette Opacity for full table.

**Speed and Distance — Dual-Arc Ring:** When both distance and duration targets are set, the ring renders as two concentric arcs: **outer ring for distance** (purple `#4B2893`) and **inner ring for duration** (light cyan `#8FE6F6`). Both arcs share the same center SF Symbol (`figure.run`). The overall percentage is surfaced via the tap tooltip, not inside the ring (see § Ring Tap Behavior below). The legend is NOT displayed inline — it is surfaced via an overlay tooltip on tap (see Ring Tap Behavior below). If only one target is set (distance-only or duration-only), the card renders a single ring like other goal types, using the color corresponding to the active metric (purple for distance, light cyan for duration). Single-ring Speed and Distance cards use the same single-ring tap behavior as other goal types (see § Ring Tap Behavior below).

**Ring Tap Behavior:** Tapping any progress ring toggles a **subtle overlay tooltip** positioned just below the ring, with a small arrow pointer pointing up at the ring. The tooltip is an overlay (not inline) and does not push card content. Tap the ring again OR tap outside the ring to dismiss. Animation: 0.15s opacity fade-in/out.

Tooltip contents vary by goal type:

**Single-ring goals** (Strength PR, Repetitions PR, Number of Weekly Workouts, and single-target Speed and Distance): Tooltip displays the overall progress percentage only (e.g., "44%"). Primary Text (`#e5e5e5`), prominent size (~18–20pt, 800 weight) consistent with the app's heading treatment (see `PRD.md` § Typography).

**Dual-arc Speed and Distance** (both distance and duration targets set): Tooltip displays three stacked elements, top-to-bottom:
1. **Overall progress percentage** as a headline at the top (e.g., "11%"). Same styling as single-ring tooltip — Primary Text, ~18–20pt, 800 weight. Value is the lower of distance% and duration% after clamping (see "Speed target logic" below).
2. **Distance legend row** — a purple dot (`#4B2893`, per `CONSTANTS.md` § Speed and Distance Dual-Arc Ring Colors) with the label "Distance". Label uses the standard app label treatment (11px, 700 weight, 2px letter-spacing, Secondary Text `#a3a3a3`).
3. **Duration legend row** — a light cyan dot (`#8FE6F6`, per `CONSTANTS.md` § Speed and Distance Dual-Arc Ring Colors) with the label "Duration". Same label treatment as Distance row.

**Completed goals (100%):** Tapping a completed ring still surfaces the tooltip. The percentage shown is "100%". For dual-arc completed goals, the full Distance/Duration legend is displayed alongside "100%".

**Accessibility:** The overall progress percentage is included in each goal card's accessibility label so VoiceOver users hear it without needing to discover the tap gesture. For dual-arc cards, the accessibility label also describes the Distance/Duration color mapping.

**Completed State Treatment:** When a goal reaches 100% (Completed), the card displays:
- **Blue border** (`#3b82f6`) — unchanged from prior treatment.
- **Faint blue wash** — a subtle Primary Accent tint at **3% opacity** across the card surface, giving completed cards a warmer feel than active ones.
- **"COMPLETED [Formal Date]" micro-label** centered at the top of the card (e.g., "COMPLETED APR 17, 2026"). Uses Secondary Text color (`#a3a3a3`), 11px, 700 weight, 2px letter-spacing, uppercase. Date sourced from `Goal.lastCelebratedDate`.
- Ring fully filled.
- **Silhouette tinted Primary Accent Blue** (`#3b82f6`) and bumped to **85–100% opacity** so the icon reads as "lit up" rather than dim. Replaces the default tint used in active states. Applies to all goal-type silhouettes (`dumbbell.fill`, `figure.strengthtraining.traditional`, `figure.run`, `calendar`).
- **Color/opacity crossfade** — the silhouette transitions from its active-state appearance to the completed blue/lit state over **0.2–0.3s ease**, synchronized with the rest of the card's completion state change (border, wash, COMPLETED label appearing). Independent of the Completion Pulse Animation halo, which still fires once per visit when `lastCelebratedDate` matches today.
- **No "✦ VICTORY ✦" label** — replaced entirely by the "COMPLETED" micro-label and visual treatment above.

**Completion Pulse Animation:** When a user navigates to the Goals screen and a goal's `lastCelebratedDate` matches today (i.e., the goal completed today and the user hasn't yet acknowledged it on this visit), the ring fires a brief **glow/pulse animation** (approximately 1–1.5s total duration) to mark the achievement. The glow is a soft Primary Accent halo emanating from the ring and settling back into the static completed state. The pulse fires **once per visit** — not on every render while the user remains on the screen. Re-triggers only if the user leaves the Goals screen and returns while `lastCelebratedDate` is still today.

**Card Tease Animation:** Per § Standard Patterns: Long-Press Tease.

### Expandable Card with Sparkline

A **gray chevron** (muted #737373) is always visible at the bottom center of each goal card, pointing **down when collapsed** and **up when expanded**. Tapping the chevron expands the card to reveal a **30-day sparkline** (Swift Charts) showing goal progress over time.

**Section structure (always present when expanded, regardless of data state):**

1. **"LAST 30 DAYS" header** — Positioned above the sparkline chart area. Muted Text `#737373`, 11px, 700 weight, 2px letter-spacing, uppercase. Left-aligned within the expanded area. This header appears for ALL expanded cards — populated, partial, and brand-new. It anchors the section visually and tells the user what the chart represents before they look at the data.
2. **Sparkline chart area** — Swift Charts rendering, fills the width of the card's content region.
3. **Footer note below the chart** — Muted italic text, content varies by data state (see below).

**Sparkline rendering by data state:**

| State | Chart Rendering | Footer Note |
|-------|----------------|-------------|
| Populated (≥ 2 snapshots) | Swift Charts `LineMark` connecting data points. One point per workout day, plotting that day's **best-of-day session value** for the goal (e.g., top set weight for Strength PR, highest reps for Repetitions PR, best matching-workout `overallProgress %` for Speed and Distance, end-of-day workout count for Weekly Workouts). See `SERVICES.md` § GoalSnapshotService → Per-Workout Value Computation for the exact value per goal type. Reflects actual per-session performance — including regressions and light sessions — not just PR events. Days with no matching workout carry forward the previous value. Only days that exist are plotted — no zero-padding for goals with less than 30 days of history. | "Goal progress over the last 30 days" |
| Brand-new (0 or 1 snapshot) | **Skeleton flat dashed line** at a neutral midpoint (~50% of chart height) spanning the full chart width, rendered in Border `#404040` with a dashed stroke pattern (`StrokeStyle(dash: [4, 4])` or similar). No data point dot. No axis ticks. | "Log a workout to start tracking progress" |

As soon as the goal has 2+ snapshots, the chart transitions to the real line on the next expand (no special animation required).

**Other rules:**

- **Multiple expand:** Users can have multiple cards expanded simultaneously.
- **Animation:** 0.3s ease expand/collapse, sparkline fades in on expand.
- **Default state:** Collapsed.
- **After "Reset Goal Progress":** All snapshots for that goal are wiped. The sparkline returns to the brand-new skeleton state until new in-scope workouts produce snapshots (see `SERVICES.md` § Reset Goal Progress and § Reset Scoping).
- **Data source:** `GoalSnapshot` model (see `PRD.md` § Data Model, `SERVICES.md` § GoalSnapshotService).

**Goal Auto-Update:** See `SERVICES.md` for full behavior, including updated Speed Target logic.

### Goals Ellipsis Menu

Two options:

**"Filter Goals"** with SF Symbol `line.3.horizontal.decrease.circle` to the left: Opens a submenu with three filter options: **Active** (goals below 100%), **Completed** (goals at 100% / Completed state), **All** (default). The selected filter is indicated with a checkmark. Filters reset to "All" on every app launch — not persisted to UserDefaults.

**"Expand All / Collapse All"** with a toggling SF Symbol to the left: Toggles all goal cards open or closed. Label reflects the current dominant state: if most cards are collapsed, show "Expand All" with SF Symbol `rectangle.expand.vertical`; if most are expanded, show "Collapse All" with SF Symbol `rectangle.compress.vertical`. The symbol swaps alongside the label.

### Long-Press Context Menu
Long-pressing any goal card opens a context menu (uses Standard Long-Press Tease). Three options:

**"Delete Goal":** Tapping opens the standard delete confirmation ("Delete [Goal Title] goal? This cannot be undone."). On confirm: goal removed from SwiftData, associated GoalSnapshot records cascade-deleted, remaining goals re-index sortOrder.

**"Reset Goal Progress":** Tapping opens a confirmation dialog ("Reset [Goal Title] progress to zero? This cannot be undone."). On confirm: all current values on the goal reset to zero, `lastCelebratedDate` cleared. **Hidden entirely for Weekly Workouts goals** since their current value is derived at runtime and cannot be manually reset. This option does not appear in the ellipsis menu — it is exclusively per-card via long-press.

**"Reorder Goals":** Tapping enters reorder edit mode (see below). Always visible in the context menu regardless of goal count.

### Reorder Edit Mode
Per § Standard Patterns: Standard Reorder Edit Mode. Persists to `Goal.sortOrder`.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | "Set your first goal to start tracking." + ADD button |
| Populated | Full goal list with three-section left columns and large right-justified progress rings |
| Goal Completed | Blue border, faint blue wash (3% opacity), "COMPLETED [Date]" micro-label at top center, ring fully filled with silhouette tinted Primary Accent Blue at 85–100% opacity (crossfades in over 0.2–0.3s) |
| Completion Pulse | Brief glow/pulse animation on ring when user navigates to Goals screen with a goal whose `lastCelebratedDate` = today (once per visit) |
| Ring Tap Tooltip | Overlay below ring, surfaced on ring tap. Single-ring goals show overall progress percentage; dual-arc Speed and Distance shows percentage headline + Distance/Duration legend. Dismissed by re-tap or outside tap. |
| Card Expanded | "LAST 30 DAYS" header above sparkline chart area. Populated goals show real line chart with "Goal progress over the last 30 days" footer note. Brand-new goals show a flat dashed skeleton line with "Log a workout to start tracking progress" footer note |
| Filtered (Active) | Only goals below 100% shown |
| Filtered (Completed) | Only Completed goals shown |
| Reorder edit mode | Drag handles (≡) visible on all goal cards; cards draggable; context menu disabled; tap outside to exit |

---

## Add Goal

**Purpose:** Create a new goal.

### Layout
← BACK. "Add Goal" heading. Goal Type selector: "STRENGTH PR" (default), "REPETITIONS PR", "SPEED AND DISTANCE", "NUMBER OF WEEKLY WORKOUTS".

**Strength PR:** Exercise dropdown (Bench Press, Barbell Squats, Deadlifts, Overhead Press, Barbell Rows, Incline Bench Press, Custom). Custom → name input with autocomplete. Current weight / Target weight side by side.

**Repetitions PR:** Same exercise dropdown + Custom with autocomplete. Current reps / Target reps side by side.

**Speed and Distance:** Goal name input. Optional: Current distance / Target distance (km or mi per useMiles). Optional: Current duration / Target duration (minutes). At least one target required. Both = speed target (completion requires both). Duration alone = endurance (higher = better). Distance values stored as km.

**Number of Weekly Workouts:** Target workouts per week displayed as a read-only value reflecting the current `targetWorkoutsPerWeek` from UserSettings. Below the target value, an informational note in muted italic text: "This goal tracks your weekly workout target. To change the target, long-press the Weekly Streak widget on the Home screen and tap Configure Settings." No editable fields — the target is controlled exclusively via the Weekly Streak Settings Modal. The goal auto-updates its current value based on the current week's workout count (Mon–Sun).

"Save Goal" button. Validation: Strength PR → exercise + target weight > 0. Reps PR → exercise + target reps > 0. Speed/Distance → name + at least one target > 0. Weekly Workouts → always valid (target read from Settings; save button enabled immediately). Only one Weekly Workouts goal can exist at a time — if one already exists, the "NUMBER OF WEEKLY WORKOUTS" option in the Goal Type selector is grayed out with a muted "Already added" label.

**Edit mode:** The same view is used for editing an existing goal (entered from a tap on a goal card or from a future edit action). On save in edit mode, if the goal's `resetDate` is non-nil, it is cleared to nil — treating a deliberate goal-definition edit as a re-baselining action that brings previously out-of-scope workouts back into scope (see `SERVICES.md` § Reset Scoping and § Reset Goal Progress). Clearing `resetDate` also triggers `GoalSnapshotService.rebuildSnapshots(goal:)` to repopulate the sparkline from the now-in-scope workout history. The user is not shown an explicit "this will bring old workouts back" warning — the interaction is treated as intentional. In edit mode, Workout Type, Exercise, and Current fields are read-only.

---

## Settings

**Purpose:** Configure unit preferences and manage Apple Health integration.

### Layout
← BACK. "Settings" heading.

**"General" header.** Weight Unit card (KG/LBS toggle). Distance Unit card (KM/MILES toggle).

All General changes take effect immediately.

✦ divider.

**"Apple Health" header.** Section managing HealthKit integration. See HEALTHKIT.md § 16 for architectural detail and HEALTHKIT.md § 17 for authorization behavior.

### Apple Health Section

**Toggle:** "Connect to Apple Health" — FortiFitSegmentedToggle styled consistently with Weight Unit and Distance Unit toggles in the General section, but functionally a two-state on/off switch rather than a unit selector. Accessibility identifier: `settings_appleHealthToggle`.

**Description text (below toggle):** Muted text, 13px, 700 weight. Reads:

> "Import workouts from Apple Watch and other Health-connected apps. Linked workouts appear automatically and can't be fully unlinked in bulk."

**Status line (below description):** Muted text, 11px, 700 weight, uppercase, 2px letter-spacing. Content depends on state — see State Table below.

**Buttons (below status line, conditional):** Full-width or inline depending on state. See State Table.

### Apple Health Section — State Table

Four possible states driven by (toggle on/off) × (iOS authorization status):

| Toggle | iOS Auth | Status Line | Visible Buttons | Behavior on Toggle Tap |
|---|---|---|---|---|
| Off | Any (including not-yet-requested) | *(hidden — no status shown)* | None | Flipping on triggers authorization request (if not yet granted/denied); otherwise simply re-enables sync using cached authorization. |
| On | Granted | `CONNECTED · LAST SYNC {relative time}` OR `CONNECTED · NEVER SYNCED YET` | **"Sync Now"** (blue outlined, full-width) — accessibility identifier `settings_appleHealthSyncNowButton`. Tap → triggers immediate `HealthKitSyncService.importPendingWorkouts()`. Shows transient "Syncing…" label on button until complete, then updates status line. | Flipping off immediately suspends all sync activity. Existing linked workouts retain `healthKitUUID`. Confirmation alert: "Turn off Apple Health sync? Imported workouts will remain in FortiFit but new workouts from Apple Health won't appear automatically. Cancel / Turn Off." |
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

### First-Time Toggle-On Flow

On the first time a user flips the toggle to on:
1. FortiFit calls `HealthKitClient.requestAuthorization()`.
2. iOS presents the native permission prompt with the read permission list (see HEALTHKIT.md § 17).
3. User grants or denies. iOS returns control to FortiFit.
4. On grant: Settings status line updates to "CONNECTED · NEVER SYNCED YET." FortiFit immediately triggers a catch-up sync. Status line updates to "CONNECTED · JUST NOW" on completion.
5. On deny: Settings status line updates to "PERMISSION DENIED IN IOS SETTINGS." Toggle remains on (user's expressed intent), but no sync activity occurs. "Open iOS Settings" button becomes visible.

### Subsequent Toggle-Off → Toggle-On Flow

If the user previously granted authorization, toggles off, then toggles back on later:
- No re-authorization prompt (iOS caches the original grant).
- Sync resumes immediately from the persisted `HKQueryAnchor`. Any workouts added, updated, or deleted upstream during the off period are processed in the next catch-up sweep.

### Confirmation Alert Copy

**Turn-off confirmation:**
> Title: "Turn off Apple Health sync?"
> Message: "Imported workouts will remain in FortiFit but new workouts from Apple Health won't appear automatically."
> Buttons: "Cancel" / "Turn Off"

Destructive action — "Turn Off" button styled in the standard destructive red.

### States

| State | What the User Sees |
|-------|-------------------|
| Initial load (General section) | KG/LBS and KM/MILES toggles reflect current preferences |
| Apple Health off | Toggle off, description visible, no status line, no buttons |
| Apple Health on — connected | Toggle on, description, "CONNECTED · …" status, "Sync Now" button |
| Apple Health on — denied | Toggle on, description, "PERMISSION DENIED IN IOS SETTINGS" status, "Open iOS Settings" button |
| Sync in progress | Same as connected state, but "Sync Now" button shows transient "Syncing…" label and is disabled until complete |

---

## Match Prompt Sheet

**Purpose:** Resolve lower-confidence deduplication matches between HealthKit-imported workouts and existing FortiFit workouts. See HEALTHKIT.md § 13 and SERVICES.md § WorkoutMatcher for the matcher logic that produces pending matches.

### Trigger

Appears as a modal sheet on app foreground transition when `WorkoutMatcher.pendingMatches()` returns one or more pending pairings. One sheet per pending match — if multiple are queued, they appear sequentially (next sheet presents after the previous is resolved).

**Not triggered by:** navigation to any specific screen, user tap, or settings toggle. Foreground transition is the sole automatic trigger. The sheet is dismissible via "Decide Later" (leaves the match in the queue) so the user is never trapped.

### Layout

iOS modal sheet (sheet presentation). The sheet uses the `.large` detent (or a custom `.height(...)` detent sized to fit the full content) so the entire body paragraph and both summary cards are visible without the user having to scroll or drag the sheet up. The previous `.medium` detent truncated the body paragraph beneath "Possible Match" — do not use `.medium` here. Swipe-down dismissal maps to "Decide Later."

- **Header:** "Possible Match" (primary text, 20px 900 weight, centered).
- **Body paragraph:** "Apple Health imported a workout that looks similar to one you already logged. Would you like to link them?" (secondary text, 14px, centered, standard paragraph spacing). Use `.fixedSize(horizontal: false, vertical: true)` so the paragraph is never vertically clipped by the sheet.
- **Side-by-side summary cards:** Two FortiFitCards rendered horizontally side-by-side. Each card displays the workout's key metadata in a compact layout.

  **Left card — HealthKit workout:**
  - HealthKit-pink heart icon (`heart.fill`) + "FROM APPLE HEALTH" label (HealthKit Pink color, 11px 700 weight uppercase, 2px letter-spacing). The label **must wrap to a second line** within the card rather than truncate — apply `.lineLimit(nil)` and `.fixedSize(horizontal: false, vertical: true)` to the label, and use `.minimumScaleFactor(1.0)` (no shrinking). The heart icon stays on the same baseline as the first line of the wrapped label.
  - Workout type pill (using FortiFit category mapped from HK type)
  - `healthKitActivityType` display string (primary text, 14px semibold)
  - Start time (e.g., "7:02 PM", muted 13px)
  - Duration (e.g., "45 min", muted 13px)
  - Distance if present (e.g., "5.2 km", muted 13px; unit per useMiles)
  - Avg HR if present (e.g., "142 bpm avg", muted 13px)
  - Active calories if present (e.g., "487 kcal", muted 13px)

  **Right card — FortiFit workout:**
  - "YOUR LOG" label (Primary Accent Blue `#3b82f6` via `FortiFitColors.primaryAccent`, 11px 700 weight uppercase, 2px letter-spacing). Mirrors the standard sentence-case Primary-Accent label treatment used elsewhere (see CONSTANTS.md line 448). Same wrap rules as the left card's label: `.lineLimit(nil)` + `.fixedSize(horizontal: false, vertical: true)` so the cards stay visually balanced if either label expands.
  - Workout type pill
  - `workout.name` (primary text, 14px semibold)
  - Start time from `workout.time` (muted 13px)
  - Duration if present (muted 13px)
  - Effort if rated (e.g., "Effort 7", muted 13px)
  - ExerciseSets count if present (e.g., "5 exercises", muted 13px)

- **Primary action row (three vertically stacked buttons):**
  - **"Link these workouts"** — Full-width blue-filled button (Primary Accent #3b82f6). Accessibility identifier `matchPromptSheet_linkButton`. Tap → `WorkoutMatcher.resolvePending(...decision: .link)` → applies link per SERVICES.md § WorkoutMatcher → Link Application → sheet dismisses → toast "Workouts linked." (~2s).
  - **"Keep separate"** — Full-width blue-outlined button. Accessibility identifier `matchPromptSheet_keepSeparateButton`. Tap → `WorkoutMatcher.resolvePending(...decision: .keepSeparate)` → creates `WorkoutMatchRejection` → sheet dismisses → no toast.
  - **"Decide later"** — Text-only link-style button (muted text). Accessibility identifier `matchPromptSheet_decideLaterButton`. Tap → `WorkoutMatcher.resolvePending(...decision: .decideLater)` → leaves match in queue → sheet dismisses → no toast.

### Button Ordering Rationale

Link is primary because it's the most common correct answer when the matcher has already filtered for same-type, same-day, within-4-hours workouts. Keep Separate is secondary (less common but deliberate). Decide Later is de-emphasized (punt action, low commitment).

### Post-Resolution Behavior

**On Link:** `WorkoutMatcher.applyLink()` runs — HK-owned fields copied from the snapshot to the FortiFit Workout, user-owned fields preserved, `lastModifiedDate` bumped, Workout Cascade fires. The Workout is now surfaced as HK-linked everywhere (source indicator on Workout Detail, peripheral glyph on Home/Workouts/Plan).

**On Keep Separate:** `WorkoutMatchRejection` record persists the (`healthKitUUID`, `workoutId`) pair. Future sync events will not re-propose this pairing. The HK workout proceeds to auto-create as a new separate FortiFit Workout (if it hasn't already been auto-created by a prior sync pass).

**On Decide Later:** Match stays queued. Re-prompts on next foreground transition. No auto-create yet — the HK workout remains in `WorkoutMatcher`'s candidate pool pending resolution.

### Sequential Multi-Match Handling

If 3 pending matches are queued, the user sees 3 sheets in sequence. Each resolves independently. No batch-resolve option in MVP — the sequential approach is simpler and keeps each decision explicit.

### Accessibility

All three buttons have accessibility identifiers (see § Button list above). The summary card contents use standard VoiceOver traversal (header → cards left-to-right → buttons top-to-bottom). No custom accessibility actions needed.

### States

| State | What the User Sees |
|-------|-------------------|
| Match queued | Sheet presents on foreground transition with side-by-side summary cards and three actions |
| Resolving (transient) | After tap, sheet dismisses immediately; toast or next sheet appears |
| No pending matches | Sheet does not present — normal app state |
