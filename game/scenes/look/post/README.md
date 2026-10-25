# look/post

What: full screen post effects over the 3D view, each a CanvasLayer below the HUD (`layer = -1`) with a ColorRect and its shader. `psx_screen.tscn`: PS1 look (low resolution, 15 bit color, 4x4 ordered dither).
Not: effects that need depth (fog by distance, outlines): those go in the Camera's `compositor`. Not the camera shake (scenes/camera/camera_shake).
Talks to: nothing; it reads the screen. `match.tscn` instances it as `PostFx`.
Edit: select `PostFx/Screen` in `match.tscn`, Material: `virtual_height`, `color_levels`, `dither_amount`, `strength`; toggle `PostFx` visible to try it.
