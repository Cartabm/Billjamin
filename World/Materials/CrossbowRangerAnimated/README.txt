CROSSBOW RANGER - GODOT 4

This is a procedural rigid-part animation setup, NOT a true skeletal rig.
It retains the original textured GLB model. Since the source model has separate
mesh pieces, legs, arms, cloak and crossbow can move with simple pivot animation.
The weapon placement is unchanged except for recoil/bob; its original chest
intersection may still require a revised mesh or dedicated hand attachment.

INSTALL:
1. Extract the CrossbowRangerAnimated folder into your Godot project root.
2. Let Godot import the GLB.
3. In your Player scene, hide your current Billjamin_Crossbow_Ranger node.
4. Drag CrossbowRangerAnimated.tscn into Player as a new child.
5. Run the game; idle animation will work by default.
6. To drive walking from player.gd, use:
   $CrossbowRangerAnimated.set_movement(clampf(velocity.length() / move_speed, 0.0, 1.0))
   Put that in _physics_process AFTER velocity is updated.
7. After firing a projectile, use:
   $CrossbowRangerAnimated.fire()
8. When reloading, use:
   $CrossbowRangerAnimated.reload()

If the original GLB import uses a nested transform, part grouping may need adjustment.
This package does not provide true bone skinning, foot IK, or authored animations.
