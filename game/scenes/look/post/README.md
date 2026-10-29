# look/post

Full-screen post effects over the 3D view, each a `CanvasLayer` with a `ColorRect` and its shader: `psx_screen.tscn`
(the PS1 look, instanced in `match.tscn` as `PostFx`, hidden) and `lens_screen.tscn` (vignette and chromatic aberration,
`LensFx`; a `BackBufferCopy` first, so it reads the picture after the PS1 pass). Effects that need depth (distance fog, outlines) go in the camera's `compositor`.
