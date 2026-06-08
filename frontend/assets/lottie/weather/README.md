# Weather animations (Lottie)

Drop Lottie JSON files here with these exact names. They map from the
OpenWeather icon code via `Weather.animationAsset` (see
`lib/services/weather_service.dart`). Until a file is present, the header
falls back to the matching Material icon — nothing breaks.

| File | Weather (OpenWeather group) |
|------|------------------------------|
| `sunny.json`               | Clear sky, day (01d) |
| `clear_night.json`         | Clear sky, night (01n) |
| `partly_cloudy.json`       | Few/scattered clouds, day (02d) |
| `partly_cloudy_night.json` | Few/scattered clouds, night (02n) |
| `cloudy.json`              | Broken/overcast clouds (03, 04) |
| `rain.json`                | Drizzle & rain (09, 10) |
| `thunder.json`             | Thunderstorm (11) |
| `snow.json`                | Snow (13) |
| `fog.json`                 | Mist/fog/haze (50) |

## Where to get them (free)

- https://lottiefiles.com/ — search "weather sunny", "rain", etc. Filter by
  Free license. Download as **Lottie JSON** (not .lottie/.zip).
- Keep them small/simple (looping) for performance.

Rename each download to the filename above and place it in this folder.
After adding files, run `flutter pub get` (if you haven't) and hot-restart.
