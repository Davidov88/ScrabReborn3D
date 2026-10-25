# SCRAP REBORN 3D — development build 0.1.2

This is an unfinished development build. It does not satisfy the full first-version acceptance contract yet.

## Additional 0.1.2 changes

- Anatomical slot selection, compatible inventory filtering, actual reference images, brief descriptions and before/after component statistics. One-click installation without confirmation, exact-instance undo while the workshop is open, explicit power/load warnings.
- Human-readable descriptions for programs and active hardware bonuses.
- Exactly one enemy in the first sector, including migration of old sector records. Actor collisions and separation prevent body overlap.
- Larger impact sparks with short contact-light flashes. Basic manipulators perform melee attacks without a false projectile beam.
- More ceiling fixtures and a low-light screen program on N. The additional program consumes 1 CPU and 0.5 energy/sec; the 24 original programs remain available.
- Workshop regression verifies direct installation, exact undo, vision resource use, one enemy and separation of two ground opponents.

## User-reported regressions addressed, 2026-10-24

- Camera switching uses the triggering key event rather than the global just-pressed state on every input event. Twelve consecutive switches with interleaved mouse events pass. V cycles third person, overhead, first person.
- Mouse motion is handled before GUI propagation. Both shoulder and first-person camera rotation are tested beneath a physical canopy. Mouse capture changes only when its mode actually changes.
- Actor state is deep-copied on creation. Replacing the player's arm is verified to leave enemy state and enemy mesh nodes unchanged. The original reported simultaneous visual replacement has not been reproduced in this revision.
- Upper arm and forearm animate separately; thigh and shin animate separately. Knee flexion is corrected. Each hand has its own attack timer. Melee opponents no longer hold both arms in a permanent aiming pose. Arm collision volumes follow both articulated segments.
- The exposed torso compartment remains physically hittable; centre hits reach the actual installed power cell. First supply gives a light pistol and automatically equips it. An actual muzzle-ray encounter disables the first domestic enemy in seven shots and leaves salvageable equipment.
- Visible ceiling fixture housings and diffusers carry downward SpotLight3D sources with shadows and distance limits. The global directional light was removed. Floor sections accommodate Compatibility's per-object light limit.
- Corrected imported prop bounds using full nested transforms, fixing oversized maintenance equipment.
- Revised all 42 GLBs with tapered shells, rounded helmet carapaces, rib and abdomen segmentation, concentric bearings, exposed actuators, and painted surfaces. This is an art iteration, not approval of reference fidelity.
- Reworked menu composition, workshop preview and component cards; added player component-condition indicators and readable HUD backing.

## Verification

- Simulation suite: 247 checks passed, including hardware capacity, broken-controller behavior and extraction preservation.
- Player journey: movement, 12 repeated V switches, first-person position, mouse rotation under canopy, supply interaction, physical sensor hit, wall blocking, workshop access passed.
- Visual regression: equipment isolation, shoulder/elbow motion and independent attack timers passed.
- Combat regression: seven physical shots with active enemy AI, player survival, real battery identity and arm salvage passed.
- Native screenshots inspected for menu, three cameras and workshop. Lighting and prop-scale issues found during review were corrected.
- Windows 0.1.2 native regression passed: actual exported/rendered execution, camera/input, live muzzle-ray combat, slot installation without confirmation, undo, low-light activation and independent save/load. The report uses runtime checks rather than release-disabled assertions.
- Exported campaign integration passed all five sectors and completion/save/reload. Later encounters use direct damage operations, so this is not an ordinary playthrough.
- Short 1920×1080 benchmark after limiting shadow-casting fixtures: 32.5–60.1 FPS over five sectors and three modes. One-hour stability remains unverified. Reports: test-results/export-regression.json, benchmark-1600.json, exported-acceptance.json.

## Remaining release gates

- Models need further reference-by-reference art refinement and inspection of mixed assemblies. Procedural geometry does not yet reach the approved detailed industrial references.
- Animation currently covers articulated locomotion, aiming, attacks and damage/deactivation. Full reload, dodge, parry and variant-specific animation polish remains.
- Sector layouts need authored spatial variety, cover and investigation pacing. The intended 60–90-minute playtime is unverified.
- Full ordinary-player balance across all enemies, weapons and software needs playtesting. An automated opening encounter is not a full balance verdict.
- The campaign integration runner uses direct damage operations for later encounters. It does not count as a manual playthrough.
- A complete one-hour stability run has not passed. Earlier partial runs were interrupted.
- Final visual approval, complete exported playthrough and hour-long performance/stability verification remain required. Do not call this release complete.
