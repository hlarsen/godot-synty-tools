# Godot Synty Tools

This is a Godot addon to streamline working with Synty assets. This addon came out of messing around with the assets in
Godot and Blender and wanting to learn more about the files, how they're structured, and they are used together.

No assets are included in this repo.

## Usage

Install the addon to `addons` as normal and enable it in `Project > Project Settings > Plugins`. You should now be able
to launch the addon at `Project > Tools > Godot Synty Tools`.

Make sure the Output tab is selected so you can see the script output.

## Features

For a given pack, the addon scans and processes the FBX files for easier use in Godot.

- `Base Locomotion`: Create animations and animation libraries properly mapped to Godot's SkeletonHumanoid3D
- `Sci-Fi City`: Split characters into individuals, fix materials, import as cleaned up scenes

See `doc/synty_pack_details.md` for more details and notes.

## Feedback and Future Work

Please reach out to me at `@hlarsen` on the [Synty Discord](https://discord.com/invite/syntystudios) if you:

- want me to prioritize adding a specific pack by gifting me a license
- have suggestions on the output of this addon (scene hierarchy, etc.)
- want to talk about custom tooling development for Godot

Please file issues on GitHub for any errors or problems.

## Notes

I am not a 3D modeler or game developer, so if I'm doing anything obviously wrong please feel free to let me know. I've
been talking with Claude and ChatGPT to help learn the 3D space, but honestly pretty much all the code it produced was
rewritten because it was not great. I'm pretty anti-LLM, but having an "interactive" docs search works well with Godot
because the docs are pretty good and contain a ton of _concepts_, but you can also double-check any suspected
hallucinations in the source!

My repo of [Blender Scripts](https://github.com/hlarsen/game-asset-blender-scripts) may be useful - it has code around
meshes, bones, materials, and other stuff like that.

## License

MIT, but if your commercial project does well please consider making a donation or gifting some packs, which will
be added to the addon =)
