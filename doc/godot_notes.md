# Godot Notes

These are some notes on how I understand things, I could definitely be wrong so let me know if so.

Please excuse the code, some of it may be... [inelegant](https://frinkiac.com/meme/S03E11/754786.jpg).

## Approaches

The below notes are for my initial import > update .import > reimport approach. It wasn't great, and after much
research and testing I found it much easier to process the files with a combination of:

- Pre-processing of files via script in this addon (as needed)
- Generating partial `.import` files _before_ copying to the file system
- Post Import scripts that run after Godot imports the files

This approach is less error prone and a lot faster. See the `import_generators` and `post_import_scripts` directories
for more info.

## File Scanning vs Importing

Scanning refers to the engine _scanning the filesystem_ - it is async, but it does _not_ take a long time.

Importing is the actual process of the engine parsing the file and creating a .import file if the import is successful.
This is also async, but it can take a long time.

Godot complains if you scan or re-import while another one is going on, so you want to use `if not is_scanning():` for
scans. For re-importing I *think* it only complains if you try re-importing a file that is already queued for re-import,
but I could be wrong.

### How do I know a scan is done?

You can check this repo for ugly code like this:

```gdscript
	var efs: EditorFileSystem = plugin.get_editor_interface().get_resource_filesystem()
	if not efs.is_scanning():
		efs.scan()

	await plugin.get_tree().process_frame
	while efs.is_scanning():
		print("FS is scanning, waiting 1 second")
		await plugin.get_tree().create_timer(1).timeout
	print("FS no longer scaning")
```

I've read that `await plugin.get_tree().process_frame` "forces all queued signals to fire" or something like that,
separately if it's scanning we're just waiting a second. This feels ok, thought I'm open to a better solution, and as
mentioned this is very fast.

### How do I know an import/re-import is done?

The `resources_reimported` signal passes back a list of files that have been reimported, so if you know what you're
importing you can check if they have been imported. See the ugly code below.

One quirk is if an import fails, it won't have an .import file created and the signal won't report it!

I wasn't able to reliabily call `reimport_resources()`, so I fell back to scanning. I think because I was updating a
bunch of .import files the engine would maybe lose some files in the `resources_reimported` signal or something. Might
still be a race condition in my code in `base_locomotion_export_menu.gd`.

```gdscript
func scan_and_wait_for_signal(efs: EditorFileSystem, file_paths: Array[String], timeout_seconds: float = IMPORT_WAIT_TIMEOUT) -> bool:
	print("Waiting up to " + str(timeout_seconds) + " seconds for reimport of %d files" % file_paths.size())

	var files_to_wait: Array = file_paths.duplicate()
	var start_time: int = Time.get_ticks_msec()

	# connect signal handler BEFORE triggering reimport
	var on_reimport = func(resources: PackedStringArray):
#		print_debug("Resources reimported signal received with %d files" % resources.size())

		# check for reimported files
		for i in range(files_to_wait.size() - 1, -1, -1):  # Iterate backwards so we can remove
			if files_to_wait[i] in resources:
#				print_debug("Reimported: " + files_to_wait[i])
				files_to_wait.remove_at(i)

	efs.resources_reimported.connect(on_reimport)

	if not efs.is_scanning():
		efs.scan()

	await plugin.get_tree().process_frame
	while efs.is_scanning():
		print("FS is scanning, waiting .2 seconds")
		await plugin.get_tree().create_timer(.2).timeout
	print("FS is finished scanning, waiting for import to finish...")

	# wait until all files are reimported or timeout
	while files_to_wait.size() > 0:
		var elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0

		if elapsed > timeout_seconds:
			push_error("Reimport timeout after %.1f seconds. Still waiting for:" % elapsed)
			for file in files_to_wait:
				push_error("  - " + file)
			efs.resources_reimported.disconnect(on_reimport)
			return false

#		print("Still waiting for %d files (%.1fs elapsed)" % [files_to_wait.size(), elapsed])
		await plugin.get_tree().create_timer(0.2).timeout

	# disconnect from the signal
	efs.resources_reimported.disconnect(on_reimport)

	print("All files successfully reimported")
	return true
```
