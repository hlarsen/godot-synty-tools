# Synty Pack Details

This is a quick summary of what processing is happening for each pack. If you're interested in
the details you can review the import generator and post import script for the pack; I like to
keep my code as KISS as possible so it should be fairly easy to read.

Anything listed will be in the import generator unless marked post import. "Cleaned up imported
object heriarchy" means the node tree was modified for what the average tutorial suggests, but
you can easily adjust the post import script to set up the objects however you prefer.

## Base Locomotion

We process both Polygon and Sidekick animations, though since we use BoneMaps they should be
interchangeable. I only have the Sidekick test char so I haven't looked further into it; there
are more bones but I'm not sure if they are used.

- Extracts T-Pose from Neutral T-Pose animation
- Generates .import files for the animations specifying the T-Pose as reset
- Create animation libraries (before the .res files are created)
- Create animation resource files referenced by the libraries (post import)

## Sci-Fi City

Most FX_ files are currently not processed.

- Characters.fbx
 - Split into separate files
 - Clean up imported object heirarchy (post import)
- SM_*.fbx:
 - Clean up imported object heirarchy (post import)
- Fix materials where possible
- Create scenes
