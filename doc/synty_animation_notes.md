# Synty Animation Notes

These are some notes on how I understand things, I could definitely be wrong so let me know if so.

## Animations and Characters

The different Synty animation packs have different bone names, so we create a BoneMap to map those bones onto Godot's
built-in (read-only) SkeletonProfileHumanoid. Same thing with Mixamo characters, most have "standard" Mixamo bone names,
some do not, but either way each individual character/armature/"set of bones" needs a BoneMap to translate it to match
SkeletonProfileHumanoid.

It's the same on the animation side, map the bones to SkeletonProfileHumanoid. The trick with the Base Locomotion pack
is the animations do not have a proper T-Pose for Rest Pose, so (according to the pinned docs) we have to (this is where
i get a bit fuzzy) extract the RESET from the T-Pose animation, then apply the offset from the T-Pose to each individual
animation so it knows where the animation bones should "start from." Does this "add the T-Pose as the rest pose to the
animations"?

Basically we have to tell Godot "this animation's bones map to these SkeletonProfileHumanoid bones" and "this
character's bones map to these SkeletonProfileHumanoid bones" and then Godot can drive everything correctly, even
without matching bones.
