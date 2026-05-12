# HK_MAPPING.md: HealthKit ↔ FitNavi Workout Type Mapping

> Static lookup tables for the bidirectional mapping between HealthKit's `HKWorkoutActivityType` enum and FortiFit's `workoutType` strings.
>
> **Inbound (HK → FortiFit, Phase 8+):** every `HKWorkoutActivityType` case maps to a FortiFit `workoutType` plus a friendly display string (stored on `Workout.healthKitActivityType`). Consumed by `HealthKitSyncService` at import time. Many-to-one (multiple HK types collapse into one FortiFit type). Architectural rationale lives in HEALTHKIT.md § 6.
>
> **Outbound (FortiFit → HK, Phase 8.7+):** each FortiFit `workoutType` that can be scheduled (Strength Training, HIIT) maps to a single `HKWorkoutActivityType` for stamping on `WorkoutComposition`s sent to the Watch via WorkoutKit. One-to-one. Consumed by `WatchScheduleService` at plan composition time. Architectural rationale lives in WORKOUTKIT.md § 6.

## Rules

- Every currently defined `HKWorkoutActivityType` has an explicit entry below.
- Unknown types (introduced by future iOS versions) fall through to `Other` with the raw enum case name as the display string. Implement as a `default` case in the mapping function.
- Indoor/outdoor variants (`running`, `cycling`, `rowing`, etc.): the display string is the base name; `workout.indoor` controls "Indoor"/"Outdoor" prefixing at display time (see SCREENS.md § Workout Detail).
- Static table. Not user-configurable.

## Mapping Table

| HKWorkoutActivityType | Display String | FortiFit `workoutType` |
|---|---|---|
| `americanFootball` | American Football | Other |
| `archery` | Archery | Other |
| `australianFootball` | Australian Rules Football | Other |
| `badminton` | Badminton | Other |
| `barre` | Barre | Other |
| `baseball` | Baseball | Other |
| `basketball` | Basketball | Other |
| `bowling` | Bowling | Other |
| `boxing` | Boxing | Other |
| `cardioDance` | Cardio Dance | Cardio |
| `climbing` | Climbing | Other |
| `cooldown` | Cooldown | Other |
| `coreTraining` | Core Training | Strength Training |
| `cricket` | Cricket | Other |
| `crossCountrySkiing` | Cross-Country Skiing | Cardio |
| `crossTraining` | Cross Training | HIIT |
| `curling` | Curling | Other |
| `cycling` | Cycling | Cardio |
| `discSports` | Disc Sports | Other |
| `downhillSkiing` | Downhill Skiing | Cardio |
| `elliptical` | Elliptical | Cardio |
| `equestrianSports` | Equestrian Sports | Other |
| `fencing` | Fencing | Other |
| `fishing` | Fishing | Other |
| `fitnessGaming` | Fitness Gaming | HIIT |
| `flexibility` | Flexibility | Other |
| `functionalStrengthTraining` | Functional Strength Training | Strength Training |
| `golf` | Golf | Other |
| `gymnastics` | Gymnastics | Other |
| `handCycling` | Hand Cycling | Cardio |
| `handball` | Handball | Other |
| `highIntensityIntervalTraining` | HIIT | HIIT |
| `hiking` | Hiking | Cardio |
| `hockey` | Hockey | Other |
| `hunting` | Hunting | Other |
| `jumpRope` | Jump Rope | Other |
| `kickboxing` | Kickboxing | Other |
| `lacrosse` | Lacrosse | Other |
| `martialArts` | Martial Arts | Other |
| `mindAndBody` | Mind and Body | Other |
| `mixedCardio` | Mixed Cardio | Cardio |
| `mixedMetabolicCardioTraining` | Mixed Metabolic Cardio Training | Cardio |
| `paddleSports` | Paddle Sports | Cardio |
| `pickleball` | Pickleball | Other |
| `pilates` | Pilates | Pilates |
| `play` | Play | Other |
| `preparationAndRecovery` | Preparation and Recovery | Other |
| `racquetball` | Racquetball | Other |
| `rowing` | Rowing | Cardio |
| `rugby` | Rugby | Other |
| `running` | Running | Cardio |
| `sailing` | Sailing | Other |
| `skatingSports` | Skating Sports | Cardio |
| `snowSports` | Snow Sports | Cardio |
| `snowboarding` | Snowboarding | Cardio |
| `soccer` | Soccer | Other |
| `socialDance` | Social Dance | Cardio |
| `softball` | Softball | Other |
| `squash` | Squash | Other |
| `stairClimbing` | Stair Climbing | Cardio |
| `stairs` | Stairs | Cardio |
| `stepTraining` | Step Training | Cardio |
| `surfingSports` | Surfing | Cardio |
| `swimBikeRun` | Swim Bike Run | Cardio |
| `swimming` | Swimming | Cardio |
| `tableTennis` | Table Tennis | Other |
| `taiChi` | Tai Chi | Other |
| `tennis` | Tennis | Other |
| `trackAndField` | Track and Field | Cardio |
| `traditionalStrengthTraining` | Traditional Strength Training | Strength Training |
| `transition` | Transition | Cardio |
| `underwaterDiving` | Underwater Diving | Other |
| `volleyball` | Volleyball | Other |
| `walking` | Walking | Cardio |
| `waterFitness` | Water Fitness | Cardio |
| `waterPolo` | Water Polo | Other |
| `waterSports` | Water Sports | Cardio |
| `wheelchairRunPace` | Wheelchair Run Pace | Cardio |
| `wheelchairWalkPace` | Wheelchair Walk Pace | Cardio |
| `wrestling` | Wrestling | Other |
| `yoga` | Yoga | Yoga |
| `other` | Other | Other |
| *(unknown future types)* | *raw enum name* | Other |

## Ambiguous Mappings (Judgment Calls)

The mapping table above is authoritative. The notes below capture cases where multiple FitNavi categories were plausible — informational only.

| HK Type | Chosen | Alternative | Rationale |
|---|---|---|---|
| `crossTraining` | HIIT | Strength Training | CrossFit-style mixed workouts blend both; metabolic intensity leans HIIT. |
| `fitnessGaming` | HIIT | Cardio | Most (Ring Fit, Beat Saber fitness modes) are interval-based. |
| `stepTraining` | Cardio | HIIT | Step aerobics is sustained moderate-intensity. |
| `wrestling` | Other | Strength Training | Team/competitive context dominates over strength character. |
| `martialArts` | Other | HIIT | Huge variance (Krav Maga vs Aikido); "Other" is the safe default. |
| `trackAndField` | Cardio | Other | Most tracked events (running, sprinting) are cardio. |
| `paddleSports` | Cardio | Other | Kayaking/canoeing are sustained cardiovascular activity. |
| `surfingSports` | Cardio | Other | Active paddling and balance work; net cardiovascular demand. |
| `waterSports` | Cardio | Other | Generic water activities lean cardio. |

**Resolved to Other by design:** `barre`, `boxing`, `kickboxing`, `jumpRope`, `gymnastics`, `mindAndBody`, `taiChi`, `flexibility`, `cooldown`, `preparationAndRecovery`. Earlier drafts placed several of these elsewhere; moved to Other to keep the five primary categories tight and avoid muddying Training Load modifiers with high-variance activities.

## Changing a Mapping

Edit the table above, then verify the HK-to-category mapping unit test in `FortiFitTests` still passes (the test iterates every enum case and asserts the expected category — see TESTING.md § HealthKit Test Strategy).

---

## Outbound Mapping (FortiFit → HK, Phase 8.7+)

When `WatchScheduleService` builds a `WorkoutComposition` to send to the Watch via WorkoutKit, it needs a single `HKWorkoutActivityType` to stamp on the plan. WorkoutKit doesn't accept "either Traditional or Functional" — it's one enum value per plan.

### Mapping Table

| FortiFit `workoutType` | Outbound `HKWorkoutActivityType` | Display String (post-completion via WorkoutKit) |
|---|---|---|
| Strength Training | `.traditionalStrengthTraining` | "Traditional Strength Training" |
| HIIT | `.highIntensityIntervalTraining` | "HIIT" |

### Why These Defaults

- **Strength Training → `.traditionalStrengthTraining`.** FitNavi's user base tracks discrete sets/reps with barbells, dumbbells, and machines — Traditional Strength Training is the right fit. Functional Strength Training (kettlebell complexes, Turkish get-ups, multi-joint movement patterns) is a meaningfully different population. Defaulting to Traditional handles the dominant case; the rarer Functional crowd is acknowledged but not supported with a per-template override in MVP (see § No Per-Template Override below).
- **HIIT → `.highIntensityIntervalTraining`.** The unambiguous match. The other HIIT-mapped inbound types (`crossTraining`, `fitnessGaming`) don't represent FitNavi's intent for outbound.

### Round-Trip Consistency

The outbound mapping pairs cleanly with the existing inbound table:

1. FitNavi schedules a Strength Training workout → outbound stamps `.traditionalStrengthTraining`.
2. Watch records the session → `HKWorkout` carries `workoutActivityType = .traditionalStrengthTraining`.
3. Plan-ID matcher fast-path (HEALTHKIT.md § 12.0) routes through `PlanService.completeFromWatch(...)`. The resulting `Workout` has `workoutType = "Strength Training"` (matches the originating `ScheduledWorkout`) and `healthKitActivityType = "Traditional Strength Training"` (friendly display string from the inbound table).
4. The user sees the resulting workout in FitNavi labeled "Traditional Strength Training" — accurate and consistent with how Apple's Fitness app labels the same session.

### Out of Scope: Cardio / Yoga / Pilates / Other

Today, only Strength Training and HIIT can be scheduled (templates only support those two `workoutType`s — see PRD.md § Data Model → WorkoutTemplate). The other FortiFit categories (Cardio, Yoga, Pilates, Other) have no scheduling path, so no outbound mapping entry is needed for them.

### No Per-Template Override (MVP)

A `WorkoutTemplate.appleHealthSubtype: HKWorkoutActivityType?` field could let users specify Functional vs Traditional Strength Training per template. Out of scope for Phase 8.7. Reasons:

- Power-user feature — 95%+ of users won't need it.
- Adds UI surface area (where does the picker live?).
- The misclassification cost is low — Apple's Fitness app and Activity rings count both subtypes equivalently for Move/Exercise.

If user feedback later shows the Functional crowd needs this, add it as a small Phase X polish.

### Changing the Outbound Mapping

Edit the table above, then verify the FortiFit-to-HK outbound mapping unit test in `FortiFitTests` still passes (the test iterates every supported FortiFit `workoutType` and asserts the expected outbound `HKWorkoutActivityType` — see TESTING.md § WorkoutKit Test Strategy).
