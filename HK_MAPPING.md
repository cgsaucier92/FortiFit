# HK_MAPPING.md: HealthKit → FitNavi Workout Type Mapping

> Static lookup table mapping every `HKWorkoutActivityType` enum case to a FortiFit `workoutType` plus a friendly display string (stored on `Workout.healthKitActivityType`). Consumed by `HealthKitSyncService` at import time. Architectural rationale lives in HEALTHKIT.md § 6.

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
