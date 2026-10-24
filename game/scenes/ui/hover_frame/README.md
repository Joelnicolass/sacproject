# ui/hover_frame

Los cuatro rincones que rodean la unidad, el edificio o el alma bajo el puntero, con el color de su bando (almas: azul propia, roja ajena).
- `hover_frame.tscn` es un hijo de `Hud`; lee `TargetProbe.hovered` y proyecta la caja del cuerpo con la cámara activa.
- `hover_frame_rules.gd`: estático, decide si hay marco, su rectángulo (mínimo 48x48 px) y su color. Lo prueba `debug/suite/hover_frame_cases.gd`.
- No aparece sobre cadáveres, cielo, suelo ni HUD, ni durante un arrastre; los edificios, con un icono armado o en reposo (`buildings_idle`).
- Aspecto en el inspector: grosor, largo de esquina, tamaño mínimo, relleno, colores de alma. La caja con el nombre es `target_info/`.
- Solo presentación local: nada de la simulación lo lee.
- Agregar uno nuevo: ponerlo bajo `Hud` y asignar `probe`.
