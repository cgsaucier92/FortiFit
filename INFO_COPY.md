# INFO_COPY.md: See Info Modal — User-Facing Copy

> User-facing strings for the Chart Info Modal (Trends → long-press chart → "See Info") and the Widget Info Modal (Home → long-press widget → "See Info"). Both surfaces share the See Info Modal component (SCREENS.md § Standard Patterns → See Info Modal).
>
> Stored in `AppConstants` as static dictionaries keyed by `chartType` and `widgetType` respectively. Never hardcoded in views. Sections render top-to-bottom in the order listed.

---

## Chart Info Modal Copy

One entry per chart type. Each entry: title + intro paragraph + ordered list of named sections (heading + body).

### Strength Tracker (`strengthTracker`)

**Title:** About Strength Tracker

**Intro:** Strength Tracker shows how the heaviest weight you lift for a single exercise changes over time. Pick an exercise from the dropdown to see how your top set has trended in recent sessions.

**How it's calculated:** Each data point on the chart is the heaviest weight you lifted for the selected exercise on that date, taken from the top set across all of that day's matching workouts. If you trained the same exercise twice in one day, only the heavier of the two sets is plotted.

**Time range:** Toggle 30, 60, or 90 days to widen or narrow the view. The chart re-renders immediately on switch.

**What's tracked:** Only sets with a recorded weight count toward the trend. Bodyweight exercises (logged without a weight value) aren't included — they don't have a number to plot. Exercise names are matched case-insensitively, so "Bench Press" and "bench press" share the same line.

**Empty state:** At least 2 workouts containing the selected exercise with a recorded weight are needed before the chart can render. Until then, you'll see a prompt to log more sessions.

### Training Frequency (`trainingFrequency`)

**Title:** About Training Frequency

**Intro:** Training Frequency shows how many workouts you've completed each week over the last 8 weeks, side by side with your weekly target.

**How it's calculated:** Each bar is the count of workouts whose date falls within that calendar week (Monday 12:00 AM through Sunday 11:59 PM). Every workout type counts equally — a yoga session and a strength session each add one to the bar for that week.

**Your target line:** The dashed blue line is your target workouts per week, set on the Weekly Streak widget via long-press → Configure Settings. Bars at or above the line mean you hit your target that week; bars below it mean you didn't.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week. Older weeks roll off as new ones begin.

**Empty state:** You need at least one full Monday–Sunday week with at least one logged workout before the chart renders.

### Personal Records (`personalRecords`)

**Title:** About Personal Records

**Intro:** Personal Records compares your most recent PR for an exercise against the PR before it, so you can see how much you improved on your latest breakthrough.

**What counts as a PR:** A PR is recorded the first time you exceed your previous heaviest weight for a given exercise. The very first time you log an exercise establishes your baseline — that workout isn't a PR by itself. Every subsequent workout that beats your highest weight to date logs a new PR event.

**How records are tracked:** PR events are calculated per exercise name (case-insensitive) and ordered chronologically by workout date. If you log the same exercise on multiple days at the same weight, no new PR is logged — the weight has to exceed the previous record. Bodyweight exercises (logged without a weight) aren't tracked because there's no number to compare.

**What you'll see:** The dropdown lists every exercise that has at least one PR event, sorted alphabetically. Selecting an exercise shows two bars: your previous record on the left and your most recent record on the right, with the date each was set.

**Empty state:** At least one exercise needs at least one PR event before the chart renders. If you've only ever lifted the same weight on a given exercise, no PR exists yet.

### Training Load Trend (`trainingLoadTrend`)

**Title:** About Training Load Trend

**Intro:** Training Load Trend plots your daily training load score over the last 14 days, color-coded by zone, so you can spot overtraining patterns and recovery windows at a glance.

**How training load is calculated:** Each day's score is a 0–100 rating that combines the volume, intensity, and recency of your recent workouts. Recent sessions count more than older ones — stress decays over about 10 days. Your experience level (set via long-press → Configure Settings on the Training Load widget) affects how quickly stress decays and how much load you can absorb before the score climbs.

**Zones:** Each dot is colored by its zone:
- Low (1–30, green): well recovered
- Moderate (31–55, yellow): some accumulated fatigue
- High (56–80, dark yellow): significant fatigue
- Peak (81–100, red): high stress, prioritize recovery

**The 7-day average line:** The dashed blue line is your 7-day rolling average, smoothing out single-day spikes so you can see the underlying trend. A rising line over a flat dot pattern means your overall load is climbing; a falling line means you're tapering.

**Empty state:** At least 3 days with at least one workout each in the last 14 days are needed before the chart renders.

### Workout Volume (`workoutVolume`)

**Title:** About Workout Volume

**Intro:** Workout Volume tracks the total weight you've moved per session over time. Each data point is one workout — together they show whether you're progressively overloading.

**How volume is calculated:** For every set in a workout, volume is `sets × reps × weight`. Those values are summed across all exercises in the session to produce a single workout volume number. Bodyweight exercises (logged without a weight) count as if the weight were 1, since they still represent work performed.

**What's included:** Only Strength Training and HIIT workouts appear on the chart. Cardio, yoga, pilates, and other types don't track exercise sets the same way, so including them would distort the trend.

**Time range:** Toggle 30, 60, or 90 days. The chart re-renders immediately on switch.

**Empty state:** At least 2 Strength Training or HIIT workouts with at least one logged exercise set are needed before the chart renders.

### Effort Trend (`rpeTrend`)

**Title:** About Effort Trend

**Intro:** Effort Trend shows your average perceived effort per week, so you can see whether your training intensity is creeping up, holding steady, or trending down.

**How it's calculated:** Effort uses a 1–10 scale where 1 is barely a warm-up and 10 is an all-out max effort. Each bar is the average of every effort rating you logged within that calendar week (Monday through Sunday). Workouts you didn't rate aren't counted — they don't pull the average up or down.

**The reference line:** The dashed line at Effort 7 marks the rough threshold between hard and very hard sessions. Several weeks averaging well above 7 in a row may signal it's time for a deload.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week.

**Apple Health import:** If you record a workout on Apple Watch and rate its effort there (iOS 18 or later), that effort score imports into FitNavi automatically when the workout is linked — but only if you haven't already entered an effort rating yourself. Your manually entered ratings always win.

**Empty state:** At least one full Monday–Sunday week with at least one workout that has a recorded effort rating is needed before the chart renders.

### Workout Type Breakdown (`workoutTypeBreakdown`)

**Title:** About Workout Type Breakdown

**Intro:** Workout Type Breakdown shows how your training is distributed across workout types, so you can see whether your routine is balanced or concentrated in one area.

**How it's calculated:** Each segment of the donut is the count of workouts of that type within the selected time range, divided by your total workout count. A 50% Strength Training slice means half of all your sessions in the period were Strength Training.

**Workout types:** Six categories — Strength Training, HIIT, Cardio, Yoga, Pilates, and Other. Each has a fixed color shown in the legend. Workouts imported from Apple Health are mapped to one of these six based on their HealthKit activity type.

**Time range:** Toggle 30 days, 60 days, 90 days, or All Time. "All Time" includes every workout you've ever logged.

**Empty state:** At least 2 workouts of any type are needed before the chart renders.

### Session Duration (`sessionDuration`)

**Title:** About Session Duration

**Intro:** Session Duration shows how long your workouts have been on average each week, so you can manage your time and pacing.

**How it's calculated:** Each bar is the average duration in minutes of all logged workouts within that calendar week (Monday through Sunday). Workouts you didn't enter a duration for aren't counted — they don't have a number to average.

**The target line:** The dashed line is your target workout duration, set via long-press → Configure Settings on the Training Load widget. It's the same value FitNavi uses as a fallback in your training load score when a workout has no duration entered.

**Time range:** The 8 most recent calendar weeks, including the current in-progress week.

**Apple Health import:** Durations from Apple Watch and other Health-connected apps are imported automatically when you link a workout, so you don't need to re-enter them.

**Empty state:** At least one full Monday–Sunday week with at least one workout that has a recorded duration is needed before the chart renders.

---

## Widget Info Modal Copy

One entry per "See Info"-eligible widget (Training Load, Power Level, Activity Rings). Same structure as Chart Info Modal Copy. Stored as a static dictionary keyed by `widgetType`.

### Training Load (`trainingLoad`)

**Title:** About Training Load

**Intro:** Training Load is a 0–100 score that summarizes how much training stress you've accumulated over the past 10 days. The zone label and advisory beneath it suggest whether to push, ease off, or rest today.

**How it's calculated:** Each workout you've logged in the last 10 days contributes a stress value based on your Effort rating for that session, how long it lasted, the workout type, and the volume you put in (sets × reps for Strength and HIIT). Recent sessions count more than older ones — stress decays over about 10 days.

**Your experience level:** Set via long-press → Configure Settings on the widget. Beginner, Intermediate, and Advanced each have a different recovery rate and stress capacity. Higher experience means stress decays faster and you can absorb more training before the score climbs into peak territory.

**Consecutive training days:** Stacking training days back-to-back adds a small multiplier to your score, up to 32% extra at five or more consecutive days. Take a rest day and the multiplier resets.

**Same-day floor:** If you've already trained today, the score won't drop low enough to suggest "train hard" — there's a built-in floor based on what you logged today that lifts on its own tomorrow.

**Zones:**
- Low (1–30, green): well recovered
- Moderate (31–55, yellow): some accumulated fatigue
- High (56–80, dark yellow): significant fatigue
- Peak (81–100, red): high stress, prioritize recovery

**What's not counted:** Workouts logged with no exercises, no Effort rating, and no duration are skipped — they're treated as placeholder entries with no meaningful stress to add.

**Empty state:** If you haven't logged a workout in the last 10 days, the score sits at 0 (Resting) and the advisory shows "No recent training stress."

### Power Level (`powerLevel`)

**Title:** About Power Level

**Intro:** Power Level shows whether your strength training volume is rising, holding steady, or trending down compared to where you were a month ago. It answers "am I progressing?" at a glance.

**How it's calculated:** FitNavi averages your workout volume across the last 30 days and compares it to your average across the prior 30 days. Volume per workout is sets × reps × weight, summed across every exercise in the session.

**What workouts count:** Only Strength Training and HIIT workouts. Cardio, yoga, pilates, and other types don't track exercise sets, so they don't contribute to a volume comparison.

**Bodyweight exercises:** Sets logged without a weight value count as if the weight were 1, since they still represent work performed. This keeps bodyweight volume from disappearing entirely from the comparison.

**Status thresholds:**
- Rising (↑, green): current 30-day average is more than 10% higher than the prior 30 days
- Steady (—, blue): within 10% in either direction — your volume is holding consistent
- Deloading (↓, red): current 30-day average is more than 10% lower than the prior 30 days

**Empty state:** If you don't have any Strength Training or HIIT workouts logged, the widget shows a prompt to start logging. If you have current workouts but no prior 30-day baseline yet (less than 31 days of history), the status defaults to Steady until you build enough data.

### Activity Rings (`appleActivity`)

**Title:** About Activity Rings

**Intro:** Activity Rings shows your daily Move, Exercise, and Stand progress pulled live from Apple Health, measured against goals you set in FitNavi. It's the same three-ring view you see on Apple Watch, brought into FitNavi so you can keep your activity tracking and your strength tracking in one place.

**The three rings:**
- **Move** (red): active calories burned today. Counts movement of any kind — walks, workouts, fidgeting at your desk. Goal default is 500 cal; you can set it 1–2000 in 10-cal increments.
- **Exercise** (green): minutes of brisk activity today. The Watch decides what counts based on heart rate and motion. Goal default is 30 min; you can set it 1–240 in 5-min increments.
- **Stand** (blue): hours where you stood and moved for at least one minute. Goal default is 12 hours; you can set it 1–24 in 1-hr increments.

**How goals are set:** When you first add the widget, FitNavi imports the goals you've already set in Apple Health. After that, your FitNavi goals are independent — change them in Configure Settings, or use the "Import from Apple Health" button to re-sync if you change them on your watch later.

**Workout contribution:** Below each ring's value, you'll see how much of today's progress came from a workout you logged in FitNavi (only workouts linked to Apple Watch contribute — manually-logged workouts that aren't HK-linked won't show up here, since their data isn't in HealthKit).

**Weekly closure rate:** The chip below the rings tells you how many days this week you closed all three rings — a quick read on your week-over-week consistency.

**Tap the widget** to open a detailed breakdown with sparklines and a calendar heatmap of which days you closed your rings (toggle between 7-day and 30-day views).

**Requirements:** You'll need an Apple Watch and Apple Health enabled in FitNavi Settings. If either is missing, the widget shows a message explaining what to do next.
