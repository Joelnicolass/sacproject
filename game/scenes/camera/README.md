# camera

The world camera: presentation and camera input only.
It follows the drawn pose of the body (`DrawnPose.origin`, in `_process`) and runs at `process_priority = 15000`, after
`MpActor` (10000), which writes the pose first. `FollowCamera` nodes (rain, air life) run at 15001.
