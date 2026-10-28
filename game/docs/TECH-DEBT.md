# Deuda técnica conocida

Lo que se sabe que está mal o fuera de lugar y todavía no tiene corte. Cada entrada dice qué pasa, qué se sospecha y qué haría falta para cerrarla.

## Nav: «2 edge errors» en el servidor dedicado de Linux

- Qué pasa: el dedicado de Linux (x86) avisa «2 edge errors» al sincronizar el navmesh del mapa.
- Hipótesis (NO VERIFICADA): el navmesh unido de `NavZones` trae vértices duplicados o casi iguales en las costuras entre zonas, y con el redondeo de x86 el rasterizador del mapa ve dos aristas en la misma celda.
- Arreglo candidato: soldar los vértices de la unión, cuantizados a `cell_size` (`data/nav/nav_bake.tres`), en la pieza que une las zonas (`NavZones` / `NavService`).
- Cómo se mide: un chequeo que cuente aristas compartidas por más de dos polígonos y vértices a menos de `cell_size / 2` en el `nav.res` de cada mapa; después, un dedicado de Linux sin el aviso.
- Costo: hay que rehornear los `nav.res` de todos los mapas (`tools/bake/bake_nav.tscn`).


## Red: aviso «saved MpSync is out of date» del mago en el dedicado

- Qué pasa: en una partida LAN headless (dedicado con IA), el host avisa una vez `MpActor on 'Wizard2' (wizard_body.tscn): its saved MpSync is out of date`.
- Lo que se sabe: al cargar la escena empaquetada, `MpSyncBuilder.matches` da `true`; la diferencia aparece en runtime, probablemente porque `sync_entries()` depende de algo que cambia después de `_ready` (aflicciones o pasivas montadas, refactor 2026-10-28).
- Qué haría falta: abrir `wizard_body.tscn` en el editor y guardarla; si el aviso sigue, imprimir `sync_entries()` en runtime contra el config guardado y ver qué entrada se agrega.

## Red: `LightningCharge:shown` no se probó en verdadero con un cliente

- La sincronización del nodo funciona (llega al cliente sin errores), pero en la prueba LAN nadie le pegó un rayo al Storm Giant y `shown` nunca pasó a `true`.
- Cómo se cierra: una LAN con un rival Stratos, o forzar daño de rayo sobre el gigante, y ver `shown=true` en el cliente.
