/// Growth stages for the Tasks streak. The longer the care streak, the further
/// the plant grows. Derived purely from `Streak.currentStreak` — no backend
/// data.
///
/// [image] is the base filename in `assets/plant_stages/`. The renderer prefers
/// `<image>.png` if present, else falls back to `<image>.svg` — so you can drop
/// your own AI-generated `seedling.png` (etc.) into that folder to replace the
/// bundled illustration with no code changes.
class PlantStage {
  final String name;
  final int minDays; // streak days required to reach this stage
  final String image; // base filename (no extension) under assets/plant_stages/
  final double size; // display size — grows a little each stage

  const PlantStage({
    required this.name,
    required this.minDays,
    required this.image,
    required this.size,
  });

  static const List<PlantStage> all = [
    PlantStage(name: 'Seed', minDays: 0, image: 'seed', size: 100),
    PlantStage(name: 'Sprout', minDays: 1, image: 'sprout', size: 108),
    PlantStage(name: 'Seedling', minDays: 3, image: 'seedling', size: 116),
    PlantStage(name: 'Young', minDays: 7, image: 'young', size: 124),
    PlantStage(name: 'Leafy', minDays: 14, image: 'leafy', size: 130),
    PlantStage(name: 'Budding', minDays: 21, image: 'budding', size: 130),
    PlantStage(name: 'Bloom', minDays: 30, image: 'bloom', size: 132),
  ];

  /// The current stage for a streak length.
  static PlantStage forStreak(int streak) {
    var result = all.first;
    for (final s in all) {
      if (streak >= s.minDays) result = s;
    }
    return result;
  }

  /// The next stage up, or null if already at the top.
  static PlantStage? next(PlantStage current) {
    final i = all.indexOf(current);
    return (i >= 0 && i < all.length - 1) ? all[i + 1] : null;
  }
}
