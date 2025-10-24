# Godot Synty Tools

This is a Godot addon to streamline working with Synty assets. This addon came out of messing around with the assets in
Godot and Blender and wanting to learn more about the files, how they're structured, and they are used together.

No assets are included in this repo.

## Assets and Goals

I've been working with some Synty asset packs I have licenses for, as well as some Mixamo models and animations. Besides
getting more familiar with the file formats in general, another initial goal was to see if I could mix Mixamo and Synty
characters/animations.

I have some Blender scripts in another repo that will clean up the FBX files, fixing materials and a few other niceties.

### Features

#### Base Locomotion

The Synty Base Locomotion source files do not have a proper T-Pose Rest Pose, so adding them to characters that do have
one is an issue. Pass in your `Animations/Polygon` folder and the addon will output fixed Animation files as well as
AnimationLibraries for the main folders.

You can add use these new Resource files in the AnimationPlayer of a character who is properly mapped to Godot's
`SkeletonProfileHumanoid`.

#### Sci-Fi City

This is a work in progress, currently:

- Exports cleaned up SM_ files (TODO: should probably change default collision type)

### Feedback and Future Work

The bone map versions in `bone_maps` should match the asset pack versions. The bone maps are an indication of what
packs I have licenses for - if anyone wants to say thanks by gifting me licenses for other packs I can add those as
well ;)

If there are any issues, please let me know.

## Usage

Install the addon to `addons` as normal and enable it in Project Settings > Plugins. You should now be able to launch
the addon at `Project Settings > Tools > Godot Synty Tools`.

Make sure the Output tab is selected so you can see the script output.

## Notes

I am not a 3D modeler or game developer, so if I'm doing anything obviously wrong please feel free to let me know. I've
been talking with Claude and ChatGPT to help learn the 3D space, but there shouldn't be any blocks of weird opaque
LLM-generated code anywhere.

My repo of [Blender Scripts](https://github.com/hlarsen/game-asset-blender-scripts) may be useful, it has code around
meshes, bones, materials, and other stuff like that.

## License

MIT, but if your commercial project does well please consider making a donation =)
