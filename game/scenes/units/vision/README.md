# units/vision

A body sees who stands in its `Vision` shape; its side remembers the foes it saw for `forget_s`, and a side's sight is
the union of its bodies (`VisionSides`, the node `Context/Vision` of `match.tscn`; a scene played alone with F6
gets a loose one of its own). The AI listens to `VisionSides.events().learned`.
Everything is ordered by node name, never by physics or group order, so two runs and two peers agree.
