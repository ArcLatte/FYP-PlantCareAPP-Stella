# Weather scene assets (watercolor)

Hand-authored watercolor-style SVGs used by the home header weather scene
(`lib/widgets/weather_scene_art.dart`). Everything is layered translucent
organic shapes plus Gaussian-blur bleed — no `feTurbulence`/displacement, so
they render reliably under `flutter_svg`.

| File | Role |
| --- | --- |
| `sky_dawn.svg` / `sky_day.svg` / `sky_rain.svg` / `sky_sunset.svg` / `sky_night.svg` | Full-bleed sky wash, picked by local time of day and weather condition. Drawn with `BoxFit.cover`. |
| `sun.svg` | Daytime sun — layered amber washes + halo. Top-right. |
| `moon.svg` | Night crescent moon + soft craters and glow. Top-right. |
| `stars.svg` | Star field overlay for night/cloudy-night scenes. |
| `cloud_soft.svg` | Light fair-weather cloud. |
| `cloud_big.svg` | Larger cloud bank. |
| `cloud_grey.svg` | Grey rain/storm cloud. |
| `rain.svg` | Diagonal rain streak texture (tiled across the section). |
| `snow.svg` | Soft snow dots texture (tiled across the section). |

Scene selection mirrors the OpenWeather icon code (`01d`, `10n`, …): the first
two chars choose the condition, the `d`/`n` suffix and local hour choose the
sky + sun/moon. Clouds drift via an `AnimationController` in the widget.

The old fully code-drawn backdrop is kept at `lib/widgets/weather_backdrop.dart`
in case a revert is wanted.

## Using your own art

`_sceneAsset` in `weather_scene_art.dart` picks the loader by file extension, so
you can replace any of these with your own images (e.g. AI-generated PNGs):

1. Drop your file into this folder (`assets/weather/`).
2. **Same name + `.svg`** → nothing else to do; it just loads.
   **Different format** (`.png` / `.jpg` / `.webp`) → open the `_A` block at the
   bottom of `weather_scene_art.dart` and change that one entry's extension,
   e.g. `static const sun = 'sun.png';`.
3. `flutter run` (or hot-restart). A brand-new file in this already-registered
   folder needs no pubspec change.

Suggested source dimensions: skies ~720×520 (drawn `cover`, so any landscape
ratio works), sun/moon ~280×280 (transparent background), clouds ~440×240
(transparent), rain/snow as 120×120 seamlessly-tiling tiles (transparent).
Use transparent PNGs for everything except the skies so layers composite cleanly.
