# Plant growth stage assets

These images are the streak plant on the Tasks page. One per growth stage,
chosen by the current streak length (see `lib/models/plant_stage.dart`):

| File        | Stage        | Reached at |
|-------------|--------------|------------|
| `seed`      | Seed         | 0 days     |
| `sprout`    | Sprout       | 1 day      |
| `seedling`  | Seedling     | 3 days     |
| `young`     | Young plant  | 7 days     |
| `leafy`     | Leafy plant  | 14 days    |
| `bloom`     | Blooming     | 30 days    |

## Replacing with your own art (e.g. AI-generated)

Drop a file named `<stage>.png` (e.g. `seedling.png`) into this folder. The app
prefers a `.png` over the bundled `.svg` automatically — no code changes needed
(this folder is already declared in `pubspec.yaml`). Just `flutter pub get` /
hot-restart.

For the stages to line up nicely, generate each with:
- a **square** canvas and **transparent** background,
- the **same art style** across all six,
- the plant **centered** with a **consistent baseline + scale** (so it appears to
  grow between stages),
- ~512–1024px.

To tweak the day thresholds or display sizes, edit `PlantStage.all` in
`lib/models/plant_stage.dart`.

## Current bundled art

The bundled `.svg` files are **original art** for this project ("Sprouty", a cute
sprout creature) — no third-party attribution required. They use the app palette
and follow two conventions the code relies on:

- **Canvas + baseline:** each is authored on `viewBox="0 0 100 100"`, horizontally
  centred at `x=50`, with the creature's base (soil mound) at `y≈91`. Keeping the
  baseline + centre consistent is what makes the stages appear to grow in place.
- **Eyes for the blink:** the dot-eyed stages (`sprout`, `seedling`, `young`,
  `leafy`) have eyes symmetric about `x=50`. Their positions are mirrored in
  `_eyeGeometry` in `lib/screens/tasks/tasks_screen.dart`, which overlays an
  animated eyelid to blink. If you move the eyes, update those fractions to match.
  `seed` (sleeping) and `bloom` (`^^` eyes) intentionally don't blink.
