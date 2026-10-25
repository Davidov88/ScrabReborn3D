# Asset decisions

Workshop uses supplied reference PNGs and the already registered Kenney/Godot UI resources. The anatomical assembly interaction and comparison logic are project code.

For low-light vision, searched Godot Shaders and the public repository https://github.com/robertcorponoi/godot-night-vision-screen-shaders . The repository warns that its Shadertoy ports have uncertain individual licenses; none of that shader code was imported. Implemented a small original luminance/gamma pass using Godot's documented screen-texture API: https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html . It amplifies existing scene light rather than emitting invisible world light or revealing occluded geometry.

Sparks adapt the existing project CPU-particle effect and registered Godot demo reference approach. Visible fixtures use the existing industrial architecture materials and project geometry.

Controller bonuses shown by the UI now affect simulation. Canonical LOAD1 +15 kg, LOAD3 +35 kg, Servo Sync +5 accuracy, Recoil-X +8 accuracy, evasion +8, shield +15 and network +20 are adapted to physical combat. Random evasion becomes dash strength. Compatibility becomes an additional load allowance. Legacy controllers lacking numeric effects receive explicit 3D values in ScrapCatalog.HARDWARE: Move-1 +4 mobility, Balance-2 +12 stability, GripSoft preserves 3% extraction durability, EcoRun reduces movement drain by 20%, SyncCore +25 kg. Damaged hardware scales bonuses using the same condition thresholds as other parts.
