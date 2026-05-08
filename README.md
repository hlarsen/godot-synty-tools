# Godot Synty Tools

This is a Godot addon to streamline working with Synty assets. This addon came out of messing around with the assets in
Godot and Blender and wanting to learn more about the files, how they're structured, and they are used together.

No assets are included in this repo.

NOTE: This is still useful for the Base Locomotion fixes, but I'd recommend using unidot
and/or [this](https://github.com/DeniedWorks/synty-godot-converter) project and using your own custom script in
Godot to reconfigure the nodes. The Unity packages have custom colliders that the source files don't, and it's
easier to review the materials and things like that.

## Usage

Install the addon to `addons` as normal and enable it in `Project > Project Settings > Plugins`. You should now be able
to launch the addon at `Project > Tools > Godot Synty Tools`.

Make sure the Output tab is selected so you can see the script output.

## Features

For a given pack, the addon scans and processes the FBX files for easier use in Godot.

- `Base Locomotion`: Create animations and animation libraries properly mapped to Godot's SkeletonHumanoid3D
- `Sci-Fi City`: Split characters into individuals, fix materials, import as cleaned up scenes

See `doc/synty_pack_details.md` for more details and notes.

### Non-Synty Stuff

This addon also supports a few other assets because I have licenses or access to them and wanted to see if I could
use them together.

- `Quaternius Universal Animation Library`: Already Godot compatible but this makes it ready for our imported Synty
  assets

## License

MIT
