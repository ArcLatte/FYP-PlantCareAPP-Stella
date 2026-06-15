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

The bundled `.svg` files are from **OpenMoji** (https://openmoji.org),
licensed **CC BY-SA 4.0**. If you ship the app with these, include OpenMoji
attribution. Replacing them with your own art removes that requirement.
