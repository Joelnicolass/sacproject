# look/post

Full-screen post effects over the 3D view, each a `CanvasLayer` with a `ColorRect` and its shader (`psx_screen.tscn`,
instanced in `match.tscn` as `PostFx`). Effects that need depth (distance fog, outlines) go in the camera's `compositor`.
