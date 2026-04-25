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

---

## Home Screen

**Purpose:** Central hub showing training status, quick stats, and access to logging. Fully customizable widget layout.

### Widget Card System
Per § Standard Patterns: Sortable Card System, backed by `HomeWidget` records. Default seed order (first launch only): **Training Load, Workout Info, Weekly Streak**. Home's edit mode is a variant of the standard — see § Widget Edit Mode below.

### Layout
Top: Left: blue ellipsis icon (functional — opens Home ellipsis menu). Right: blue gear icon (→ Settings). ✦ divider. Widget cards render vertically by `sortOrder`. Full-width blue-outlined "+ Log Workout" button below last widget. "Recent Workouts" header, then list of 5 most recent (name, date, exercise count, chevron). Recent Workouts list and "+ Log Workout" are unaffected by widget customization.

### Home Ellipsis Menu
One option: **"Add Widgets"** with SF Symbol `plus.rectangle.on.rectangle` to the left → opens Add Widgets Menu overlay.

### Add Widgets Menu
Per § Standard Patterns: Sortable Card System → Add Menu.

### Widget Edit Mode
Activated by long-pressing any widget card (uses Standard Long-Press Tease). Unlike the standard "Reorder from context menu" pattern, Home combines delete + drag in one edit mode entered directly by long-press:
- "x" button appears in top-right of each widget (24x24pt circular, #2d2d2d bg, #404040 border, muted "×"). Tapping deletes the `HomeWidget` record, removes the card, re-indexes remaining `sortOrder`.
- Gear icons on Training Load and Weekly Streak widgets are hidden during edit mode.
- Cards are draggable with the same drag physics as Standard Reorder Edit Mode (0.2s ease, sortOrder re-indexed on drop).
- Cards maintain full styling during edit and drag.
- Exit by tapping outside any widget. "x" buttons fade out (0.15s).

### Widget Definitions

**Training Load** (`trainingLoad`): Blue-bordered card. "Training Load" header + "?" tooltip positioned close to the title (left-aligned with small padding), blue gear icon in the upper-right corner of the card. Tapping "?" opens the standard Training Load explanation. Tapping the gear icon opens the **Training Load Settings Modal** (see below). Zone label (e.g., "Moderate"), gradient progress bar (LOW→HIGH), context-aware advisory text below. Advisory shows readiness variant (no workout today) or post-training variant (trained today). See `CONSTANTS.md` for advisory text table and `SERVICES.md` for algorithm. Score updates in real time on workout log/edit/delete.

**Training Load Settings Modal:** Centered modal with dimmed background. "Configure Training Load" heading + "?" tooltip (explains experience affects decay rate and stress capacity). Training Experience card (3-position slider: Beginner/Intermediate/Advanced). Target Workout Duration card (slider 0–300 min) — fallback duration for Training Load algorithm. All changes take effect immediately. Experience level change recalculates Training Load. Dismiss via close button or outside tap.

**Workout Info** (`workoutInfo`): "Workout Info" header. Interior split by vertical divider (#404040). Left: "LAST WORKOUT" muted label above name + date of most recent workout (or "—"). Right: "TOTAL WORKOUTS" muted label above count (or "—").

**Weekly Streak** (`weekStreak`): "Weekly Streak" card. Blue gear icon in the upper-right corner of the card. Tapping the gear icon opens the **Weekly Streak Settings Modal** (see below). Left: animated blue flame SVG scaling by tier. Right: streak count (32px, 900 weight), "WEEK STREAK" label (blue uppercase), motivational message (muted italic). See `CONSTANTS.md` for flame tiers and messages, `SERVICES.md` for algorithm. Flame flickers (1.2s outer, 0.9s inner loops).

**Weekly Streak Settings Modal:** Centered modal with dimmed background. "Configure Streak Widget" heading. Target Workouts per Week card (slider 0–99). Used exclusively by Streak algorithm. All changes take effect immediately. Target workouts change recalculates streak retroactively. Dismiss via close button or outside tap.

**Power Level** (`powerLevel`): Blue-bordered card. "Power Level" header + "?" tooltip positioned close to the title (left-aligned with small padding, matching Training Load layout). Status label (Deloading/Steady/Rising), directional indicator (↓/—/↑ with status-specific color), contextual message (muted italic). See `CONSTANTS.md` for messages, `SERVICES.md` for algorithm.

**Today's Plan** (`todaysPlan`): "Today's Plan" header. Card interior is split into two columns — workout info on the left, calendar square on the right.

**Left column (workout info):** If one or more planned workouts exist today, shows the first uncompleted workout — template name (primary text), workout type pill (muted uppercase), and a compact blue-outlined "Complete Workout" button spanning only the left column (opens the same compact confirmation sheet as the Plan tab — see SCREENS.md § Plan). If additional planned workouts remain beyond the one displayed, a muted note "X more planned" appears below the button (11px, 700 weight, muted text). When a workout is completed, the widget automatically repopulates with the next planned workout on the same day. If all today's workouts are completed: "All planned workouts completed." (muted, with green checkmark). If no workouts scheduled today: "No workout planned for today." (muted text).

**Right column (calendar square):** Always visible in all states. Rounded rectangle container styled after the iOS Calendar icon in FitNavi colors. Top bar: Primary Accent Blue (#3b82f6) background with the day abbreviation (e.g., "MON") in white text, uppercase, bold. Body area: dark surface (#1a1a1a or elevated #2d2d2d) with the month and date number rendered large and prominent in primary text (#e5e5e5). Blue and green dot indicators appear below the date number matching Plan tab dot logic — blue dot = planned `ScheduledWorkout`, green dot = completed from either a completed `ScheduledWorkout` OR a logged-only `Workout` surfaced on Plan (see SCREENS.md § Plan → Logged-Only Workout Surfacing for the inclusion rule). The left column's workout info, "Complete Workout" button, and "No workout planned for today." / "All planned workouts completed." messaging remain scoped exclusively to `ScheduledWorkout` records — logged-only workouts do **not** appear in the left column.

Included in default widget set — also available via Add Widgets menu.

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | All widgets at default/empty: Training Load 0% "Resting", Workout Info "—"/"—", Streak 0 dormant flame, Power Level "No data" message |
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
- **Workout Name** — 16px semibold.
- **Date** — muted text.
- **Duration** — muted text, Strength/HIIT only when recorded.
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
- **RPE range:** Min/max stepper 1–10. Nil RPE workouts excluded when active.
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
← BACK. Top right: blue ellipsis (new-workout mode only — hidden in edit mode). Heading: "Log Workout" (new) / "Edit Workout" (edit).

Workout Name input. Single SwiftUI `DatePicker` with `.dateAndTime` components — date defaults to today, constrained to today or earlier; any time selectable; format follows iOS locale (12/24-hour). Date stored on `workout.date`, time on `workout.time`.

Workout Type dropdown (6 types). Post-Workout RPE dropdown (1–10) + "?" tooltip. Duration field (minutes, optional) — shown for all types, below RPE.

**Type-specific fields below duration:**
- **Strength Training / HIIT:** Exercise cards (name input with autocomplete, sets/reps/weight table, + ADD ROW, remove). "+ Add Exercise" button. Each table row = one ExerciseSet.
- **Cardio / Sprints:** Distance field (km or mi per useMiles, optional). No exercises.
- **Yoga / Pilates:** No additional fields. No distance.

### Log Workout Ellipsis Menu (New Mode Only)
**"Use workout template"** with SF Symbol `doc.badge.arrow.up` to the left → Centered selector overlay listing all templates (name + type). Selecting pre-populates form (name, type, duration, exercises). Date/time default to now, RPE empty. All fields editable. Shows "No saved templates yet." when empty.

**"Save as workout template"** with SF Symbol `square.and.arrow.down` to the left → Grayed out when type isn't Strength/HIIT or when name + exercise not yet entered. Opens naming prompt (pre-filled with workout name). Saves template to SwiftData + "Template saved!" toast (auto-dismiss ~2s). Does NOT log the workout.

### Save Button
"Save Workout" (new) / "Save Changes" (edit). Disabled until name filled. Enabled = blue.

### Edit Mode Behavior
All fields pre-populated. Heading: "Edit Workout". Workout type dropdown locked. Blue trash icon (16px) in top-right → standard delete confirmation → deletes workout + ExerciseSets, cascade recalcs (PR, goals, Training Load, streak, Workout Type card), navigates to Workouts list. Adding exercise = new ExerciseSet on save. Modifying row = update ExerciseSet. Removing row = delete ExerciseSet. Ellipsis hidden.

---

## Create Template

**Purpose:** Build a reusable workout template from scratch, or edit an existing one.

### Layout
← BACK. Heading: "Create Template" (new) / "Edit Template" (edit). Template Name input (required). Workout Type dropdown — Strength Training and HIIT only. Duration (optional). Exercise cards identical to Log Workout for Strength/HIIT. "+ Add Exercise" button. No RPE, no DatePicker, no distance.

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
- Workout name (primary text, 16px semibold).
- Workout type pill (muted, uppercase, 11px) followed by ` · LOGGED SESSION` metadata to the right of the pill (11px, 700 weight, uppercase, muted text — matches pill label styling but sits outside the pill boundary). `· LOGGED SESSION` is the source affordance and appears **only** on logged-only cards, not on completed scheduled cards.
- Duration (muted, if `workout.durationMinutes` is set; omitted if nil).
- Muted "COMPLETED" label with green checkmark in place of any action button.

Days with no scheduled or logged-only workouts show no content in the detail area. The "+" button in the Plan header is the sole entry point for scheduling.

**Overdue planned workouts** (scheduled date in the past, status still "planned"): Card shows a muted "OVERDUE" badge (11px, 700 weight, uppercase, muted text) below the workout type pill.

**Completed scheduled workouts:** Card visually marked with green checkmark and muted styling. Next to the workout type name is `· PLANNED SESSION`. "Complete Planned Workout" button replaced with muted "COMPLETED" label. `· PLANNED SESSION` is the source affordance and appears **only** on scheduled-only cards, not on completed logged cards.

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
   - **RPE** — horizontal row of numbered pills (1–10), consistent with Log Workout RPE input. Optional. No default value.
   - **Duration** — FortiFitInput with "min" suffix label. Optional. Pre-filled from template's `durationMinutes` if available.
   - **"Save Workout"** button (full-width, blue filled, prominent).
   - **"Modify Exercises"** button below "Save Workout" (full-width, blue-outlined secondary style). Routes to full Log Workout view pre-populated from template snapshot.
4. **On "Save Workout":** Creates `Workout` from template snapshot (name, type, exercises/sets/reps/weights) plus RPE and duration from sheet. Marks `ScheduledWorkout` as completed, stores new `Workout.id` in `completedWorkoutId`. Dismisses sheet. Toast: "Workout completed." (~2s auto-dismiss).
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

Top-right icons: blue share icon (16px, `square.and.arrow.up`, #3b82f6), muted edit icon (16px), muted trash icon (16px). Blue ellipsis icon (16px) to right of trash, shown when at least one ellipsis menu item applies (see Ellipsis Menu below). Share → renders workout as styled image card and presents iOS share sheet (see Share Image Card below). Edit → Log Workout in edit mode. Trash → standard delete confirmation → cascade delete, back to Workouts list.

**Ellipsis Menu:** Items appear conditionally based on workout type and state. The ellipsis icon itself is shown only when at least one item is visible.

- **"Save as workout template"** with SF Symbol `square.and.arrow.down` to the left → naming prompt (pre-filled with workout name) → saves template (name, type, duration, exercises — NOT RPE, date, time, notes) → "Template saved!" toast (~2s). Visible only for Strength Training / HIIT workouts.
- **"Show on Plan"** with SF Symbol `calendar.badge.plus` to the left → flips `workout.hiddenFromPlan` from `true` to `false`. No confirmation alert (non-destructive, trivially reversible). Toast: "Showing on Plan." (~2s auto-dismiss). Visible only when `workout.hiddenFromPlan == true`. Applies to all workout types — if this is the only applicable item (e.g., a hidden Cardio workout), the ellipsis icon appears with just this single option. When both items apply (a hidden Strength/HIIT workout), "Show on Plan" is rendered immediately below "Save as workout template".

✦ divider. Content varies by type. Each summary field is rendered with a leading SF Symbol to the left of the label (see CONSTANTS.md § Workout Detail Summary Icons): RPE → `heart.gauge.open`, Duration → `clock`, Distance → `ruler`. Icons are rendered at the same size and color as the summary row label text, with standard spacing between icon and label.

- **Strength/HIIT:** "Summary" header. RPE if rated + duration if entered (fields not entered are hidden). "Exercises" header, exercise list (name, sets, weight).
- **Cardio/Sprints:** "Summary" header. RPE if rated, duration, distance (km or mi per useMiles) — unrecorded fields hidden.
- **Yoga/Pilates:** "Summary" header. RPE if rated, duration — unrecorded fields hidden.

✦ divider. "Session Notes" header + edit icon. Note card or textarea when editing + SAVE button.

### Share Image Card

Tapping the share icon renders the workout as a styled PNG image card and presents the iOS share sheet (`UIActivityViewController`). The image is a self-contained card using FitNavi's design tokens, designed to be legible as a standalone image outside the app.

**Card content (type-adaptive):**

| Workout Type | Content Shown |
|---|---|
| Strength Training / HIIT | Workout name, date/time, workout type, summary pills (RPE if rated, duration if recorded), exercise list (name, sets × reps @ weight per unit preference; "BW" for nil weight) |
| Cardio / Sprints | Workout name, date/time, workout type, summary pills (RPE if rated, duration if recorded, distance in km/mi per useMiles if recorded) |
| Yoga / Pilates | Workout name, date/time, workout type, summary pills (RPE if rated, duration if recorded) |

Summary pills with nil values are omitted entirely (no empty pill shown). When `workout.time` is nil, the time component is omitted from the date line.

**Summary pill icons:** Each summary pill renders with a leading SF Symbol matching the corresponding field on the Workout Detail screen — RPE → `heart.gauge.open`, Duration → `clock`, Distance → `ruler` (Cardio/Sprints only). See CONSTANTS.md § Workout Detail Summary Icons and § Share Image Card Styling.

**Exercise cap:** Maximum 10 exercises displayed. If the workout has more than 10, the first 10 are shown followed by a muted "+X more exercises" line (e.g., "+3 more exercises").

**Excluded from image:** Session notes, navigation chrome (back button, icon tray).

**Card styling:** See `CONSTANTS.md` § Share Image Card Styling for the full token table (background, border, padding, header/footer, workout name, date, summary pills, exercise rows, dividers, image dimensions).

**Rendering:** SwiftUI `ImageRenderer` at @3x scale. If rendering fails, show a brief toast: "Couldn't generate image. Try again." (auto-dismiss ~2s, matching existing toast pattern).

**Edge cases:**

| Scenario | Behavior |
|----------|----------|
| All optional fields nil (no RPE, no duration, no distance) | No summary pills rendered; card shows name, date, type, and exercises (if any) |
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
Activated by long-pressing any chart card (uses Standard Long-Press Tease). Two options:

**"Delete Chart":** Per § Standard Patterns: Sortable Card System → Delete. Confirmation: "Delete [Chart Display Name]? This cannot be undone."

**"Reorder Charts":** Enters Standard Reorder Edit Mode. Always visible in the context menu regardless of chart count.

### Reorder Edit Mode
Per § Standard Patterns: Standard Reorder Edit Mode. Persists to `TrendsChart.sortOrder`.

### Chart Definitions

**Strength Tracker** (`strengthTracker`): Exercise dropdown, 30D/60D/90D toggles, line chart of weight over time, latest value.

**Training Frequency** (`trainingFrequency`): Bar chart of weekly sessions (8 weeks), blue dashed target reference line, legend.

**Personal Records** (`personalRecords`): Exercise dropdown listing only exercises with at least one PR event (see PR Definition below). On selection, displays most recent PR value + date and previous record value + date. Visualized as a bar chart comparing previous record vs. current record (see PR Layout below).

**Training Load Trend** (`trainingLoadTrend`): Line chart, one dot per day colored by zone (Low/Moderate/High/Peak), blue dashed 7-day rolling average, zone-colored background bands, zone legend.

**Workout Volume** (`workoutVolume`): Line chart of total session volume (sets × reps × weight) over time for Strength Training and HIIT workouts. 30D/60D/90D toggles. Each data point = one workout. Blue line with data point dots.

**RPE Trend** (`rpeTrend`): Bar chart of weekly average RPE (8-week rolling window, same as Training Frequency). Horizontal dashed reference line at RPE 7. Includes workouts with and without recorded RPE.

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
| RPE Trend | 1 full Mon–Sun week with ≥ 1 workout with recorded RPE | "Log workouts with RPE ratings to display effort trends" |
| Workout Type Breakdown | 2 workouts of any type | "Log more workouts to display your training breakdown" |
| Session Duration | 1 full Mon–Sun week with ≥ 1 workout with recorded duration | "Log workouts with duration to display session length trends" |

### States
| State | What the User Sees |
|-------|-------------------|
| Empty | All charts show empty state messages |
| Partial | Charts meeting threshold render; others show empty message |
| Populated | All charts with full data and controls |
| Reorder edit mode | line.3.horizontal SF symbol drag handles rotated 90 degrees vertically visible on all chart cards; cards draggable; context menu disabled; tap outside to exit |
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

**Number of Weekly Workouts:** Target workouts per week displayed as a read-only value reflecting the current `targetWorkoutsPerWeek` from UserSettings. Below the target value, an informational note in muted italic text: "This goal tracks your weekly workout target. To change the target, tap the gear icon on the Weekly Streak widget on the Home screen." No editable fields — the target is controlled exclusively via the Weekly Streak Settings Modal. The goal auto-updates its current value based on the current week's workout count (Mon–Sun).

"Save Goal" button. Validation: Strength PR → exercise + target weight > 0. Reps PR → exercise + target reps > 0. Speed/Distance → name + at least one target > 0. Weekly Workouts → always valid (target read from Settings; save button enabled immediately). Only one Weekly Workouts goal can exist at a time — if one already exists, the "NUMBER OF WEEKLY WORKOUTS" option in the Goal Type selector is grayed out with a muted "Already added" label.

**Edit mode:** The same view is used for editing an existing goal (entered from a tap on a goal card or from a future edit action). On save in edit mode, if the goal's `resetDate` is non-nil, it is cleared to nil — treating a deliberate goal-definition edit as a re-baselining action that brings previously out-of-scope workouts back into scope (see `SERVICES.md` § Reset Scoping and § Reset Goal Progress). Clearing `resetDate` also triggers `GoalSnapshotService.rebuildSnapshots(goal:)` to repopulate the sparkline from the now-in-scope workout history. The user is not shown an explicit "this will bring old workouts back" warning — the interaction is treated as intentional. In edit mode, Workout Type, Exercise, and Current fields are read-only.

---

## Settings

**Purpose:** Configure unit preferences.

### Layout
← BACK. "Settings" heading.

**"General" header.** Weight Unit card (KG/LBS toggle). Distance Unit card (KM/MILES toggle).

All changes take effect immediately.
