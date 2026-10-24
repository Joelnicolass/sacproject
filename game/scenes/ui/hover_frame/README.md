# ui/hover_frame

El marco del original (cuatro cuñas, una por lado, que nacen opacas cerca de una esquina y se desvanecen a lo largo del lado y hacia sus bordes; sobresalen 5% del rectángulo y escalan con él; mezcla alfa normal, sin animación) que rodea la unidad, el edificio o el alma bajo el puntero, con el color de su bando (almas: azul propia, roja ajena).
- `hover_frame.tscn` es un hijo de `Hud`; lee `TargetProbe.hovered` y proyecta la caja del cuerpo con la cámara activa.
- `hover_frame_rules.gd`: estático, decide si hay marco, su rectángulo (mínimo 48x48 px) y su color. Lo prueba `debug/suite/hover_frame_cases.gd`.
- No aparece sobre cadáveres, cielo, suelo ni HUD, ni durante un arrastre; los edificios, con un icono armado o en reposo (`buildings_idle`).
- La malla (20 vértices, 16 triángulos) sale de `HoverFrameRules.frame_mesh()`. Aspecto en el inspector: tamaño mínimo, relleno (0 como el original), colores de alma. La caja con el nombre es `target_info/`.
- Solo presentación local: nada de la simulación lo lee.
- Agregar uno nuevo: ponerlo bajo `Hud` y asignar `probe`.
