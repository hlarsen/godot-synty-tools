# Synty Pack Details

This is a quick summary of what processing is happening for each pack. If you're interested in the details you can
review the import generator and post import script for the pack; I like to keep my code as KISS as possible so it should
be fairly easy to read.

Anything listed will be in the import generator unless marked post import. "Cleaned up imported object hierarchy" means
the node tree was modified for what the average tutorial suggests, but you can easily adjust the post import script to
set up the objects however you prefer.

## Base Locomotion

You should be able to use the resulting animations and animation libraries with any Synty characters that have a proper
bone map and a Skeleton3D node named Skeleton3D. The original docs about this used GeneralSkeleton, so if you have a
node with that name just try changing it to see if it works. The original docs also had importing unique, which was
causing me issues, so I disabled it.

We process both Polygon and Sidekick animations, though since we use BoneMaps they should be interchangeable. I only
have the Sidekick test char, so I haven't looked further into it; there are more bones however I'm not sure if they are
used.

- Extracts T-Pose from Neutral T-Pose animation
- Generates .import files for the animations specifying the T-Pose as reset
- Create animation libraries (before the .res files are created)
- Create animation resource files referenced by the libraries (post import)

## Sci-Fi City

Not Processed:
- Skybox (likely able to be fixed, except for shaders)
- FX_ files: shaders need to be ported individually

Possible Issues:
- Some textures may be incorrect (see the importer FILE_MAP)
- Probably need to adjust collider shapes for some/all objects

- Characters.fbx
- Split into separate files
- Clean up imported object hierarchy (post import)
- SM_*.fbx:
- Clean up imported object hierarchy (post import)
- Fix materials where possible
- Create scenes

If you've already run the addon against the Base Locomotion pack and the files are in the output directory, it will
apply the Polygon Masculine library to the characters automatically.
