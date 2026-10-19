# Features
- Con un `deflector` (el escudo del Protector desvía el golpe a otro cuerpo), `damage_typed` devuelve el daño que tomó el que desvía y `LifeDrain.feed` cura con eso; el original sí drena con el daño de los guardianes (F164b).
- El digest del banco hashea posiciones, no vida: el drenaje lo prueban `check_drain` de `f164_expect.py` y `f166_expect.py`.

Fan game de Sacrifice. Arquitectura estándar. Multijugador online con servidor dedicado.

## Must

### F1 — Servidor dedicado
El proceso con `--dedicated` llama `host_dedicated`, no tiene slot de jugador e imprime el puerto. No abre menú.

Criterio: headless `-- --dedicated` queda en marcha y escribe `dedicated listo puerto`. Hecho: puerto 7777 y slot 0.

### F2 — Unirse por IP
El cliente escribe una IPv4 y entra al mundo cuando el dedicado abre la partida.

Criterio: un cliente a `127.0.0.1` carga `res://scenes/world/high_noon.tscn` y muestra un slot mayor que 0. Hecho: la captura lee «Slot 1».

### F3 — Jugar solo
No llama a `host()`. Carga el mismo mundo en local.

Criterio: el botón Jugar solo cambia a High Noon sin abrir el puerto. Hecho: el puerto 7777 quedó libre.

## Should

### F4 — Terreno de High Noon
Altura y paredes de acantilado exportadas desde la instalación local, fuera de git, puestas en el mundo. Sin texturas de baldosa. Hecho: la captura muestra el cañón, no un plano.

### F5 — Mago y una criatura
James y el campesino están en High Noon, en pose quieta, sin textura original. El campesino queda junto al mago.

Criterio: la captura muestra dos figuras, el mago y el campesino. Hecho: James y el campesino de pie, altura parecida.

### F6 — Tick comparado con sacengine
Tras N ticks, posición y vida coinciden con una partida scriptada de sacengine.

Criterio: en `res://debug/idle_tick.tscn`, la acción `check_tick` muestra «coincide». Hecho: el rótulo pasa de «Pendiente» a «coincide». Es un tick quieto (velocidad 0, vida 1), no una orden de combate.

### F7 — Avance comparado con sacengine
Una orden con velocidad distinta de cero. Tras N ticks la posición horizontal cambió y coincide con el dump de sacengine. El mago se mueve en la escena. La vida sigue en 1. No es combate y no llama a `ObjectState.update`.

Criterio: en `res://debug/advance_tick.tscn`, la acción `check_tick` mueve al mago y el rótulo pasa de «Pendiente» a «coincide». Hecho: el mago pasa de Z 1275 a 1278 y el campesino se queda. No es combate.

### F8 — Posición tras frames de ObjectState
sacengine avanza N frames con el `update` que ya tiene la partida y escribe la posición del mago. Godot no recalcula `speed/fps`: lee ese archivo y, con `check_tick`, deja al mago ahí. El rótulo pasa de «Pendiente» a «coincide».

Criterio: en `res://debug/state_tick.tscn`, la acción `check_tick` muestra «coincide» y el mago deja el punto de encuadre. Hecho: el mago pasa de (1275, 53.4, 1275) a (1502.47, 16.9, 1555.2). El campesino no se mueve.

### F9 — Orden de movimiento en la partida
Una orden `move` entra en la partida y `ObjectState.update` la ejecuta. El dump trae al mago lejos de donde aparece. Godot no calcula el camino: con `check_tick` lo deja en esa posición.

Criterio: en `res://debug/move_order.tscn`, la acción `check_tick` muestra «coincide» y el mago no está en el punto de aparición del frame 60 sin orden. Hecho: frame 49, el mago queda en (1507.67, 16.9, 1555.94), a 5.25 del spawn. El campesino no se mueve. Esa escena compara el dump. No es el caminar del jugador: un solo cambio de posición es un salto.

### F10 — El mago camina con una orden
El jugador da la orden y el mago recorre el camino. Cada tick avanza un paso medido en sacengine. Godot no lo lleva de un salto a la meta y no usa la física del motor como regla.

Criterio: en `res://debug/walk_order.tscn`, la acción `order_move` lo pone en marcha. Tras un segundo no está en el inicio ni en la meta. La captura lo muestra a mitad de camino. Hecho: en 1 s el rótulo dice «Caminando», el mago pasa de (1275, 53.4, 1275) a (1279.55, 53.4, 1279.55), unos 6.4 m de 12, y la altura no cambia. El campesino se queda.

### F11 — La caminata usa el motor
El mago es un `CharacterBody3D`. La orden lo mueve con `move_and_slide` sobre la colisión del terreno. La velocidad sale del tramo medido en sacengine.

Criterio: en `res://debug/walk_order.tscn`, `order_move` lo pone en marcha. Al segundo caminó sobre el suelo y no está en la meta. Hecho: arranca en y ≈ 11.9, en 1 s recorre unos 6.4 m y el rótulo dice «Caminando».

### F12 — El dedicado mueve el cuerpo
El cliente manda la orden. El servidor dedicado avanza el `CharacterBody3D`. El cliente pinta. Jugar solo no abre servidor.

Criterio: con el dedicado en marcha, un cliente entra a High Noon, pulsa `order_move` y al segundo el mago se movió en el plano. El cliente no simula ese cuerpo. Hecho: Slot 1, el mago pasa de (1275, 11.89, 1275) a (1279.95, 12.53, 1279.95), unos 7 m. El campesino se queda. Después del playtest pt20, el flow camina con `move_forward` 1.5 s: el dedicado imprime «mago 1 arranca en 1504.9 1540.4» y «para en 1507.2 1526.9», y el cliente ve la misma posición (`AgentKit/wizard_travel`: «caminó 13.7 m»).

### F15 — Cámara, WASD, cielo de Persephone
El mago camina con W A S D. El mouse gira la cámara (arrastre con el botón derecho o el central, y el borde de la pantalla). El cielo, las plantas y las estructuras salen del tileset de Persephone, no del de James. El cielo no muestra el anillo de corte de la textura.

Criterio: en `res://scenes/world/high_noon.tscn`, mantener `move_forward` un segundo mueve a James. La captura del cielo no muestra un corte circular ni paneles verticales. Se ven plantas y estructuras de Persephone con textura. Hecho: James pasa de (1275, 11.9, 1275) a (1280.3, 12.8, 1283.2). El cielo es el de Persephone, de una sola vuelta. El manalito y los arcos tienen la piedra y el brillo azul.

### F13 — Partida mínima al estilo Sacrifice
La cámara sigue al mago. El clic en el suelo lo manda ahí. El libro de abajo tiene Convocar y Rayo: primero el hechizo, después el suelo. La criatura convocada queda elegida y el clic siguiente la manda a ese punto.

Criterio: en `res://scenes/world/high_noon.tscn` se ve al mago caminar hacia el clic, un campesino aparecer en el suelo elegido, caminar cuando se le ordena, y un rayo salir hacia el blanco.

## Núcleo de juego (RFC-016)

### F16 — Datos del instalador
`tools/export_stats.py` lee CRE8, WIZD y SPEL de `spells.wad`. El autoload `GameData` arma los tipos y los libros por dios.

Criterio: en `res://debug/data_book.tscn`, `check_tick` muestra los libros. James: Manahoar, Trogg, Earthfling, Gargoyle / Speedup, Heal, Rock. Persephone: Druid, Ranger, Shrike / Wrath. Trogg: 960 de vida, 8.25 m/s, 1 alma. Rock: 300 de maná, alcance 125, cooldown 8 s. Aparecen los 15 magos.

Hecho: 71 criaturas, 15 magos, 53 hechizos y 60 habilidades. James: Manahoar, Trogg, Earthfling, Gargoyle / Speedup, Heal, Rock. Persephone: Manahoar, Druid, Ranger, Shrike / Speedup, Heal, Wrath. «Trogg 960 vida 8.25 m/s 1 alma». «Rock 300 maná alcance 125 cooldown 8 s». «15 magos», de Jadugarr a Hachimen.

### F17 — Mallas horneadas y estructuras
Las mallas se guardan una vez. Se quita el anillo de modelos. Cada slot tiene manantial y altar.

Criterio: en `high_noon.tscn` no está el anillo y se ven manantial y altar. Se imprime `carga mundo ms` < 2000. El dedicado no carga mallas.

Hecho: `tools/bake_bodies.gd` hornea 84 cuerpos y 70 props en unos 2.7 s. `high_noon` imprime «mundo listo 89 ms» con ventana y 39 ms en headless, sin el anillo. En headless `BodyLibrary` no carga mallas. En `res://debug/body_gallery.tscn` se lee «cuerpos 84 de pie 84». Cada slot tiene el altar `alt1` (`alba` + 4 `alpi` + `alto`) y el manantial `pcfn`, en las posiciones de High Noon. Hay 40 plantas con su textura. Después del playtest: las rocas PCW5 y PCW6 se ven con textura y volumen; la Guadaña `ddiz` no tiene el rectángulo negro, porque se aplica el chroma key del SAXS; ninguna planta queda oculta. Capturas: `agent/out/f17_plants_fixed_*.png` y `f17_gallery_zoom_scythe_fixed.png`. Después del playtest pt20, las plantas son los widgets del NTTS de High Noon (JAW1–5) en sus posiciones originales, con modelos de Persephone por etiqueta (`widget_models`). Se omiten los que caen sin suelo o a menos de 40 m del altar y 6 m del manantial. Se ven alrededor del spawn (`agent/out/fix_holes/plants/`).

El mago no cae por los agujeros del mapa: `GroundGuard` desliza el paso sobre el suelo como `moveOnGround` de sacengine. En `res://debug/hole_edge.tscn`, mantener W 5 s deja al mago en el borde, en el suelo (`agent/out/fix_holes/holes/`). Las criaturas usan el mismo `GroundGuard` en `UnitBody`; si igual caen 25 m bajo el suelo en un agujero, revientan sin alma (`gib(state, -2)`, `state.d:14800-14821`, `8341`). Ese caso no tiene flow.

Luz (pulido final): dagon usa los colores de ambiente y sol del ENVI como valores lineales (`ambientConstant`, `renderer.d:1156`; `sunColor`, 1174-1176; `deferred.d:383, 403-411`, contra el albedo pasado a lineal). Godot lee un `Color` de luz como sRGB, así que `ThemeApplier` le pasa `linear_to_srgb()` del valor. El ambiente pesa frente al sol como en `deferred.d` (sol `albedo/π·sunEnergy`, ambiente `albedo·1`): `GodTheme.ambient_light_energy()` = π/14 con el sol calibrado a 1.0 en fuerza 14. Las texturas con alfa (plantas) pasan por `fix_alpha_edges()` antes de los mipmaps, y de lejos ya no son puntos negros. La roca de Rock y la cara de abajo de `alto` siguen oscuras porque sus texturas lo son (la roca promedia 50/255); con la cuenta de dagon (exposición 0.5·0.6, ACES) la roca da unos 40/255 al sol también en sacengine. Re-horneado con `bake_bodies.gd`.

### F18 — Cámara original e InputMap
WASD mueve al mago. Teclas de hechizos y órdenes del original. Bordes de la pantalla: los costados giran a 36°/s y arriba/abajo acercan o alejan. Rueda ±0.04.

Criterio: en `high_noon.tscn`, 1 s con el mouse en el borde izquierdo gira unos 36°. El borde superior acerca y el inferior aleja. Un clic derecho corto sigue dando la orden.

Hecho: `scenes/world/world_camera.gd` en la cámara de `high_noon.tscn`, con las fórmulas de `positionCamera` de sacengine (distancia, altura, foco y ojo +1 m) y el suavizado del zoom. En `res://debug/camera_edges.tscn` imprime «borde izquierda giro 36.3», el zoom pasa de 0.125 a 0.000 con el borde superior y a 0.50 con el inferior. Arrastrar con el botón central mira hasta 80° hacia arriba y se ve el cielo. El −90 del playtest pt20 era el pitch libre relativo; el absoluto (`view_pitch_deg`) queda entre −80 y 85. sacengine no lo limita. La cuña negra al mirar arriba junto al altar es la cara de abajo del techo `alto`, iluminada solo por el ambiente. En campo abierto el cenit es cielo (`agent/out/fix_holes/holes/hole_02_look_up.png`). `order_units` sigue dando «Orden». InputMap completo: Q / Shift+… criaturas, X R C LAlt E T Espacio hechizos, Ctrl+R/A/Espacio, Ctrl+Q o Shift+B, P, grupos 1–0 y Ctrl+1–0.

### F19 — Cielo en movimiento
El cilindro rota 2π/512 rad/s y las nubes se desplazan (1, −1) cada 64 s. Repetición en espejo, sin costuras.

Criterio: en `res://debug/sky_motion.tscn`, a los 16 s el ángulo es 0.196 rad y las capturas a t=0 y t=16 no son iguales. No hay corte vertical.

Hecho: mallas del original (cilindro SKYT, anillo SKYB y plano de nubes SKY_) en `scenes/world/sky.tscn`, con espejo en SKYT/SKYB y energía 1.7. A los 16 s imprime `cielo angulo 0.196`. Las capturas `agent/out/f19_dev.png` (3 s) y `f19_dev_16s.png` (16 s) difieren. El corte venía de las texturas exportadas corridas 8 px; se corrigió `tools/export_persephone.py`.

### F20 — Un mago por slot
Cada cliente tiene su mago, con vida 1500, maná 1000 y almas. HUD con los tres valores.

Criterio: con el dedicado y dos clientes, cada cliente ve dos magos y W mueve solo el propio. El HUD dice «Vida 1500/1500 · Maná 1000/1000».

Hecho: `WizardSpawner` (`MpSlotSpawner`) crea un `scenes/world/wizard/wizard_body.tscn` por slot ocupado: el slot 1 en el altar de `Slot0` y el 2 en el de `Slot1`, a 30 m hacia el manantial y mirándolo. El dedicado no tiene mago. El cuerpo lleva `Health`, `ManaPool` y `SoulPurse` (`scenes/world/components/`), con los valores de `GameData.wizard(tag)` y las almas de `MatchRules`. Se replican con su `MultiplayerSynchronizer`. Solo el cliente dueño maneja su mago: el servidor acepta `submit_drive` si `slot_for_peer(sender) == owner_slot`. Shift+W ya no camina. El HUD (`scenes/ui/hud.tscn`) muestra «Seerix · Persephone» y «Vida 1500/1500 · Maná 1000/1000 · Almas 12». Con el dedicado en el puerto 7791 y dos clientes (`agent/flows/f20_client_a.json` y `f20_client_b.json`), cada uno ve `Wizard1` (`serx`) y `Wizard2` (`jnwr`). W de A mueve solo a `Wizard1`, unos 8.7 m, y W de B solo a `Wizard2`, unos 8.6 m. Capturas: `agent/out/f20_a_antes.png` y `f20_b_despues.png`. En solo: `f20_solo.png`. Pendiente: la regeneración de vida según el maná va en F31.

### F21 — Selección de personaje
Menú con los 15 magos (modelo real) y los 5 dioses. El dios define el libro.

Criterio: en `boot.tscn`, elegir Seerix y Persephone imprime `pick serx persephone` y en el mundo aparece la malla `serx`.

Hecho: menú en `scenes/ui/character_select.tscn` dentro de `boot.tscn`, con los 15 magos, los 5 dioses, el libro inicial y el modelo real girando (`wizard_preview.tscn`). «Jugar» guarda `SacrificeFlow.pick` e imprime `pick serx persephone` (flow `agent/flows/f21_pick.json`, `agent/out/f21_select.png`). En red, el cliente manda la elección por el canal `pick` de MpKit, el dedicado la valida por slot y replica `SacrificeFlow.slot_picks` (`slot 1 pick jnwr james`). Malla en el mundo: el mago del slot toma `wizard_tag`, `model` y `god` de `pick_for(slot)` en el servidor y los replica. Elegir Seerix muestra `serx` en solo y en red (`agent/flows/f20_solo.json`, `agent/out/f20_solo.png`).

### F22 — Maná por manantial y altar
Sin regeneración pasiva. 33.3/s a 50 m del manantial, 16.7/s cerca del altar, y se suman.

Criterio: en `res://debug/mana_fount.tscn`, lejos el maná no sube. Al acercarse con W sube unos 33 por segundo. Hecho: `ManaSource` en el manantial (cualquiera) y en el altar (solo su jugador), distancia 3D < 50 como sacengine. El mago arranca con 200 a 120 m del manantial: 0/s; tras 8 s con W queda a 40 m y sube 33.33/s. Junto al altar sube 16.67/s. En High Noon el altar y el manantial están a 121.7 m, así que ningún punto recibe los dos; con radio 80 de prueba se suman a 50.00/s.

### F23 — Base de partículas
`ParticleType` y `SpriteParticles` con atlas del juego. `FxBus` reproduce efectos en todos los clientes.

Criterio: en `res://debug/fx_gallery.tscn`, lanzamiento, Heal, Speedup, roca y sangre se ven con sus sprites. El emisor se libera solo. En headless no crea nada. Hecho: 9 efectos (`cast_james`, `cast_persephone`, `summon`, `heal`, `speedup`, `rock`, `dirt`, `blood`, `hover_blood`) con atlas 4×4 de `main.wad` y `charlie.wad`. Al segundo `FxBus` tiene 9 emisores y a los 4 s ninguno. En headless no instancia nada.

### F24 — Libro y lanzamiento
Speedup, Heal y el hechizo del dios con su maná, tiempo de lanzamiento y cooldown.

Criterio: en `res://debug/cast_heal.tscn`, Heal sube la vida de 500 a 1500 y el maná baja 300. Rock queda bloqueado unos 10 s. Sin maná aparece «Sin maná». Hecho: `Spellbook` y `Caster` en el mago, con el servidor como autoridad. Teclas por `spellOrder`: X Speedup, R Rock, C Heal. Se arma con la tecla y se lanza con clic izquierdo. Valores de `GameData`: los tres cuestan 300. Speedup tarda 0.74 s, alcance 100, y dura 6.5 s en el mago (×1.75). Heal tarda 0.37 s, alcance 100, y cura 1000 a 240/s (4.17 s). Rock tarda 0.74 s, alcance 125 y vuela a 30 m/s. Cooldowns (sacengine `applyCooldown`): Rock 10.24 s, Heal 2.87 s y Speedup 3.24 s. Los demás hechizos esperan 3.24 s, o 2.87 s tras Heal. El maná se drena durante el lanzamiento. En la escena debug, Heal deja 1500/1500 y 700 de maná. Rock sigue «Enfriando» a los 9.5 s y vuelve a los 10.6 s. Con 100 de maná aparece «Sin maná». Online (dedicado en 7795 + 1 cliente): el servidor imprime `lanza Heal slot 1` y el cliente ve el maná bajar y «Enfriando». La roca no hace daño (F28). Los hechizos de otros dioses dicen «No implementado». Flows `agent/flows/f24_cast.json` y `f24_online_client.json`.

Pulido del libro (como `renderSpellbook`, `renderer.d:4872-4975`): abajo a la izquierda, en unidades de una pantalla de 480 de alto (escala = alto/480, 1.5 a 720), tres pestañas de 48 (Criaturas, Hechizos, Estructuras) con el aro dorado en la activa, y solo las casillas de 32 de la pestaña activa sobre la tira del marco. Una tecla de criatura o de hechizo cambia a su pestaña antes de chequear (`switchSpellbookTab`); también se cambia con clic en la pestaña. Cada casilla tiene la página de su pestaña, el ícono original achicado y desvanecido por maná/costo, el espíritu si faltan almas y el barrido del enfriamiento. La tecla no se dibuja en la casilla porque el original no la muestra (`renderer.d:4912-4975`); queda en el tooltip. `tools/export_icons.py` saca los ICON (TXTR) de `MAIN.WAD!/icon.FLDR` a `cache/look/icons/<tag>.png` y `tabs`, `page`, `fram` y `spi2` a `cache/look/hud/`; sin caché se escribe el nombre. A 1280×720 la barra ocupa unos 210×110 px y no tapa al mago con el zoom al máximo (`agent/flows/polish_spellbar.json`, `agent/out/polish_spellbar_close_*.png`). Un hechizo armado sigue armado si el clic no tiene blanco o el lanzamiento se rechaza («Blanco inválido», «Sin maná»…), como `castSpell` (`dagonBackend.d:1236-1250`); el clic derecho lo cancela. `f28_rock` lo prueba: tras «Blanco inválido» en el suelo, un clic en el Trogg lanza Rock sin volver a pulsar R.

### F25 — Convocar criaturas
Las criaturas del dios, con stats de CRE8. Cuestan maná y almas.

Criterio: en `res://debug/summon_unit.tscn`, Shift+Q (orden del libro por `spellOrder`; Q es Manahoar) convoca un Trogg con la malla `eorc` y el HUD dice «Trogg 960/960». Con una orden camina unos 8.25 m en 1 s.

Hecho: las criaturas son entradas del libro, como en sacengine. `Spellbook` ordena criaturas y hechizos juntos por `spellOrder` y aplica el cooldown a todo el libro. Por eso James queda Q Manahoar, **Shift+Q Trogg**, Shift+W Earthfling y Shift+R Gargoyle: el Trogg sale con Shift+Q, no con Q. `Caster.request_summon` (RPC `submit_summon` validado por slot) chequea almas, maná y cooldown, sin blanco ni clic en el suelo. `Summoner` pone la criatura 6 m delante del mago (`spawnPosition`, con sus posiciones de reserva) apenas empieza el lanzamiento, translúcida (alfa 0.36, modo `SUMMONING`), con `FxBus` `summon` en el lugar y `cast_<dios>` en el mago. El maná se drena durante el lanzamiento (Trogg 0.43 s, 300 de maná). Al terminar, `SoulPurse.spend` cobra el alma; si falta, la criatura se borra y aparece «Sin almas». La criatura entra a la selección. `UnitSpawner` (en `high_noon.tscn`) instancia `units/unit.tscn` en `%Units`; se quitó `UnitBody.new()` y el WORKAROUND de F26. Las criaturas voladoras ya se pueden convocar y no quedan pegadas al suelo: nacen en suelo (como `spawnPosition` en sacengine) y `UnitBody` mantiene altura de vuelo sobre terreno (`flyingHeight = 4.5`, `upward/downwardHoverSpeed = 3.0`, tomado de `stats.d`). La barra muestra las criaturas (nombre, tecla, maná y almas) antes de los hechizos, y el HUD muestra la unidad elegida. En la escena debug: el Trogg aparece a 6.0 m del mago con `eorc`, el HUD dice «Trogg 960/960» y «Maná 700/1000 · Almas 11», y con `order_units` camina 8.25 m en 1 s. Shift+Q otra vez dice «Enfriando» (3.93 s). Q convoca un Manahoar por 1 de maná y 1 alma: «Manahoar 550/550», «Maná 699 · Almas 10». Online (dedicado en 7797 + 1 cliente): el servidor imprime `convoca Trogg slot 1` y el cliente ve «Trogg 960/960» y «Almas 11». Flows `agent/flows/f25_summon.json`, `f25_flying_summon.json` y `f25_online_client.json`.

### F26 — Cuerpo a cuerpo, muerte y cadáver
Golpe con la fórmula del original. A vida 0 queda el cadáver. Como en sacengine, una muerte normal no salpica sangre (solo el gib).

Criterio: en `res://debug/melee_duel.tscn`, un Trogg y un Druid enemigos pelean; uno muere y queda el cadáver.

Hecho: `UnitBody` (`scenes/world/unit_body.gd`, escena `scenes/world/units/unit.tscn`) toma vida, velocidad y modelo de `GameData.creature(tag)`. Usa `CharacterBody3D` y `move_and_slide`, con autoridad del servidor y su `MultiplayerSynchronizer` fijo. Estados: quieto, orden, persecución, ataque y muerto. Sin orden ataca al enemigo más cercano dentro de `sightRange·0.1` (100 m), como `patrol`. El golpe usa `dealMeleeDamage` (`state.d:9231`) y la resistencia de `state.d:8951`: `facing = 1.5 + 0.5·dot`, `P = acc/(acc + evasión/facing)`, `daño = facing·frames/(fps·ticks)·fuerza·0.4·resistencia`, rebajado por `(1−tirada)/(1−P)` si falla. El ritmo sale de las animaciones SXSK `HUa1` (24 cuadros a 30 fps, golpe en el 15) y `HUa2` (20, golpe en el 14), que `tools/export_stats.py` ahora exporta. Frente a frente: el Trogg pega 64.0/53.3 con P 0.500 y el Druid 48.0/40.0 con P 0.476. En tres corridas ganó el Trogg con 338–486 de vida y unos 36 golpes. Al morir el cuerpo cae de espaldas (la sangre al morir se quitó en F30: sacengine solo la tira en el gib) y queda en el grupo `corpse`. Las barras de vida son verdes para el jugador y rojas para el enemigo. `check_tick` repite el duelo. Flow `agent/flows/f26_duel.json`, capturas `agent/out/f26_*.png`. `f14_controls` sigue pasando.

### F27 — Órdenes RTS y selección
Clic, Shift+clic, Ctrl+clic, rectángulo y grupos. El clic derecho mueve, ataca o escolta según el blanco.

Criterio: en `res://debug/orders_group.tscn`, el rectángulo elige 4 unidades y el clic derecho sobre un enemigo las pone a atacar.

Hecho: `Selection` (`scenes/world/selection.gd`, `%Selection` en `high_noon.tscn`) guarda la selección del jugador local, solo con criaturas propias vivas y sin tope (RFC-025: `max_size` 0; con 12 vuelve el clásico, la más nueva primero). El clic elige y Shift+clic agrega o quita. Ctrl+clic o doble clic eligen las del mismo tipo a 50 m, y Ctrl+Shift las suma. Arrastrar el izquierdo 3 px o más dibuja el rectángulo blanco `%SelectionBox`; Shift suma, y un rectángulo vacío deselecciona. El clic izquierdo en el suelo o en vacío, sin Shift ni Ctrl y sin nada armado, también deselecciona (desvío consciente del original, RFC-025 3.2); sobre cuerpos o la HUD no. Ctrl+arrastre sigue siendo la vista libre de la cámara, como en el original. Grupos 1–0: Ctrl+N define, N elige (un grupo vacío no cambia nada) y Shift+N agrega. Las criaturas convocadas entran a la selección y al grupo 0. Las barras de vida propias se ven solo con la criatura seleccionada. El HUD `%Unit` muestra «Trogg 960/960» con una y «4 unidades» con varias. Clic derecho: enemigo = atacar, criatura o mago propio = escoltar, cadáver = guardia del lugar, suelo = mover. Ctrl+R (atacar) y Ctrl+A (guardia) arman el clic izquierdo: sobre un cuerpo atacan o escoltan; sobre el suelo avanzan o guardan el lugar. Ctrl+Espacio manda a todas las criaturas propias a retirarse junto al mago. `Orders` (`scenes/world/orders.gd`, RPC `submit_order(unit_paths, command, target_pos, target_path, facing)`) valida en el servidor el `owner_slot` de cada unidad. Arma la formación en línea (filas de 12 detrás de la primera, sin tope de unidades) con separación `min(1.25·tamaño + 0.85, 10)`, girada según la cámara, y asigna los lugares por distancia. Cada criatura tiene un hijo `Orders` (`units/unit_orders.gd`) que la maneja: mover ignora enemigos hasta llegar; atacar persigue a cualquier distancia; escoltar, guardia y retirada pelean dentro de 50 m de su ancla. En `debug/orders_group.tscn`, Enter (`check_tick`) hace la selección por rectángulo y el clic derecho (o `order_units`) sobre el Druid pone a los 4 Trogg a atacar hasta matarlo. Flow: `agent/flows/f27_orders.json`.

Empuje entre cuerpos (pulido final): `BodySeparation` (`scenes/world/body_separation.gd`) reproduce `positionAfterCollision` (`state.d:14446-14564`) antes de `move_and_slide`, en criaturas y magos (`MovingObject`). Primero bloquea el paso contra la caja de cada obstáculo achicada 0.1 por lado (`blockSlack` 0.2), por el eje de menor solapamiento. Después suma los solapamientos con la caja agrandada 0.1 y empuja hasta 5 m/s (`collisionFixupSpeed`, `stats.d:161`). Los empates se sortean. Obstáculos según `isObstacle` (112-126): no los muertos ni los que se están convocando; el fantasma sí. La caja es `max(radio, alcance)` del horneado, la misma de la formación (sacengine usa las cajas por hueso, que no se exportan). Con Ctrl+Espacio los 4 Trogg rodean al mago sin encimarse (1.1–2.2 m entre ellos) y siguen separados al caminar (`agent/flows/final_separation.json`).

> **Reemplazado (2026-10-18, RFC-036 036f, F207):** `BodySeparation`, `BodyGrid` y `MakeWay` se borraron; la separación es la evasión de Godot (`BodyAvoidance`, NavigationAgent3D).

### F28 — Daño de hechizos
Rock hace 650 de daño por la resistencia; el Trogg es inmune. Wrath hace 550 en radio 5.

Criterio: en `res://debug/rock_hit.tscn`, Rock baja la vida del Druid y no la del Trogg.

Hecho: `Health.damage_typed` como `dealDamage` de sacengine (`state.d:8948-8972`): `min(vida, cantidad·max(0, resistencia))`, con resistencia directa o de salpicadura según `DamageMod.splash` (8955-8957) y sin daño a aliados. Las resistencias vienen de CRE8/WIZD ×1e-3 (`sacobject.d:156-160`). Druid 1.0, Trogg 0.0 (inmune por datos) y magos 0.5. Rock pide un blanco vivo no aliado (flags 8213, sin targetGround: `sacspell.d:43-65`); el suelo da «Blanco inválido». Sale del suelo mientras se lanza, persigue al blanco y explota con 650 de daño directo (`rockExplosion`, `state.d:16784`), escombros `rock`/`dirt` y la malla original `rock.MRMM`. En `rock_hit.tscn` (James, Druid a 40 m y Trogg a 60 m, sin aggro): R + clic en el Druid imprime `dano Druid 650 vida 150` y en el Trogg `dano Trogg 0 vida 960 (inmune)`. A un mago le haría 325. Wrath (Persephone) vuela a 0.5 m del suelo y explota en el blanco: 550 de daño de salpicadura (`state.d:16496-16525`); los demás reciben `550·(1−d/5)` (`dealSplashSpellDamageAt`, 9053-9088). `res://debug/wrath_splash.tscn` (hereda `rock_hit`: mago de Persephone, Ranger a 3 m del Druid) lo prueba: `dano Druid 550 vida 250 · dano Ranger 245 vida 555`, Trogg intacto (inmune a salpicadura). El registro junta los golpes de un mismo cuadro y los imprime con su tipo (`agent/flows/final_wrath_splash.json`; `pt28_wrath` también pasa). Fireball, Lightning e Insect Swarm siguen «No implementado». `cast_heal.tscn` ahora tiene un Druid a 40 m para que Rock tenga blanco. Flows `agent/flows/f28_rock.json` y `f24_cast.json`.

### F29 — Habilidades de criatura
Ataque a distancia y habilidad activa con Ctrl+Q o Shift+B. Gastan el maná de la criatura y tienen cooldown.

Criterio: en `res://debug/ability_spit.tscn`, el Earthfling escupe desde 60 m y su maná baja 5.

Pulido: Ctrl+Q / Shift+B va por `match_command` como `selectAbility` de sacengine (`dagonBackend.d:152-178`): toma la habilidad de la criatura seleccionada más nueva que tenga una (sacengine usa `creaturePriority`, que no se exporta) y la usan todas las seleccionadas con esa misma habilidad (`state.d:29256`). Si pide blanco (`flags ≠ 0`) arma el clic izquierdo y sigue armada si el clic se rechaza; si no, se usa al momento. `%Battle` dice «Rockform» o el motivo. En `ability_spit.tscn` el Earthfling empieza seleccionado y Ctrl+Q lo vuelve roca (maná 200 → 187). Rockform ya no duplica el `CreatureType`: `Health.damage_factor` = 0.05 (`state.d:8964`).

Escena de prueba (pulido final): las criaturas solo recargan maná en fuentes (`state.d:14409`), así que con `clear_of_mana` el par va al lugar más cercano sobre tierra fuera del radio de todas las fuentes; el maná gastado no vuelve (182/200 tras escupir y Rockform). `target_mana_share` fija el maná inicial del Druid: su vida regenera `regeneration·maná/máximo` (14400), 0 = sin regeneración. `target_approaches` lo hace caminar hasta el Earthfling: a 18 m deja de escupir y pega (`golpe Earthfling a Druid`). `force_swings_at_rock` arranca los golpes del Druid contra la roca (la IA no elige una roca, `isVisibleToAI`, 93). El golpe cuerpo a cuerpo ahora también aplica `damage_factor`, como `dealDamage` (8951, 8962-8969); antes la roca recibía el golpe entero. Medido: `golpe Druid a Earthfling 8 (roca, sin roca 153, ×0.05)`. Variante `res://debug/ability_spit_melee.tscn`, flow `agent/flows/final_spit_melee.json`.

### F30 — Almas
La muerte deja un alma. El mago la junta a 5 m. Convocar cuesta almas. P suelta un alma.

Criterio: en `res://debug/soul_pickup.tscn`, el mago camina hasta el alma azul y el contador sube. Con 0 almas aparece «Sin almas».

Hecho: `SoulSystem` (`scenes/world/souls/soul_system.tscn`, un nodo en `high_noon.tscn`) y `scenes/world/souls/soul.tscn` con su `MultiplayerSynchronizer` fijo y `SoulSpawner`. Reglas de sacengine (`state.d`): cuando termina la caída del cadáver (`spawnSoul`, 14016) aparece un alma con `Cre8.souls` sobre el centro del cuerpo; crece en 3 s y recién ahí se puede juntar. Se dibuja 2 m (1.25·1.6) por encima, sprite `spir` 1×1.6, 8 cuadros a 15 fps: azul (0–7) si no tiene lado o es tuya, roja (8–15) si es del enemigo; con más de 1 alma, un anillo que gira 45°/s. La junta el mago vivo a ≤ 5 m en horizontal y en vertical (`MatchRules.soul_collect_distance`), primero el dueño, después las sin lado y al final las enemigas; la roja pegada a su cadáver no se puede juntar (falta Convert). Al juntarla se achica hacia el mago a 4/s, suma `number` a `SoulPurse` y el cadáver se quita a los 2.5 s (`dissolutionTime`). P (`drop_soul`) manda `submit_drop` al servidor, que valida el slot, gasta 1 con `SoulPurse.spend` y suelta un alma de 1 a los pies del mago (no adelante), con su lado y `dropped`; tarda 3 s en aparecer y, si el mago sigue encima, la vuelve a juntar. Un alma suelta cae a 1 m/s hasta el suelo. Con 0 almas sacengine no hace nada; acá aparece «Sin almas» en `%SoulMessage` (señal `message`). En `soul_pickup.tscn` (`debug/rules/soul_pickup.tres`, 0 almas) P da «Sin almas», 3 s con W juntan el alma de 25 m adelante (Almas 0 → 1), P la suelta (→ 0) y a los 3.5 s vuelve a 1. En `melee_duel.tscn` el Druid muerto deja «alma 1 roja». Se quitó la sangre al morir. Flows `agent/flows/f30_souls.json`, `f30_duel_soul.json` y `f26_duel.json` pasan; capturas `agent/out/f30_*.png`. No se probó en red.

### F31 — Vida y fantasma del mago
La vida se regenera según el maná. A 0 pasa a fantasma y vuelve con la vida llena.

Criterio: en `res://debug/wizard_ghost.tscn`, el mago a vida 0 se vuelve translúcido y vuelve junto al manantial.

Hecho: `GhostForm` (`scenes/world/wizard/ghost_form.gd`, un nodo del mago con `stage` replicado) y la regeneración en `wizard_body.gd`. Reglas de sacengine (`state.d`): la vida sube `regeneration · maná/máximo` por segundo (16.7/s con el maná lleno) solo quieto, sin lanzar y sin un golpe en los últimos 0.5 s (14400, 1429). A vida 0 el mago muere: tarda lo que dura su animación de muerte, elegida al azar (Jadugarr 87, 51 o 154 cuadros a 30 fps), y si su lado tiene altar se levanta como fantasma (`deadToGhost`, 14004-14014 y 14081): el maná queda en 0 y el alfa pasa de 1 a 0.36 en `corpseRise` (51 cuadros, 1.7 s). Sin altar desaparece en 1 s. El fantasma corre ×1.75 (`ghostSpeedFactor`, 1090: 17.5 m/s), no recibe daño ni es blanco de criaturas, Rock, Wrath o disparos (`canDamage` 8916, `isValidAttackTarget` 138), no lanza ni convoca y no avisa nada (`canCast` 9520), y no junta almas (`canCollectSouls` 243). Cada punto de maná que le da una fuente lo cura 4.2, aunque tenga el maná lleno (`giveMana` 8827, 14409): en el manantial son 140/s. Con la vida llena vuelve donde está (`unghost`, 13959), sin teletransporte: el alfa sube en `float2Stance` (31 cuadros, 1.03 s). Los otros lados no ven al fantasma (`renderer.d:1412`). El HUD muestra «Fantasma» mientras el cuerpo es translúcido. `tools/export_stats.py` agrega `death_frames`, `corpse_rise_frames` y `float_to_stance_frames` a `wizards.json`. En `wizard_ghost.tscn` (`debug/rules/wizard_ghost.tres`, vida 50) un Druid enemigo mata al mago enseguida, después lo deja en paz (modo IDLE); el fantasma camina 113.7 m en 6.5 s hasta el manantial, sube de «Vida 0 · Maná 0» a 1500 en 10.7 s (maná 357) y vuelve con alfa 1. Flow `agent/flows/f31_ghost.json`; capturas `agent/out/f31_*.png`. Online, con el dedicado en el puerto 7799 y `--world=res://debug/wizard_ghost.tscn` en el dedicado y en el cliente (`agent/flows/f31_online_client.json`), el cliente ve `stage` 3, transparencia 0.64 y la vuelta a 0. Pasan también f20_solo, f22_mana, f30_souls, f26_duel, f24_cast y f28_rock.

Pulido final: el libro se oculta mientras el mago muere o es fantasma (`spellbookVisible`, `state.d:28104`; `renderer.d:4981-4991`). Las otras sides no ven al fantasma solo en `idleGhost`/`movingGhost` (`renderer.d:1412`; `isGhost`, `state.d:65-67`): al levantarse y al volver se ve. El fantasma no tira sombra (solo los opacos, `renderer.d:5658-5661`) y se dibuja sin luz, con energía de 1 a 10 según su alfa (`ghostEnergy`, `state.d:13779-13780`, 14084 y 14094; `shadeless.d:114`). Esa energía es textura × energía, como el ambiente, así que pasa a la escala de luz de Godot con el mismo π/14 (`energy_scale` = 0.224, en el inspector); sin esa conversión el fantasma saturaba a blanco plano. Las escoltas siguen al fantasma y a la vuelta, pero lo sueltan mientras muere (`isValidGuardTarget`, `state.d:145-151`, usado en 13016 y 13687).

### F32 — Biomas
El servidor elige un dios al azar. Cambian el cielo y el suelo.

Criterio: en `res://debug/biome_pick.tscn`, con Pyro forzado se ven el cielo y el suelo de Pyro, y los clientes imprimen el mismo bioma.

Hecho (parcial): `tools/export_tilesets.py` saca el cielo, el atlas del suelo y los colores del ENVI de los 5 dioses; `GodTheme` (`data/themes/*.tres`) y `ThemeApplier` los aplican, y `res://debug/biome_gallery.tscn` los recorre con Enter. Sorteo y réplica: `MatchBiome` (`scenes/world/match_biome.gd`) sortea en el servidor (o en solo) con `ThemeApplier.pick_random(semilla)` e imprime `bioma <dios> semilla <n>`. Manda `theme.god` a cada cliente por el canal `biome` de MpKit cuando ese cliente tiene el mundo listo. Cada cliente imprime `bioma <dios>` y lo aplica. `MatchRules.biome_god` y `biome_seed` lo fijan. En `res://debug/biome_pick.tscn` (`debug/rules/biome_pyro.tres`) se ven el cielo y el suelo de Pyro (`agent/out/f32_biome_pick.png`). Con el dedicado y dos clientes, los tres imprimieron el mismo bioma (stratos). High Noon usa ACES con exposición 0.85.

Suelo por bioma (pulido final): sacengine no cambia la tierra de un mapa. El tileset sale del LEVL (`levl.d:43-52`); cada índice del TMAP lee el `NNNN.MAPT` de esa carpeta (`sacmap.d:192-195, 688-704, 861`) y un MAPT que falta queda en blanco (695). High Noon es de James, y con otro dios el mismo índice es otra cosa: las manchas azules eran agua y transiciones de Persephone (50, 208-219) puestas por «el índice más cercano». Ahora `export_tilesets.py` lee los grupos `MGnn.MAPG` de cada tierra (`maps.d:55-76`). Los grupos base tienen una banda de altura normalizada; los de transición (byte 32) nombran dos grupos base y traen 12 baldosas. Cada baldosa de James va a la de la otra tierra con el mismo papel. Los grupos base usan un mapeo que respeta el orden de alturas y deja fundidas la mayor cantidad posible de celdas de transición del mapa; si empatan, gana la banda más cercana. Un grupo con banda de ancho 0 (MG05 `[1,1,1,1]`) toma el destino del grupo con el que más limita. La transición se decide por qué grupo base muestra cada esquina de 16×16 (casi todos los sets dan 12 firmas distintas). Si aun así falta el par, va la baldosa base de la mayoría de las esquinas; en High Noon ya no queda ninguna así. Las paredes del vacío usan el `edge.png` del tema, como `sacmap.d`. `theme.json` guarda `atlas_groups` y `atlas_remap`. James no cambia (atlas idéntico). WORKAROUND: el original nunca hace esto; ver el comentario en `export_atlas`.

### F33 — Hechizo de dios inicial (Pyro/Stratos/Charnel)
Fireball (`brif`), Lightning (`ntil`) e Insect Swarm (`mrws`) ya se pueden lanzar como segundo hechizo del libro (tecla R por `spellOrder`, después de Speedup).

Criterio: en escenas debug por dios, al pulsar R + clic sobre un enemigo aparece el nombre correcto en `%Battle`, baja su vida y el flow termina con `AGENT_OK`.

Hecho: `Caster` integra los tres tags y valida el mismo tipo de blanco enemigo vivo que Rock/Wrath. Fireball y Swarm salen como proyectiles guiados con splash (familia Rock/Wrath) y diferencias del original: Fireball (`size 0.5`, `flyingHeight 0.5`), Swarm (`size 0.3`, `flyingHeight 1.25`). Lightning pega instantáneo como daño directo de hechizo. `SpellSpawner` agrega `spawn_fireball` y `spawn_swarm`; se crearon `fireball_projectile.gd` y `swarm_projectile.gd`. Nuevas escenas/flows: `debug/cast_{pyro,stratos,charnel}.tscn` y `agent/flows/pt33_{fireball,lightning,swarm}.json`. Validado además con regresión de convocatoria: `f25_summon` y `f25_flying_summon` pasan.

### F34 — Estructuras básicas del libro y pose en movimiento
La pestaña de estructuras ya no arma un hechizo normal: arma una estructura y la coloca en suelo dentro de alcance, con spawn replicado.

Criterio: en `res://debug/cast_heal.tscn`, elegir la pestaña Estructuras, seleccionar Manalith y confirmar suelo crea `Structure1` con modelo del dios local.

Hecho: `spell_book.gd` emite `structure_pressed`; `match_command.gd` agrega `_arm_structure` y `_structure_at`; `caster.gd` agrega `structure_status`, `request_structure`/`submit_structure` y `_try_structure` para validar maná, cooldown, alcance y espacio libre. Se añadió `StructureSpawner` (`scenes/world/structures/structure_spawner.gd`) y `structure.tscn` (`structure_body.gd`) en `high_noon.tscn`, con `ManaSource` activo para `htlm` (Manalith). Ajuste de regla original: Manalith sólo se coloca sobre un manafount libre; al ocuparlo, el `ManaSource` del manafount se apaga (`rate=0`) y la estructura queda como dueña de la zona de maná. Además, las estructuras tienen `Health`, regeneración de Manalith (75/min) y pasan a ser blanco válido para órdenes/ataques/proyectiles (`unit`, `wizard`, `structure`). El zoom no cambia al construir (flujo imprime `0.125` antes y después). Validación AgentKit: `agent/flows/pt34_structures.json` y `agent/flows/pt35_manalith_lifecycle.json` (`AGENT_OK`), más regresiones `f24_cast`, `f18_camera` y `f25_summon` (`AGENT_OK`).

Pulido visual de personajes: se agregó oscilación leve de marcha en `wizard_body.gd` y `unit_body.gd` (mesh local en movimiento, retorno suave en reposo). Flow de verificación: `agent/flows/pt34_animation_pose.json` (`AGENT_OK`).

### F35 — Cadencia de locomoción desde animaciones reales SXSK
La oscilación visual de mago y criaturas usa el tiempo real de las animaciones del juego original (idle0/run/walk), en vez de frecuencias fijas.

Criterio: al caminar en `res://debug/summon_unit.tscn`, el bob/roll de `%Wizards/Wizard1/Mesh` y `%Units/Trogg1/Tilt/Mesh` se reproduce con ciclo derivado de `cache/data/{wizards,creatures}.json` (`frames`/`framerate` de run/walk). En reposo, ambos usan la cadencia de `idle_animation` y no vuelven en seco a una pose fija.

Hecho: `tools/export_stats.py` ahora exporta `idle_animation`, `run_animation` y `walk_animation` desde slots reales de `animations.d` (idle0=1, run=6, walk=24), resolviendo `frames`/`framerate` por SXSK/SKEL para criaturas y magos. `GameData` los carga en `CreatureType`/`WizardType`. `unit_body.gd` y `wizard_body.gd` reemplazan el gait hardcoded por ciclos por segundo basados en esos clips y escalan la amplitud según velocidad real.

### F36 — Playback de clips reales (MVP jnwr/eorc)
Se reemplaza la pose procedural de wizard+trogg por playback por frame de clips reales del original (SXSK/SKEL), acotado al mago `jnwr` y Trogg `eorc`.

Criterio: `res://debug/anim_wizard_trogg.tscn` usa `debug_anim_cycle` para alternar `idle/run/attack` y mostrar rol/tag/frame/fps (incluye impacto de `HUa1` desde metadata); en `res://debug/summon_unit.tscn` se ven transiciones reales idle↔run para wizard/trogg. Si falta `cache/data/anim_mesh_clips_f37.json`, la visual queda estática (fallback), sin tocar gameplay/RPC.

Hecho: `tools/export_stats.py` escribe `cache/data/anim_mesh_clips_f37.json` y exporta cada clip a todos sus frames `.obj` usando `sacengine` (`export-all-frames`), con `frames`, `framerate`, `impact_frames` y lista `frame_objs`. En esta vuelta cubre los 15 modelos de mago (`idle/run` o `idle/walk` según el modelo) y el Trogg (`HUi1/HUrn/HUa1`). `ClipPosePlayer` ahora reproduce esos frames reales de malla (no pose sintética) y se conecta en `wizard_body.tscn` y `unit.tscn`; `wizard_body.gd` y `unit_body.gd` eligen clip por estado (idle/run y ataque Trogg) con override debug. `HUa1` expone su frame de impacto por metadata (`impact_frames`) y no por hardcode visual.

### F37 — Robustez de estructuras y visibilidad en editor
El sistema de estructuras no puede quedar en estado “lógico sí, visual no”: si falta un modelo específico, la estructura sigue visible y el editor avisa la configuración incompleta.

Criterio:
- Construir Manalith en `high_noon.tscn` siempre muestra una malla visible aunque el modelo por dios no exista en `cache/baked`.
- `BodyLibrary.models()` lista cuerpos y props en una sola fuente para selectores/validaciones de editor.
- `BodyVisual` advierte en el inspector cuando el tag de `model` falta en cache.
- `ClipPosePlayer` advierte en inspector cuando `mesh_path` está vacío o apunta a un nodo inválido, sin romper gameplay.

Hecho: `structure_body.gd` resuelve modelo visible con fallback explícito y warning cuando no hay asset; evita dejar la estructura “invisible” mientras conserva su lógica de vida/maná. `body_library.gd` ahora devuelve unión de `bodies` + `props` para visibilidad/editor tooling. `body_visual.gd` y `clip_pose_player.gd` pasaron a `@tool` con `_get_configuration_warnings()` para exponer problemas de wiring en el inspector antes de correr la partida.

### F38 — Convert con Sac Doctor (RFC-020e, reescrita)
Convert (`ccas`, pestaña Estructuras) roba las almas de una criatura enemiga muerta. El mago apunta a un alma roja a 20 m o menos y necesita un altar propio en pie. Al terminar el casteo (2,2 s, 800 de maná) un Sac Doctor cae de un vórtice junto al cadáver, camina hasta él, lo revive y lo bombea `(almas+1)·5` s, lo levanta y lo lleva flotando al altar propio más cercano al mago. Ahí cuatro doctores hacen el ritual: 5 s de preparación y `int(vidaMáx/550) + 1` rondas de 13,5 s. Al final la criatura se desintegra y sus almas se suman al contador del mago.

Criterio: en `res://debug/convert_ritual.tscn`, A pulsa la pestaña Estructuras, `spell_3` y hace clic sobre el alma roja; «Almas 0» pasa a «Almas 1» y la criatura ya no está. Matar al doctor: antes de llegar, el alma sigue roja; durante el bombeo (`convert_pump_kill.tscn`), la criatura muere otra vez y deja su alma; mientras la lleva (`convert_carry_kill.tscn`), la criatura cae viva y de su dueño.

Hecho: ver F61. Lo anterior (un doctor que salía del altar, consumía el alma y volvía) no era el original y se reemplazó.

### F39 — Desecrate y fin de partida (RFC-020a, c y d, reescrita)
Desecrate (`ucas`, pestaña Estructuras) es la condición de victoria. Con un altar enemigo a 75 m o menos, el mago apunta a una criatura propia y viva a 20 m o menos. Al terminar el casteo (5,6 s, 1000 de maná) un Sac Doctor cae junto a ella, la levanta y la lleva al altar enemigo. Ahí cuatro doctores hacen el ritual a 20 m del altar: 5 s de preparación y rondas de 13,5 s. Cada ronda le quita al mago enemigo `200·(1+almas)` de vida y `40·(1+almas)` de maná. Si el mago muere bajo ritual no vuelve como fantasma: desaparece, su altar se destruye y su bando queda derrotado. Si muere cualquiera de los cuatro doctores, el ritual se cancela y la criatura queda viva y libre.

Criterio: en `res://debug/desecrate_ritual.tscn`, con dedicado y dos clientes, A pulsa la pestaña Estructuras, `spell_4` y hace clic sobre su criatura; el cliente A termina en «Victoria» y el B en «Derrota», con el altar 2 destruido en los tres procesos. En `res://debug/ritual_cancel.tscn`, los tiradores matan a un doctor: el altar 2 sigue en pie y la criatura vuelve a `%Units`.

Hecho: ver F57, F59 y F60. Lo anterior (borrar una criatura, un doctor que cantaba 7,5 s y destruía el altar) no era el original y se reemplazó.

### F40 — Corte integral de fidelidad visual + editor + combate base
El slice cierra de una vez los problemas que rompen la lectura jugable del port: animación real de unidades, orientación/pivote/escala correctos, partículas faltantes, habilidades faltantes del roster actual y edición del mundo desde inspector sin depender de instanciación opaca por código.

Criterio:
- En `res://debug/unit_parity_gallery.tscn` se despliega una muestra de magos/criaturas/estructuras del roster activo, con ciclo `idle/run/attack` real por tag SXSK; el panel debug muestra `role/tag/frame/fps` y no hay modelos rígidos sin clip cuando el clip existe en cache.
- La galería valida orientación y apoyo al suelo por modelo (`upright_fix` + `foot_offset`): no hay unidades de costado ni flotando para los modelos del roster jugable; los ajustes quedan visibles/editables en datos (`cache/baked/*.json` + tooling), no hardcodeados por nodo.
- `high_noon.tscn` expone Sky/Environment como nodos editables en escena (sin perder la aplicación por bioma); abrir la escena en el editor muestra cielo, entorno y tunables sin depender de creación ad-hoc en `_ready`.
- Las partículas definidas en `data/fx/*.tres` se disparan en todos los eventos ya implementados del loop (cast, summon, heal/speedup, ranged impact, fireball/wrath/rock/swarm y habilidades activas), con verificación en `res://debug/fx_gallery.tscn` + playtest.
- Las habilidades/poderes de criaturas del roster activo dejan de responder “No implementado” cuando ya existe lógica equivalente en el original y datos en `GameData`; los casos no implementables aún deben responder motivo explícito y quedar listados en el panel debug.
- Parseo headless sin `SCRIPT ERROR` y playtest de `res://debug/unit_parity_gallery.tscn` + `res://scenes/world/high_noon.tscn` con evidencia de cada criterio.

Hecho: se agregó `res://debug/unit_parity_gallery.tscn` para auditar en una sola escena magos/criaturas/estructuras con ciclo de clips (`idle/run/attack`), metadata de playback (`role/tag/frame/fps`) y verificación rápida de pose/orientación. `high_noon.tscn` ahora incluye `%Sky` y `%Environment` como nodos persistentes de escena (editables en el inspector) y `high_noon.gd` dejó de instanciarlos dinámicamente en runtime. `body_visual.gd` soporta correcciones de pose/escala por modelo desde datos (`rotation_offset`, `position_offset`, `model_scale`) para tuning en cache sin hardcode por actor. `structure.tscn` incorpora `ClipPose` y `structure_body.gd` reproduce el primer clip real disponible del modelo cuando existe en `anim_mesh_clips_f37.json`. `debug/fx_gallery.gd` completa automáticamente slots faltantes desde `data/fx/*.tres`, dejando cubierta la matriz de partículas del cache. `active_ability.gd` dejó de limitarse a Rockform y ahora implementa las habilidades activas del roster actual (`!nur` Run Away, `dedp` Play Dead, `ivni` Stealth, `hsba` Life Shield, `eesd` Divine Sight, además de `dihk` Rockform), con validación de cooldown/maná/rango, efectos de estado y disparo de FX asociados.

## Won't (este corte)

Campaña, audio original, web, Steam, fork de Godot, fork de MpKit.

### F41 — Paridad jugable de unidades (animación + estado + soporte Manahoar)
Todas las criaturas convocables del libro actual (neutral + 3 por dios) deben tener clips reales `idle/run/attack` reproducibles, quedar orientadas correctamente en galería y mantener lógica servidor-autoritativa para soporte de maná del Manahoar.

Criterio:
- `cache/data/anim_mesh_clips_f37.json` contiene clips de malla para todas las criaturas convocables del libro (`books.json`) y cada una valida `idle_clip_ok`, `walk_clip_ok`, `attack_clip_ok`.
- `res://debug/unit_parity_gallery.tscn` se alimenta del libro (sin lista hardcodeada de 6 unidades), permite ciclar `idle/run/attack` con `check_tick` y muestra `role/tag/frame/fps`.
- El Manahoar aplica soporte de maná en servidor (`hmba`) con radio/curva configurables en `MatchRules`, y la galería marca `probe manahoar mana: pass`.

Hecho: `tools/export_stats.py` dejó de limitar F37 a magos+Trogg y exporta la plantilla completa de criaturas convocables del libro activo. Se agregó `tools/audit_unit_parity.py`, que cruza `nttData.d` + `books.json` + `creatures.json` + `anim_mesh_clips_f37.json` y genera `agent/out/f41/unit_parity_report.json` (sin faltantes de clips en la corrida actual). `unit.tscn` incorpora `ManaSupport` (`unit_mana_support.gd`) para `hmba`, con cálculo por distancia a Manalith aliado y aplicación de maná a aliados dentro de radio. `MatchRules` ahora expone `manahoar_rate/radius/near/far` en editor. `debug/unit_parity_gallery.gd` pasó a roster dinámico por libro y agrega sonda de maná de Manahoar.

### F42 — Suite de reglas en local
Batería determinística que corre en un solo proceso, sin peers, y comprueba reglas del juego sobre las mismas escenas y datos que la partida: unidades del roster, daño, muerte de una unidad, estructuras y su destrucción. No prueba red ni condición de victoria: eso lo cubren los flows online de `agent/flows/` (dedicado + clientes).

Criterio:
- `res://debug/rules_suite.tscn` corre la batería sobre `GameData`, `UnitBody`, `StructureBody`, `Health` y `MatchRules`.
- Cada criatura convocable del roster actual existe, tiene display name, owner y HP, y no rompe al ejecutar `begin_walk`, `engage` y `damage_typed`.
- Casos: `unit_interactions`, `battles` (una batalla con daño), `unit_death` (una unidad que recibe toda su vida queda muerta y la de al lado no), `buildings` (Manalith con `Health`, `spell_tag` y modelo) y `destruction` (una estructura que recibe toda su vida queda muerta).
- La salida en consola deja `PASS`/`FAIL` por caso y termina con `RULES SUITE PASS` si todo está correcto.

Hecho: `debug/rules_suite.gd` (antes `multiplayer_suite`) arma las piezas en una escena propia, sin entorno de red. En F46 se renombró, se quitó el caso `synchronization` (armaba un diccionario y miraba sus propias claves) y `victory_defeat` pasó a llamarse `unit_death`, que es lo que prueba.

### F43 — Higiene del mundo (Fase 0 de AUDIT-2026-10-12)
`high_noon.tscn` no lleva datos del juego original y guardarla en el editor no los vuelve a meter.

Criterio: `scenes/world/high_noon.tscn` pesa menos de 100 KB y ningún `.tscn` ni `.tres` contiene `PackedByteArray`. `res://scenes/world/high_noon.tscn` en headless imprime `mundo listo` sin `ERROR`. No hay acción de InputMap: es un corte de archivos.

Hecho: `terrain.gd` quita `PROPERTY_USAGE_STORAGE` a `mesh` y `material_override` en `_validate_property` (quedan de solo lectura en el inspector) y ya no mueve el nodo raíz en el editor. La escena pasó de 5,2 MB a 9,5 KB; `Terrain` queda en el origen, donde ya lo dejaba el runtime. Se borraron `_configure_environment()` y el `@export` `tonemap_exposure`, que nadie leía. `RULES.md` apunta a `/Applications/Godot.app`. Review: `reviews/REVIEW-F43.md` (PASS). Probado en headless, en siete escenas debug y en un dedicado real; el guardado se probó con `--headless --editor`, no con Ctrl+S en la interfaz. Sin recentrado, en el editor hay que encuadrar `Terrain` con F. Se quedan `%Creature`, `wizard.gd` y `tick_order.gd` (los usan los flows f7–f10, `wizard_preview.gd` y los `.tres` de tick). Pendiente: mover los checks F6–F10 a `debug/`; las 24 escenas que referencian High Noon con el uid viejo `uid://highnoonworld01` (hoy resuelven por ruta).

### F46 — Higiene de red (RFC-017c)
La vida de una estructura llega a los clientes, los comandos validan al remitente por un solo camino y la suite local se llama por lo que es.

Criterio: con el dedicado y dos clientes en `--world=res://debug/structure_siege.tscn`, el cliente A pulsa la pestaña Estructuras, `spell_1` (Manalith) y clic en `%View`; unos 4 s después de aparecer `%Structures/Structure1`, su `Health.current` es menor que 3000 en A y en B. Los flows online que ya existían siguen pasando.

Hecho (falta el playtest de dos clientes): `structure.tscn` tiene `MultiplayerSynchronizer` con `Health:maximum` y `Health:current`. Los `submit_*` de `wizard_body`, `unit_body` y `caster` usan `MpAuthority.accept_command(self, owner_slot)`; `orders` y `soul_system` usan el nuevo `MpAuthority.command_slot(self)` (agregado a `addons/mp_kit/mp_authority.gd` y a su README; falta subirlo a `godot-studio-skills`, ES y EN, y sumarlo a `kit-api.md`). `debug/structure_siege.tscn`: High Noon con `debug/rules/cast_heal.tres` y un Ranger enemigo (`Sieger`, slot 2, `target_groups = ["structure"]`) a 14 m del manantial 1; arranca sin estructura. El sitiador es un Ranger porque un cuerpo a cuerpo no llega a pegarle a un Manalith (el modelo de la estructura no tiene `reach` horneado: hueco de F34, sin arreglar). `structure_body.gd` ya no pisa en el cliente la vida que llega en el spawn. Review: `reviews/REVIEW-RFC-017c.md` (PASS). Evidencia del developer: con el dedicado y un cliente, la vida del Manalith baja 3000 → 2882 → 2647 en el cliente; `f24_online_client`, `f20_client_a/b`, `f27_pt_online_client`, `f30_pt_online_client` y `f31_online_client` dan `AGENT_OK`. Sin probar: segundo cliente, entrada tardía con la estructura dañada, `submit_ability` por RPC y un comando de un jugador sobre un actor ajeno (la equivalencia del rechazo se revisó por lectura).

### F47 — Los modelos se ven en el editor (RFC-018a)
Abrir una escena con un modelo horneado lo muestra en el editor, y el altar tiene sus pilares en las esquinas.

Criterio: abrir `res://scenes/world/props/altar.tscn` en el editor muestra base, techo y 4 pilares en las esquinas, sin `SCRIPT ERROR`. `model` en el inspector es un desplegable. Guardar no deja malla ni pose en el archivo. No hay acción de InputMap: es un corte de editor.

Hecho: `BodyCatalog` (`scenes/world/body_catalog.gd`, `@tool`, estático) lee `cache/baked` sin depender de autoloads; `BodyLibrary` queda como su fachada y los 14 scripts que la usan no cambiaron. `BodyVisual` usa el catálogo, ofrece los 155 tags en un desplegable y en el editor no guarda `mesh` ni su `transform`. En `altar.tscn` cada pilar es `Pillar (Node3D) > Visual`: antes `BodyVisual` pisaba su propia posición y los cuatro se dibujaban en el centro, también en partida. `ClipPosePlayer` apaga su `_physics_process` en el editor (vaciaba la malla del manantial). `sky.gd` no guarda su transform. Review: `reviews/REVIEW-RFC-018a.md` (PASS). Probado en editor headless (malla en los 8 visuales, pilares en ±20, re-guardado sin datos embebidos), en runtime headless (314 casos de pose iguales al script anterior, 8 escenas debug sin errores) y en un dedicado real (0 mallas cargadas). No se vio en el editor con interfaz. El primer Ctrl+S de una escena escrita a mano cambia el formato (`uid=`, `unique_id=`), no los datos. Regla: un `BodyVisual` no se coloca; se coloca su padre. Pendiente: `plant.tscn` tiene el `BodyVisual` como raíz (va en 018d); el gizmo todavía puede mover un visual aunque no se guarde; `node_paths=` sobre `mesh_path` en `unit.tscn`, `wizard_body.tscn` y `structure.tscn`; F17 dice «cuerpos 84 de pie 84» y la galería lista 155 porque incluye props.

### F48 — Inicios y manantiales como nodos de la escena (RFC-018b)
El mapa muestra en el editor dónde inicia cada jugador y dónde están las fuentes, y se mueven con el gizmo.

Criterio: abrir `res://scenes/world/high_noon.tscn` en el editor muestra 2 inicios (altar, mago translúcido en el punto de aparición, cartel «Jugador 1» / «Jugador 2») y 5 manantiales con su modelo. Arrastrar `MapProps/Founts/FountCenter` lo deja apoyado en el suelo. Con F6 el mago aparece donde estaba el fantasma. No hay acción de InputMap nueva.

Hecho: `PlayerStart` (`props/player_start.tscn`: `slot`, `faces`, `wizard_distance`, `spawn_spot()`, vista previa solo de editor) y `GroundSnap` (`components/ground_snap.gd`, apoya a su padre con `terrain.ground_height`; se apaga con `enabled` o quitando el hijo). `high_noon.tscn` tiene `MapProps/Starts/Start1..2` y `MapProps/Founts/FountCenter|East|South|North|West`, en las posiciones del mapa original: son 5 manantiales, antes había 2. `map_props.gd` ya no instancia altares ni manantiales; baja `rules` a los `ManaSource` en `_enter_tree`. `wizard_spawner.gd` pide `spawn_spot()` al inicio de su slot. Review: `reviews/REVIEW-RFC-018b.md`. Probado en headless: posición y giro de los magos iguales a antes en 7 escenas; maná en los 5 manantiales y altar solo a su dueño; dedicado con dos clientes sin errores; editor headless con avisos, apoyo en el suelo y re-guardado sin datos. Guardado real desde el editor (2026-10-12 21:13): la escena pesa 10,4 KB, sin malla, sin vista previa y sin posición en la raíz. En ese guardado `Start2` había quedado en (1498, 1328) y `Start1` corrido 5 cm: era una prueba del usuario y se restauraron las posiciones originales. Pendiente: 4 flows con rutas viejas (`pt35_manalith_lifecycle`, `pt20_solo`, `f17_world`, `f22_mana_pt`); el altar no guarda `owner_slot` porque no tiene script, así que Desecrate responde «Blanco inválido» (lo arregla 017a).

### F53 — Modelos de pie y apoyados (RFC-019b)
Ningún modelo jugable queda de costado ni flotando, y un modelo se corrige desde el inspector.

Criterio: abrir `res://debug/body_pose_bench.tscn` en el editor muestra al Trogg de pie sobre el piso, dentro de la cápsula y mirando la flecha de frente; elegir otro `model` en `Body/Visual` lo cambia. Agregar una entrada en `data/bodies/pose_overrides.tres` mueve el modelo en el momento. En `res://debug/unit_parity_gallery.tscn`, `debug_anim_cycle` cambia de clip sin que nadie se acueste ni flote. `Godot --headless --path game -s res://tools/audit_body_pose.gd` termina en `POSE AUDIT PASS`.

Hecho: la causa era de datos. El horneado medía la pose de enlace del SAXS, que el juego nunca dibuja, y el clip real heredaba ese giro y ese desplazamiento. Ahora `tools/bake_bodies.gd` hornea los 31 modelos con clip (roster de `books.json` y los 15 magos) desde el cuadro 0 de su idle; los otros 53 cuerpos siguen con la heurística. `tools/export_stats.py` indexa los clips por el tag real (Sylph, Abraxus y Yogo no animaban) y corrige el desplazamiento de los cuadros como el juego (`sxsk.d:128-139`): el Frostwolf estaba a +25 m. Las correcciones a mano viven en `data/bodies/pose_overrides.tres` (`BodyPoseOverride`: giro, desplazamiento, escala, cápsula, alcance), que `BodyCatalog` aplica encima del horneado; ya no se lee ninguna corrección del JSON del caché. Hoy tiene dos entradas: el giro del manantial `pcfn` y Brainiac (`sbob`), bajado 1,4 m. La auditoría pasó de 29 fallas a 0. Review: `reviews/REVIEW-RFC-019b.md` (PASS). Cambió alto, radio y alcance de casi todos los cuerpos (Jadugarr 4,08 → 3,06 m; alcance del Ranger 0,36 → 0,81; Sylph 0,34 → 0,77; Druid 0,27 → 0,55): es un cambio de balance del cuerpo a cuerpo. Sin ver con ventana: el frente de los 31 modelos, el selector de magos, el combate con los alcances nuevos y la edición en vivo desde el inspector real. Pendiente de decisión: en el original Brainiac vuela 1,4 m más alto (su clip trae ese desplazamiento); la corrección lo baja para cumplir «voladoras sin extra». Nits: `BodyCatalog.refresh()` no relee el `.tres` del disco; si se borran los `.obj` de un clip sin borrar su marcador `.displacement_fixed`, el re-export los deja sin corregir.

### Playtests del 2026-10-13 (F47, F48, F53)
Flows en `agent/flows/pt53_*.json`, `pt47_*.json`, `pt47_48_high_noon.json`; capturas en `agent/out/`. Todos terminan en `AGENT_OK`, sin `SCRIPT ERROR`. El orquestador miró los montajes.

- **F47 — PASS.** `pt47_wide_montage.png`: el altar se ve con techo, base y los pilares separados en las esquinas.
- **F48 — PASS.** Los 5 manantiales y los 2 inicios existen en partida; la vista previa del editor no aparece; en `mana_fount.tscn` el HUD pasa de «Maná 200 · +0.0/s · sin fuente» a «+33.3/s · manantial». Se migraron las rutas de `f22_mana_pt`, `pt35_manalith_lifecycle`, `f17_world` y `pt20_solo`, y los cuatro pasan. Sin jugar: el editor (gizmo, avisos), que es de interfaz.
- **F53 — PASS para magos y criaturas de suelo; voladoras sin confirmar.** `pt53_montage_idle/run/attack.png`: nadie acostado, pies en el piso, dentro de la cápsula. `pt53_s3_montage.png`: Jadugarr apoyado y el Trogg convocado de pie y caminando. `pt53_duel_montage.png`: Trogg y Druid frente a frente; muere el Druid. `pt53_boot_montage.png`: Jadugarr, Seerix, The Ragman y Marduk de pie en el selector. Sylph anima (`AAi1` → `AAa1`). **Pendiente:** en `pt53_flyside_montage.png` varias voladoras se ven inclinadas y con el cuerpo por encima o fuera de su cápsula; hace falta una vista lateral estricta para saber si es la pose de vuelo o un error. Sin ver: el Manahoar convocado encuadrado, y el frente de cada modelo respecto de hacia dónde camina.
- Aparte, visto en las capturas: a la sombra del techo del altar los personajes quedan casi negros (`pt53_s3_montage.png`).
- `pt35_manalith_lifecycle` imprime `rate=0.0` en el manantial con Manalith encima; es lo esperado (el manantial ocupado se apaga) pero el flow no lo afirma con un assert.

### F54 — Chorro del manantial (RFC-019c)
Manantial libre con chorro continuo; con Manalith, columna teñida con el color del dueño.

Criterio: ver RFC-019 (019c). Libre: chorro `elec` desde el tope del modelo, visible en el editor. Con Manalith: el chorro se apaga y aparece la columna `fb_g` teñida con el dueño; al destruirse vuelve el chorro, en todos los clientes. Un nodo con `ParticleType` `.tres` editable; sin red y sin partículas en el dedicado.

Hecho y cerrado (review PASS con observaciones, `reviews/REVIEW-RFC-019c.md`; playtest con ventana PASS): `SpriteEmitter` (`scenes/fx/sprite_emitter.*`, `@tool` `CPUParticles3D` armado desde un `ParticleType`, no emite headless), `SideColors` (paleta y `manaColor` de sacengine, `state.d:30104-30116`, `sids.d:9-16`), `data/fx/manafount.tres` y `manalith.tres` (`state.d:27769-27811`, `sacobject.d:1393-1400`), `manafount.tscn` con `FreeFx` y `ManalithFx`; `manafount_body.gd` conmuta y tiñe en `occupy`/`release` desde el `manafount_path` que viaja en el spawn del Manalith. `FxAtlas` refresca los parámetros del material en cada armado, así que energía, atlas y mezcla se ven en vivo en el inspector. Desvíos: energía 2 (sacengine 20 se blanquea con AgX), multiplicador de bando ×2, vida y anillo uniformes, paleta por slot provisional (`slot % 8`). Playtest (`agent/out/pt19c/`): chorro en High Noon a 90, 60, 31 y 4 m (`pt19c_01_walk2.png`), sin tapar unidades; al aparecer el Manalith (al empezar la construcción, no al terminar) el chorro se apaga y sale la columna lavanda del jugador 1 (`pt19c_12_after_a.png`); destruido por el `Sieger`, vuelve el chorro (`pt19c_14_destroyed_6s.png`); en red A, B y un cliente que entra tarde ven la columna (`net/pt19c_net_c_late_close.png`). 0 errores. Observación visual: el chorro libre se ve como una nube con el centro quemado a blanco, más grande de lo que debería; la columna es tenue. Se calibra en los `.tres` con el glow de RFC-022 (022h/022l). Sin probar: destrucción del Manalith en red; colores de otros slots.

### F57 — Altar con estado y partida que cierra (RFC-020a)
El altar tiene estado propio, la partida tiene una sola fuente de verdad y cada cliente ve «Victoria» o «Derrota».

Criterio: con el dedicado y dos clientes en `--world=res://debug/match_defeat.tscn`, el cliente B (slot 2, cuyo altar ya arranca destruido) camina con `move_forward` hasta la vista del Druid `Executioner`; cuando su mago muere y se desvanece, A ve «Victoria» y B «Derrota»; el dedicado no muestra nada. Un cliente que entra con la partida terminada ve el altar destruido y su resultado.

Hecho (review PASS tras una corrección; playtest con ventana en curso): `Altar` (`props/altar.gd`: `STANDING / COLLAPSING / DESTROYED`, colisión, grupo y maná), `AltarCollapse` (la secuencia visible de 11 s) y `RitualSite` (ocupación; punto de extensión de Shrine) en `altar.tscn`. `MatchState` (`%Match`) guarda altares, bandos derrotados y ganador, y los manda por snapshot, también al que entra tarde. `DefeatRule` (servidor): el mago que muere bajo ritual o sin altar en pie no vuelve como fantasma; al desvanecerse mueren sus criaturas y se derrumban sus altares; al terminar el derrumbe su bando queda derrotado. `MatchResultBanner` muestra el resultado según el slot local. Tiempos en `MatchRules`: derrumbe 11 s (`state.d:5289-5291`), desvanecido bajo ritual 4 s (`14010`). El Desecrate viejo queda con un puente transitorio hacia `begin_altar_collapse` hasta 020c. Review: `reviews/REVIEW-RFC-020a.md`. Evidencia del reviewer, con dedicado y dos clientes headless: el mago 2 muere bajo ritual, el altar pasa a `COLLAPSING` y a `DESTROYED` 11,0 s después en los tres procesos, `winner=1`, A «Victoria», B «Derrota», cartel invisible en el dedicado, y las criaturas del slot 2 mueren en servidor y clientes. El fantasma con altar en pie sigue funcionando. Sin ver: el derrumbe en pantalla; entrada a mitad del derrumbe con ventana. En solo con un único mago, perder el altar da «Derrota»; «Fin de partida» es inalcanzable hoy.

**Alcance real de F57 (aclaración del 2026-10-13, a pedido del usuario):** este corte entrega la maquinaria de cierre (estado del altar replicado, regla de derrota, cartel), no la victoria jugable. La victoria se consigue profanando el altar rival, y Desecrate todavía no se puede lanzar (020c) ni existe el ritual (020d). En las pruebas la derrota se provocó de forma artificial: `debug/match_defeat.tscn` arranca con el altar 2 ya destruido y un Druid mata al mago 2, y la sonda del reviewer marcó al mago «bajo ritual» por código y lo mató. Que un mago muera con su altar en pie **no** hace perder: vuelve como fantasma (probado). La victoria por profanación de punta a punta (lanzar Desecrate → ritual → muere el mago → cae el altar → «Victoria») es el criterio de 020d y no está probada.

### F58 — El Sac Doctor como actor (RFC-020b)
El doctor es un cuerpo propio: cae, camina, trabaja y muere, y se lo puede atacar.

Criterio: en `res://debug/doctor_bench.tscn`, `spell_3` (Rock) y clic sobre `DoctorRock` lo matan de un golpe; arrastrar la selección sobre `Guard1..4` y clic derecho (`order_units`) sobre `DoctorMelee` lo matan en 2 a 4,5 s; `DoctorDrop` cae al cargar y no recibe daño hasta aterrizar. Ninguno deja cadáver ni alma. El doctor no se puede seleccionar.

Hecho (review PASS; playtest con ventana en curso): se instaló `addons/fsm_kit` (idéntico al de la RC). `scenes/world/sacrifice/doctor.tscn` con `DoctorBody` y sus modos como nodos de estado (`Off`, `Dropping`, `Grounded`, `Working`, `Dying`) y `StuckGuard` (plazo de 45 s, invento del port; se apaga quitando el hijo). Vida 400, velocidad 10 y regeneración 83,33/s salen de `GameData.creature("dcas")`. `Attackable` (`scenes/world/attackable.gd`) es la única lista de qué se puede atacar: reemplaza tres copias en `match_command.gd`, `ranged_shot.gd` y `rock_projectile.gd`. `Health` tiene `class_name`. Una criatura ociosa enemiga ataca sola a un doctor a la vista, como en sacengine. Review: `reviews/REVIEW-RFC-020b.md`. Medido en la suite: 1 atacante no lo mata; 4 Druids en 2,8 a 4,4 s; Rock, Wrath, Fireball, Lightning y Swarm de un golpe. Una orden de ataque real lo persigue y le baja la vida. En red un cliente ve posición, pose y vida. Sin ver: nada en pantalla (`sacd` está en pose fija, sin clips); clic real; cliente que entra mientras cae.

### Playtests del 2026-10-13, segunda tanda (F58, F57, F46)
Con ventana; dedicado headless y dos clientes para F57 y F46. Flows `agent/flows/pt58_*.json`, `pt57_*.json`, `pt46_*.json`; lanzadores `agent/run_pt57.sh` y `agent/run_pt46.sh`; capturas en `agent/out/pt58/`, `pt57/`, `pt46/`. El orquestador miró las capturas.

- **F58 — A, B, C y D PASS; E (aspecto) FAIL: vuelve al developer.** Rock (`spell_2`, no `spell_3`) mata a `DoctorRock` de un golpe (400 → 0) y a los 2 s no queda nodo, cadáver ni alma. Los 4 Druids, seleccionados con rectángulo y enviados con `order_units`, lo matan en unos 4,5 s desde la orden (400, 341, 298, 143, 121, 22, 0). Un clic o un rectángulo sobre un doctor no lo selecciona. `DoctorDrop` se ve en el aire y aterriza. **FAIL:** en `pt58_e1_close.png` el doctor se ve acostado a ras del suelo mientras su cápsula es vertical; el modelo `sacd` no tiene clips exportados y sigue horneado desde la pose de enlace (es uno de los 53 cuerpos que F53 dejó con la heurística). Por eso además cuesta apuntarle. Sin probar: que no reciba daño mientras cae, jugado con input.
- **F57 — PASS como maquinaria de cierre** (no es la victoria por profanación; ver la aclaración de F57). Al cargar, ningún cliente muestra cartel; `Start1/Altar.state` 0 y `Start2/Altar.state` 2 en ambos. Tras morir y desvanecerse el mago 2: A «Victoria» (`pt57_a1_result.png`), B «Derrota» (`pt57_b1_result.png`), legibles. Dedicado: `bando 2 derrotado`, `partida terminada, gana el slot 1`, 0 `ERROR`. B reentrando con la partida terminada ve «Derrota» y el altar 2 destruido. En solo no hay cartel y el altar propio se ve entero. Observado: con solo `move_forward` el mago 2 se clava contra un manantial y el Druid queda trabado del otro lado (no hay pathfinding); hubo que rodearlo. Al reentrar con la partida terminada aparece un mago nuevo vivo. Sin ver: el derrumbe del altar en pantalla.
- **F46 — PASS.** A construye el Manalith (`spell_1` en la pestaña Estructuras); `Health.maximum` 3000 en A y en B, y `current` baja a la par: 2880,5 / 2881,2 y 2763,7 / 2764,3. `pt46_a2_damaged.png` muestra el Manalith en la ventana de A; desde B no hubo captura con el Manalith en vista (está a unos 600 m): el dato de B sale del nodo replicado. Sin jugar: entrada tardía con la estructura dañada, `submit_ability` por red y un comando sobre un actor ajeno.

### F62 — Despacho de la pestaña Estructuras (RFC-021a)
Cada hechizo de la pestaña Estructuras es una pieza propia que declara a qué se apunta. Refactor sin cambio de comportamiento.

Criterio: en `res://debug/structure_siege.tscn`, pestaña Estructuras, `spell_1` y clic en el suelo: `%Battle` pasa de «Elegí el suelo» a «Manalith» y unos 11 s después aparece `%Structures/Structure1` sobre el manantial, igual que antes. `spell_2` a `spell_5` (Guardian, Convert, Desecrate, Teleport) responden «No implementado».

Hecho (review PASS; playtest con ventana en curso): `SpellAction` (`scenes/world/spells/actions/spell_action.gd`: `tag`, `pick` en `GROUND / OWN_UNIT / SOUL / OWN_BUILDING`, `prompt`, `arm_status`, `check`, `begin`, `finish`, `cancel`) y `ManalithAction`, como hijos de `Caster/Actions` en `wizard_body.tscn`. `caster.gd` busca la acción por tag y `match_command.gd` decide el clic por `pick`; ninguno nombra un tag de esa pestaña para elegir el blanco. Quitar el nodo `Manalith` deja la casilla en «No implementado». `submit_structure` no cambió; ningún RPC nuevo. Review: `reviews/REVIEW-RFC-021a.md`. Evidencia: la sonda del developer en 10 escenarios (éxito, sin maná, enfriando, sin manantial, fuera de alcance, unidad encima, mago muerto a mitad de casteo, manantial ocupado a mitad de casteo) da salida idéntica a la línea base tomada con el código viejo; el reviewer la repitió con diff vacío. En red con dedicado y un cliente, el cliente construye el Manalith y ve su vida bajar. Las ramas `OWN_UNIT`, `SOUL` y `OWN_BUILDING` no las usa ninguna acción todavía. Huecos del contrato anotados para los cortes siguientes: no hay gancho por cuadro durante el casteo, y cada acción tiene que validar el blanco que manda el cliente.

**Corrección de F58 (2026-10-13):** el doctor ya no se ve acostado. `tools/export_stats.py` exporta los clips de una lista explícita de actores fuera de los libros (`GAME_ACTOR_CREATURES`, hoy `dcas`) y `sacd` se hornea desde el cuadro 0 de su reposo `SDda`; `tools/audit_body_pose.gd` lo incluye (`POSE AUDIT PASS`, 32 modelos). `doctor.tscn` tiene un `ClipPose` y anima reposo, carrera, clavar, bombear y levantar según `pose` y `work`, con el mapeo como dato editable; solo en procesos con mallas. `pose_overrides.tres` fija el radio de su cápsula en 0,5 (la jeringa inflaba el horneado a 0,92). Review PASS. Captura con ventana del developer: tres doctores de pie; el cuerpo queda algo corrido respecto de la cápsula según el clip. `doctor_melee`: 4 Druids de frente 5,1 s (antes 4,4). Pendiente: verlo en juego.

### F63 — Guardian (RFC-021b)
El mago ata una criatura propia a un edificio propio: la criatura pega más fuerte y aguanta más, y el edificio no recibe daño mientras tenga guardián.

Criterio: sin edificio propio a 50 m o menos del mago, `spell_2` de Estructuras dice «Lejos de un edificio propio»; un clic en algo que no es una criatura propia libre, «Blanco inválido»; a más de 40 m, «Fuera de alcance». Al terminar el casteo (1,11 s) la criatura queda atada al edificio propio más cercano a ella, sale de la selección y se ve un haz hasta el edificio en todos los clientes (también en el que entra tarde). Atada: pega ×1,5, recibe ×0,5 de hechizos y ×0,25 de disparos, se cura 16,67/s y no usa su habilidad. Un Manalith con guardián no pierde vida: la pierde el guardián. Pasados los 50 m del enganche vuelve sola a 20 m del edificio; se libera al morir, al cambiar de bando, al tomarla un doctor o al caer el edificio, y el haz se retira en 1 s.

Hecho: `GuardPost` (hijo de `structure.tscn` con `attach_height` 15 y de `altar.tscn` con 2,5; reparte el daño `daño / min(n, 0,5 (n + 3))` entre sus guardianes), `GuardianBond` (hijo de `unit.tscn`: `post_path` replicado, factores, cura, correa, validez y grupo `rooted`), `GuardianTether` (haz de 19 segmentos, aparece, se sacude y se retira en 1 s; el dedicado no lo instancia) y `GuardianAction` (`ndrg`, `OWN_UNIT`, hijo `Actions/Guardian` de `wizard_body.tscn`). `Health` suma `deflector` (`DamageDeflector`) y `kind_factors`; `UnitBody.attack_factor` lo leen `melee_attack.gd` y `ranged_attack.gd`; `ActiveAbility.locked` (ahora con `class_name`); `Selection.drop` y el doble clic separa guardianes de libres. Números en `MatchRules` (grupo «Guardián») con su cita a `sacengine/source/state.d`: 28082, 8884, 9007-9008, 14408, 15366, 15368. Sin verificar contra `Sacrifice.exe` (RFC-021 §0): la atadura dura, la liberación y el tope de guardianes; la criatura atada se puede volver a ordenar, como en sacengine. Arte placeholder: la textura `grdn.TXTR` no está en el repo, el haz es una banda aditiva (ancho estimado, 1 m). Desvío declarado (RFC-021 riesgo 2): un golpe cuerpo a cuerpo desviado llega al guardián con la resistencia del edificio ya aplicada y sin el 0,4 propio de `dealDamage`.
Evidencia: `debug/rules_suite` con `guard_split`, `guard_factors`, `guard_leash`, `guard_release`, `guard_action` y `guard_selection` en PASS; `debug/guardian_altar.tscn` (a ~20 s Guard1 800 / Guard2 182) y `debug/guardian_manalith.tscn` (la vida del Manalith solo regenera: 2766 → 2780 → 2793 → 2805; el guardián recibe 29,7) con ventana (`agent/flows/f63_guardian_altar.json`, `f63_guardian_look.json`, `f63_guardian_manalith.json`; capturas en `agent/out/f63/`); dedicado + dos clientes + un cliente tardío (`agent/run_f63_net.sh`, `agent/out/f63net/`): B y el tardío ven `post_path` y `GuardianTether`.

**F63 — review y playtest con ventana (2026-10-14): PASS, cerrado.** Review PASS con observaciones (`reviews/REVIEW-RFC-021b.md`); corregidos después el haz del cliente tardío (espera al puesto en vez de liberarse), la textura real `grdn` al caché con el dibujo de sacengine (`guardian_tether.gdshader`) y la reentrancia de `Health._deflect`. Playtest (`agent/out/pt63g/`): haz rojo-rosado de la criatura al altar (`f63_altar_13_close.png`) y a la cima del Manalith (`f63_manalith_01_beam_close.png`); `Guard1` atado queda lleno mientras `Guard2` libre baja a 176; la vida del Manalith deja de bajar; «Blanco inválido» y «Lejos de un edificio propio» en pantalla; en red B y el cliente tardío ven el haz (`net/f63_net_b0_beam.png`, `net/f63_net_c0_late_beam.png`); 0 errores. `attack_factor` vale 1 en los clientes porque solo lo usa el servidor. Sin probar en ventana: «Fuera de alcance», que la guardiana salga de la selección, y su muerte con el haz retirándose en red (solo suite).

### F64 — Teleport (RFC-021c)
El mago salta a un edificio propio y se lleva a las criaturas de su bando que tiene cerca.

Criterio: `spell_5` de Estructuras y un clic sobre un Manalith o altar propio en pie, a cualquier distancia: al terminar el casteo (1,23 s) el mago y sus criaturas a 30 m o menos aparecen a 30 m del edificio, del lado desde el que venían y con la misma formación. Cuesta 800 de maná y enfría 15 s más el casteo. No viajan guardianas, criaturas a más de 30 m, doctores ni muertas (ni cautivas, desvío declarado). Otro blanco: «Blanco inválido». Mago muerto a mitad de casteo: nadie se mueve. Si el edificio cae a mitad de casteo el salto ocurre al último destino. Los dos clientes ven el salto sin que el cuerpo cruce el mapa y el efecto en origen y destino.

Hecho: `TeleportAction` (`tag elet`, `OWN_BUILDING`, hijo `Actions/Teleport` de `wizard_body.tscn`; `target_groups` `["structure", "altar"]`), `TeleportMath` (cuentas puras, `scenes/world/spells/actions/teleport_math.gd`), `warp_to(point)` en `UnitBody` y `WizardBody` (cuerpo en el suelo del terreno, sin velocidad ni meta; la criatura pierde la orden salvo guardia o retirada, `UnitOrders.warped()`), `WarpSnap` (hijo de `unit.tscn` y `wizard_body.tscn`: el servidor avisa y el cliente apaga la interpolación de `MpReplicate` 0,6 s con su `interpolate_speed`, sin tocar el addon), y el efecto `TeleportRings` (`scenes/fx/teleport_rings.tscn`, anillos del átlas `brng` del instalador local por `tools/export_particles.py`) más las partículas `teleport_out` / `teleport_in` (`data/fx/`, átlas `heal`, 50 partículas). Números en `MatchRules` grupo «Teleport» con cita a `state.d`; radio y distancia son `SpellType.effect_range` (30). Sin sonido (`elet`) todavía.
Evidencia: `debug/rules_suite` con `teleport_landing`, `teleport_offsets`, `teleport_carry`, `teleport_action` y `teleport_cast` en PASS; `debug/teleport_home.tscn` con ventana (`agent/flows/f64_teleport.json`, `agent/harness/teleport_watch.gd`; capturas en `agent/out/f64/`): el mago pasa de 80,0 a 30,0 m del altar, Pack1..3 conservan su distancia al mago (6,2 / 7,6 / 8,4) y quedan a 30,7 / 25,6 / 37,8 m, Stray no se mueve; dedicado + dos clientes (`agent/run_f64_net.sh`, `agent/out/f64net/`): A y B ven el salto de 50 m en un solo cuadro y B ve el efecto en origen y destino.

**F64 — review y playtest con ventana (2026-10-14): PASS, cerrado.** Review PASS con observaciones (`reviews/REVIEW-RFC-021c.md`; bajo ritual Teleport no libera del drenaje, como sacengine). Playtest (`agent/out/pt64t/`): el mago pasa de 80 a 30 m del altar y `Pack1..3` conservan la formación sobre el terreno, `Stray` no se mueve, maná 1000 → 200 y «Enfriando»; destellos y anillos en origen y destino (`f64_0_origin.png`, `f64_1_destination.png`, `f64_2_formation.png`); «Sin maná» (`m_lowmana.png`). En red B ve un salto de 50 m en un cuadro, sin deslizar, con el efecto en los dos extremos (`net/`). 0 errores. Sin ver en ventana: «Blanco inválido» (sin edificio enemigo en la escena; un clic fuera de un edificio da «Sin blanco») y que una guardiana no viaje (no alcanza el maná para Guardian + Teleport; solo suite). Observaciones abiertas: una criatura en `SUMMONING` viaja; restaurar `interpolate_speed` en `WarpSnap._exit_tree`.

### Playtests del 2026-10-13, tercera tanda (corrección de F58 y F62)
Con ventana. Flows `agent/flows/pt63_*.json`, lanzador `agent/run_pt63.sh`, capturas en `agent/out/pt63/`. Todas las corridas válidas terminan en `AGENT_OK` sin `ERROR`. El orquestador miró la captura del doctor.

- **Corrección de F58 — PASS. F58 queda cerrado.** `pt63/pt58_e1_close.png`, mismo ángulo que la captura que había fallado: el doctor se ve de pie, con los pies en el suelo, sombra y barra de vida, animado. Un clic sobre el centro del cuerpo visible acepta el blanco a la primera (`%Battle` = «Rock», vida 400 → 0). Los 4 Druids lo matan en 4,0 a 4,5 s desde la orden (400, 314, 229, 156, 73, 0). Cae erguido y aterriza de pie. No queda cadáver ni alma. Sin ver: el doctor caminando; una captura limpia bajo ataque (lo tapa el mago). A mirar: queda un rectángulo rojo chico donde murió (`pt63_a4_final.png`), posible barra de vida sin limpiar.
- **F62 — PASS. Cerrado.** En solo: «Elegí el suelo» → «Manalith», `Structure1` con vida máxima 3000, maná 1000 → 200, y la vida baja 3000 → 2881 → 2765 por el Ranger enemigo (`pt63_s1_appears.png`). `spell_2` a `spell_5` decían «No implementado» (hoy solo cambia lo que F63 y F64 implementan) (`pt63_s_noimpl.png`). Con dedicado y dos clientes la vida baja a la par: 2880,6 / 2881,0 y 2763,8 / 2764,1.
- Con esto quedan cerrados con playtest: F46, F47, F48, F57 (como maquinaria de cierre), F58 y F62. F53 cerrado para magos y criaturas de suelo; voladoras pendientes de vista lateral.

### F52 — Suelo suavizado y lightmap del mapa (RFC-019a)
El terreno ya no muestra los triángulos: las laderas se leen como una superficie continua.

Criterio: en `res://scenes/world/high_noon.tscn` (o `res://debug/biome_pick.tscn` para un bioma fijo), con `move_forward` y la cámara, las laderas no muestran facetas triangulares y el borde contra el acantilado sigue neto. En el editor, destildar `Terrain.smooth_ground` vuelve al facetado en el momento; `light_base` y `light_gain` (grupo «Light map» de `Terrain`) cambian el brillo del suelo en vivo.

Hecho (review con una corrección aplicada; playtest con ventana pendiente): `terrain.gd` iguala la normal de los vértices de suelo que comparten posición, como `generateNormals` de sacengine (`sacmap.d:720-744`: suma de productos cruz ponderada por área); las paredes conservan su normal plana. Sonda `debug/terrain_normals_probe.gd`: 3 174 posiciones de suelo, antes 29 con normal única, ahora 3 174; paredes planas 1 016 de 1 016; con `smooth_ground` apagado vuelve a 29. Colisión, `ground_height` e `is_on_ground` idénticos (220 puntos). `sacrifice_ground.gdshader` muestreaba el lightmap con `VERTEX` en espacio de vista y leía casi siempre negro: ahora usa la coordenada de mapa del vértice (no depende de la cámara ni del recentrado de la vista previa del editor). Las dos constantes pasaron a `light_base` 0,3 y `light_gain` 0,55, elegidas para conservar el brillo anterior (queda entre 1 y 7 % más claro). Review: `reviews/REVIEW-RFC-019a.md`; su bloqueante (los dos valores no eran editables porque el material se regenera del caché) lo corrigió el orquestador con dos `@export_range` en `Terrain` que sobreviven al cambio de bioma. Capturas del developer con ventana (pyro): las facetas desaparecen en laderas y crestas; sin costuras ni manchas nuevas. El paso del lightmap casi no se nota: en este mapa es casi blanco en tierra firme. Visto en las capturas y previo a este corte: un rectángulo negro grande delante del cielo desde ciertos ángulos, sin identificar.

### F59 — Desecrate: casteo, vórtice y portador (RFC-020c)
La casilla de Desecrate funciona: el doctor cae del vórtice, toma a la criatura elegida y la lleva en un portal, unida por una cuerda, hasta el altar enemigo.

Criterio: en `res://debug/desecrate_carry.tscn`, clic en `%StructureTab`, `spell_4` (`%Battle` dice «Elegí tu criatura») y clic sobre `Offering` (`%Battle` dice «Desecrate»). Durante ~5,5 s se ve un vórtice rojo en lo alto; al terminar cae `Doctor1`, toma a la criatura y la lleva suspendida dentro de un aro azul, unida por una cuerda luminosa, hasta quedar a menos de 20 m del altar enemigo. El altar sigue en pie y no hay resultado: el ritual es 020d.

Hecho (review y playtest con ventana PASS): `DesecrateAction` (`pick = OWN_UNIT`) como hijo de `Caster/Actions`; `SacrificeSystem` (`scenes/world/sacrifice/`) valida en el servidor (criatura propia y viva, altar enemigo en pie a 75 m o menos del mago, alcance 20), abre el vórtice y, al terminar el casteo, spawnea el portador; `CarryErrand` con sus pasos como nodos de estado (`Approach`, `Haul`); `Captive` en `unit.tscn` (`Mode.HELD`: sin órdenes, sin selección, sin colisión, a 3,5 m de altura y 2,7 m detrás). Se borró `scenes/world/desecration/` y el Desecrate viejo de `caster.gd` y `match_command.gd`. Si el doctor muere en cualquier paso, o cae el altar, la criatura queda viva y libre. Efectos (solo presentación, nada en el dedicado): aro `PortalDisc` y cuerda `Tether` con resorte (`scenes/fx/`), `CarryRope` en `doctor.tscn`, vórtice rojo con sus gotas; texturas `ltn2`, `vtx1`, `vtx2`, `vtx3`, `cst0` sumadas a `tools/export_particles.py`; `DoctorBody.carried` replicado para que cada cliente sepa a quién lleva. Números de sacengine con su cita; en la instancia del doctor se bajó el brillo de la cuerda a 0,6, el codo a 1 m y el punto de la jeringa (`Needle`, estimado: el port no tiene esqueleto), y a la mitad las gotas del vórtice, por legibilidad. Reviews: `reviews/REVIEW-RFC-020c.md`. Playtest (`agent/flows/pt59b_*.json`, capturas en `agent/out/pt59b/`): en la secuencia lateral se ven el aro azul alrededor de la criatura y la cuerda curva hasta el doctor, con la criatura 3,5 m por encima y unos 3,3 m detrás; llegada a 19,99 m del altar con el altar en pie y sin cartel; la criatura tomada no se selecciona; clic en el suelo o en el mago da «Sin blanco» sin gastar maná. Con dedicado y dos clientes, el rival ve el aro y la cuerda desde su ventana y recibe `carried`; al matar al doctor con Rock el aro se cierra, la cuerda desaparece y la criatura cae viva, vuelve a seleccionarse y obedece una orden. Pendiente: la criatura va en pose de reposo (los clips `thrash` / `rise` no están exportados); sin referencia visual del original para comparar los efectos; el modelo del doctor queda corrido respecto de su cápsula y cuesta apuntarle en movimiento; un mago no puede atacar a su propio doctor (es aliado); la criatura tomada es invulnerable; segundo Desecrate con otro en curso, sin probar.

**F52 — playtest con ventana (2026-10-13): PASS, cerrado.** En `biome_pick.tscn` la ladera se ve continua, sin facetas ni costuras, y el brillo no está lavado (`agent/out/pt59b/terrain/t3_walk2.png`, `t5_zoomout.png`); en `hole_edge.tscn` el borde contra el vacío es neto (`c3_borde_giro.png`). Visto de paso y ajeno al suelo: el rectángulo negro delante del cielo es la cara inferior sin luz de la losa del altar; en `hole_edge` se ve un disco naranja liso bajo el acantilado y terreno lejano invertido sobre el horizonte; hay manchas oscuras ovaladas en el suelo sin identificar. Van a la base de iluminación de RFC-022.

### F60 — El ritual: rondas, drenaje, cancelación y victoria (RFC-020d)
La victoria se consigue profanando el altar rival: el ritual drena al mago enemigo hasta matarlo y esa muerte destruye su altar.

Criterio: con el dedicado y dos clientes en `--world=res://debug/desecrate_ritual.tscn`, el cliente A (slot 1) hace clic en `%StructureTab`, `spell_4` y clic sobre `Offering`. Sin más intervención: el portador llega al altar enemigo, aparecen 4 doctores en anillo, B ve «Están profanando tu altar», la vida del mago 2 baja por rondas, el mago muere, su altar se derrumba y unos 55 a 60 s después del clic A ve «Victoria» y B «Derrota». En `res://debug/ritual_push.tscn` (cuatro Druids enemigos) y `res://debug/ritual_cancel.tscn` (ocho Rangers enemigos) el ritual se cancela: «Ritual interrumpido», 0 doctores, `Offering` viva y libre, altar en pie, sin cartel de resultado.

Hecho y cerrado (review PASS; playtest con ventana PASS, ver abajo): `Ritual` (`scenes/world/sacrifice/ritual.tscn`, spawneado, con `phase`, `round_index` y `outcome` replicados) y sus fases como nodos de estado (`Setup`, `Walk`, `Shoot`, `Wait`); `SacrificeSystem.start_ritual` ocupa el `RitualSite`, cambia al portador por 4 doctores (`ritual_doctor.tscn`) a 20 m en 45° + 90°·k y sube a la criatura 15 m sobre el altar; una cola hace esperar a un segundo portador. Preparación 5 s y rondas de 13,5 s; en la ventana de disparo se drenan `200·(1+almas)` de vida (daño crudo, sin resistencias, como `dealDesecrationDamage`) y `40·(1+almas)` de maná. Sin tope de rondas. Si muere cualquiera de los 4 doctores, se pierde la criatura o cae el altar, se cancela: mueren los 4, la criatura queda viva y libre y el mago deja de estar bajo ritual. Al morir el mago bajo ritual se usa la maquinaria de F57 (`begin_altar_collapse`, `DefeatRule`, cartel); la criatura se desintegra y sus almas vuelven al lanzador. `RitualPush` empuja hacia afuera lo que esté dentro del radio; `RitualFx` (vórtice sobre el mago, rayos del altar y de profanación, marcados «estimado») y `RitualNotice` («Están profanando tu altar», «Ritual interrumpido», «Altar profanado») son solo presentación. Un mago en fantasma vuelve al cuerpo al empezar el ritual. **Decisión del usuario (2026-10-13): el empuje usa los valores exactos de sacengine (20 m, 0 en el borde), así que los cuerpo a cuerpo pueden llegar a un doctor y cancelar el ritual**, aunque el ReadMe del original hable de una barrera; la variante con barrera (24 m, 15 m/s) queda en `debug/rules/ritual_barrier.tres` y `debug/ritual_barrier.tscn`. Review: `reviews/REVIEW-RFC-020d.md`. Evidencia del reviewer en red (dedicado + 2 clientes headless): profanación completa con las mismas fases, drenaje (1500 → 1100 en la primera ronda) y ganador en los tres procesos, «Victoria» en A, «Derrota» en B y nada en el dedicado; cancelación por tiradores con `outcome` abortado, 0 doctores, criatura libre y altar en pie en los tres; con la regla actual cuatro Druids cancelan el ritual. Sin probar: un hechizo real del rival contra un doctor del ritual; segundo portador y cliente tardío fuera de las sondas del developer. A decidir aparte: si el mago blanco no existe (jugador desconectado) el ritual completa tras la primera ronda, como en sacengine; el dueño del altar no ve «Ritual interrumpido» al cancelarse.

**F60 — playtest con ventana (2026-10-14): PASS, cerrado.** Profanación completa con dedicado y dos clientes (`bash agent/run_pt60.sh <puerto>`): preparación, dos rondas de disparo, el mago 2 muere en la segunda, «Altar profanado», derrumbe, A «Victoria» (`agent/out/pt60/a310_hud.png`) y B «Derrota» (`b90_resultado.png`); B ve «Están profanando tu altar» y su vida bajando; 0 errores. Cancelación en solo: `ritual_push` (Druids) y `ritual_cancel` (Rangers) terminan en `outcome` abortado, «Ritual interrumpido» en pantalla (`agent/out/pt60c/push112.png`, `canc108.png`), 0 doctores, `Offering` libre, altar en pie y sin resultado. Corregido en las escenas de prueba: con `Start2` movido el mago 2 aparecía sobre un pilar de su altar (`Start2.wizard_distance = 12`), y las escenas de cancelación ahora traen un `TargetWizard` fijo y los enemigos a 55 m. Sin ver en captura: los doctores a la distancia de juego (son pocos píxeles) y el golpe a un doctor; el vórtice sobre el mago 2. Sin probar: un hechizo real del rival contra un doctor. Pendiente: si un inicio queda con su punto de aparición sobre un pilar, `WizardBody._seat()` asienta al mago encima (avisar en el editor o asentar sobre el terreno).


### F61 — Convert fiel (RFC-020e)
Convert (`ccas`, pestaña Estructuras) ya es el del original: no toma un alma, la convierte. Un Sac Doctor cae de un vórtice junto al cadáver, camina hasta él, lo bombea `(almas+1)·5` s (la criatura revive con `max(400, 50 %)` de su vida máxima y nadie la puede atacar), la levanta y la lleva en su aro azul hasta el altar propio más cercano al mago; ahí cuatro doctores hacen el ritual (`int(vidaMáx/550) + 1` rondas de 13,5 s) y al final la criatura se desintegra y sus almas se suman al contador del mago.

Criterio: en `res://debug/convert_ritual.tscn` (solo, un proceso: Convert no tiene mago blanco, el blanco es la criatura), `Killer1/2` matan a `Victim` y aparece un alma roja; clic en `%StructureTab`, `spell_3` (`%Battle` dice «Elegí un alma roja») y clic sobre el alma (`%Battle` dice «Convert»): «Almas 0» pasa a «Almas 1» unos 50 s después del clic y `Victim` ya no está. En `convert_pump_kill.tscn` los guardias matan al doctor mientras bombea: la criatura muere otra vez, el alma roja reaparece y sigue «Almas 0». En `convert_carry_kill.tscn` lo matan mientras la lleva: la criatura cae viva, `owner_slot` 2, en el grupo `unit`. Si el doctor muere antes de llegar, el alma sigue roja y convertible (caso `convert_doctor_dies` de la suite).

Hecho y cerrado (review PASS con observaciones, `reviews/REVIEW-RFC-020e.md`; playtest con ventana PASS, ver abajo): `ConvertAction` (`pick = SOUL`) en `Caster/Actions`; `SacrificeSystem` valida (altar propio en pie, alma roja convertible a 20 m o menos), abre el vórtice pasada el alma y reserva el alma (`Soul.reserve_for`, `convertSideMask` de sacengine); `CarryErrand` con `Kind` de `Ritual` y el paso `Pump` (`errand_states/pump.gd`) más la rama Convert de `Approach`; `Captive.revive()` / `die_again()`, `Corpse.stand_up()`, `UnitBody.Mode.REVIVING` (al final del enum) y `Soul.State.REVIVING`; `Ritual.Kind.CONVERT` (sin mago blanco, fin por `Ritual.is_last_round()`). Se borraron `souls/sac_doctor.*`, `request_convert` y los doctores de `SoulSystem`, `_convert_soul` de `caster.gd` y la rama `CONVERT` de `match_command.gd`. Números en `MatchRules` (grupo «Sacrificios», `# 020e`): `convert_reach` 2 m, `convert_pump_s_per_soul` 5, `convert_revive_min_health` 400, `convert_revive_fraction` 0,5, `convert_health_per_round` 550.

**F61 — playtest con ventana (2026-10-14): PASS, cerrado.** Solo: `convert_ritual` llega a «Almas 1» unos 51 s después del clic (bombeo con `REVIVING` y 400 de vida, acarreo, ritual `kind=1` de 2 rondas, sin carteles; `agent/out/pt61b/c02_alma_roja.png`, `k04_camino_3.png`, `close/r_c11_ritual.png`, `c13_fin.png`); `convert_pump_kill`: el alma roja del bando 2 vuelve (`p05_alma_vuelve.png`); `convert_carry_kill`: la criatura cae viva y del bando 2. En red (dedicado + A + B, B entra durante el bombeo): A «Almas 1», B ve bombeo, acarreo y ritual; 0 errores. Confirmada la limitación de escena: la `Victim` puesta a mano queda como copia colgada en los clientes. Sin ver en captura: los 4 doctores del ritual (oscuros y chicos bajo la losa) y el bombeo (captura muy oscura): va a la luz de RFC-022. Sin probar: entrada tardía durante el acarreo; `pump_kill` y `carry_kill` en red. Sin hacer: clips `SDpm`/`SDpu`, sonido `convertRevive`.

Dos errores heredados de F38 que se corrigieron porque sin ellos no se podía jugar: el `Target` del alma era un `Area3D` y el raycast del puntero no colisiona con áreas (ahora `StaticBody3D` con una cápsula que cubre el cadáver y el sprite, 2 m más arriba); y `SoulSystem` no vigilaba las unidades puestas en la escena a mano (ahora las busca con `call_deferred`).

Sin hacer: clips `SDpm` (bombeo) y `SDpu` (levantar), sonido `convertRevive`, el `revive` de la criatura se anima con la caída al revés (`Corpse.stand_s`). Las unidades puestas a mano en una escena de prueba no se borran en los clientes cuando el servidor las libera (el doctor, el ritual y el alma sí): en juego las criaturas nacen del spawner.

### F65 — Andamiaje y medición del remaster (RFC-022a)
Base del remaster visual: perfiles de look por dios, `Environment` en `.tres`, presets de calidad con escala de render, galería y banco. No cambia nada visible.

Hecho y cerrado (review: un bloqueante, corregido: los cinco `LookProfile` estaban vacíos y no cargaban; `reviews/REVIEW-RFC-022a.md`): `scenes/world/look/` (`LookProfile`, `LookQuality`, `QualityApplier`, `LookApplier`, `LookRig`), `data/look/` (`env_base.tres`, `quality_{low,medium,high}.tres`, un perfil por dios), `debug/look_gallery.tscn` (F1 bioma, F2 cámara, F3 calidad) y `debug/look_bench.tscn` (`--units=`, `--quick`, `--capture`; por defecto sin cuerpos). Captura clásica idéntica a la previa (0 % en `ref`, `rts`, `horizonte`). Línea de base en RFC-022 «Medido en 022a»: medio 0,67 con reescalado espacial ≈ 4,9 ± 1 ms de GPU; los modos temporales (FSR 2, MetalFX temporal) dejan restos alrededor de cuerpos animados y se descartan. En Metal `viewport_get_measured_render_time_gpu` da 0: el banco estima con 9 vistas. Sin playtest con ventana propio: no hay nada visible que probar; el diff de capturas lo cubre. Hallazgo: 60 cuerpos animados dan 5 fps y ~7,7 GB de video (en investigación aparte).

### F66 — Rendimiento de cuerpos animados (arreglo, sin RFC)
Con 60 cuerpos animados el juego daba 5 fps y ~7,6 GB de video.

Hecho y cerrado (review PASS, `reviews/REVIEW-perf-bodies.md`; playtest con ventana PASS): `ObjMesh` cachea materiales y texturas de forma estática (antes uno por superficie y por malla, ~110 MB por cuerpo); `ClipPosePlayer` comparte las mallas por cuadro de clip entre todos los cuerpos y en headless no las construye (el reloj del clip sigue); `BodySeparation.resolve` sin asignaciones por par, misma lógica y mismo orden de `randi()`. Medido con ventana a 2560×1440 (`agent/out/ptperf/bench_*.log`): 60 cuerpos en medio 8,3 ms (tope de 120 Hz) y 330 MB; en alto 10,6 ms y 501 MB; draw calls 755 → 110. Aspecto igual: dos bandos del mismo modelo sin contagio (`ptperf/side_a.png`), fantasma translúcido solo él (`ptperf/ghost/pt31_02_ghost.png`), cautiva y doctor como antes; red sin errores. Sonda `agent/perf/perf_probe.tscn` (N cuerpos, `--shot=`). Pendiente: `BodySeparation` sigue siendo O(N²) (~7 ms por tick con 60; con ~150 vuelve a ser el cuello; una grilla espacial cambiaría los desempates); las cachés estáticas no se invalidan al re-hornear con el editor abierto; `ghost_form` duplica materiales por cuadro de clip.

### F67 — Luz base del remaster (RFC-022b)
Capa de luz por bioma, apagable y editable: sol, sombras PSSM con penumbra, relleno, ambiente, AgX, SSAO; SSIL solo en alto.

Hecho y cerrado (review FAIL por la volumétrica con densidad por defecto, corregido; `reviews/REVIEW-RFC-022b.md`; playtest con ventana PASS): `LookLayer`, `LightLook` (`scenes/world/look/light/`), `data/look/light/*_light.tres` (Persephone afinado; densidad volumétrica 0,01 en los cinco), `fill_light.tscn`, `quality_medium.tres` por defecto en `high_noon.tscn`; los 5 `GodTheme` referencian su `LookProfile` (cambia el look de todas las partidas; `look = null` vuelve al clásico). Costo (método 022a, ±1 ms): medio +0,5; alto +5,7, de los que SSIL son ~3,5 (alto sin SSIL +2,1). Doctores bajo la losa: luminancia 0,011 → 0,153. Playtest (`agent/out/pt22b/`): galería recorre dioses, cámaras y presets; Persephone sin velo y sin negros (`p_on.png` vs `p_off.png`); partida normal sin errores; bombeo y doctores legibles en sombra lila (`c06_bombea.png`, `r_c11_ritual.png`); los 4 dioses restantes legibles (`god_*.png`). Reservas: suelo pálido (nieve de Stratos casi blanca y plana, desierto rosado): es el atlas actual, lo reemplaza 022c; columna del altar blanca y saturada (calibrar en 022h); la galería clásica imprime `capas 1` aunque se vea clásica.

### F68 — Terreno PBR de la pradera (RFC-022c) y terreno de doble cara
Suelo PBR por capas para Persephone; el terreno se ve desde ambos lados.

Hecho y cerrado (review PASS con observaciones, `reviews/REVIEW-RFC-022c.md`; playtest con ventana PASS): `GroundLayer`, `GroundSet`, `TileLayerMap`, `ground_pbr.gdshader` (4 capas por zona del mapa, pendiente, altitud y altura; roca triplanar; macro-variación; estocástico de I. Quilez, MIT con su texto), `ground_material.gd`, `TerrainLayer` en el `LookRig`; 4 materiales ambientCG 2K CC0 por LFS (Grass004, Ground103, Rock051, Ground108; ~92 MB; `assets/cc0/LICENSES.md`; `.import` versionados con VRAM comprimida y mipmaps). Perilla `patch_softness` para el borde de los parches. El dedicado ya no carga el `LookProfile` al sortear el bioma (`ThemeApplier.pick_god`). Costo: medio luz + suelo 7,5 ms; alto 22,2 ms (estocástico a resolución nativa). **Doble cara (reporte del usuario: «hay caras del terreno que no se ven»):** `render_mode cull_disabled` en `sacrifice_ground.gdshader` y `ground_pbr.gdshader` (este invierte `NORMAL` en caras traseras). Playtest (`agent/out/pt22c/`): valle con pasto variado y parches suaves (`w00.png`), loma con roca (`w04.png`), laderas vistas desde atrás sólidas (`h01_atras.png`, `h04_atras.png`), borde del mapa desde afuera sólido con ambos suelos (`back_pbr.png`, `back_classic.png`), otros dioses sin cambios, tres calidades coherentes. Pendiente: la pared del borde con PBR se ve con vetas verticales estiradas (usar triplanar en paredes); falta probar un pozo con la cámara de juego; pulido del look con `studio-visual`; 022j hace los `GroundSet` de los otros biomas.

### F69 — Cielo del remaster: legacy fiel y Swirl experimental (RFC-022d)
El cielo visible es el del original (modo Legacy) en los cinco dioses; el cielo nuevo por shader (Swirl) queda como experimento.

Hecho y cerrado (review FAIL por capas encima del Legacy, corregido; `reviews/REVIEW-RFC-022d.md`; playtest con ventana PASS): `scenes/world/look/sky/` (`SkyLook` con `sky_mode` Legacy/Swirl, `SkyLayer` sobre copia del env con restauración, `sky_swirl.*`, `sky_discs.*` solo en Swirl), `data/look/sky/*_sky.tres` (todos Legacy, sin halo, sol ni luna). Ambiente y reflejos desde un `Environment.sky` procedural que no se ve; la niebla de distancia toma el color del horizonte del bioma (`fog_horizon_mix`). Se borraron las nubes con volumen y los haces rechazados por el usuario. Decisiones del usuario: conservar el cielo original (§17.6), cielo nuevo opcional + legacy (§17.7), sin criterio de rendimiento para Legacy (§17.8). Playtest (`agent/out/pt22d/`): los 5 cielos son los del original y se mueven (`M_gods_hor.png`, `M_move.png`); horizonte fundido salvo Charnel (terreno gris contra banda turquesa); partida sin errores ni costuras; clásico intacto (`M_classic_hor.png`). Observaciones para el pase de paleta: con el look encendido el cielo se ve más lavado que en clásico (AgX/exposición/glow); en Persephone el sol del propio cielo legacy aparece con anillos y bloom; el Swirl no se parece al original (borroso en Persephone, celdas en Pyro). Pendiente: medir Swirl y nubes volumétricas (pedido del usuario).


### F71 — Semilla y banco IA contra IA (RFC-024, corte 024a)
Partida reproducible con `match_seed`, corredor `debug/ai_match` sin ventana e informe JSON con `digest`. Sin IA.

Hecho y cerrado (review PASS con nits N1/N2, aplicados; `reviews/REVIEW-RFC-024a.md`; playtest con ventana: el digest con ventana difería del headless porque el cadáver caía con un tween de render y el alma nacía según los fps; corregido pasando los tweens de simulación a física; digest seed 7 con ventana = headless en 4+2 corridas; `agent/out/pt024a/`). `MatchRules.match_seed` (0 = se sortea y se imprime `semilla <n>`) y `MatchSeed` (`HighNoon._enter_tree` lo abre en quien simula): siembra `UnitBody`, `GhostForm`, `GuardianTether`, `MatchBiome` (si `biome_seed` es 0) y el desempate de `BodySeparation` (generador propio, ya no `randi()` global); `seed()` global también. Corredor `debug/ai_match.tscn/.gd` + `AiAudit` (registro de eventos, posiciones a 0,1 m cada 60 s y al final, libro de almas por bando, `digest` sha256) y `debug/rules/ai_duel_seeded.tres` (`BenchRules`: 6 Trogg contra 6 Druid a 60 m, en pausa «Pendiente» con ventana). Medido: `--seed=7 --minutes=2` dos veces = mismo `digest`; `--seed=8` otro; 3,4 s reales y 206 MB de RSS; `rules_suite` PASS; `f26_duel` y `f27_orders` AGENT_OK. La pelea termina por aniquilación a los ~54 s, no a los 2 min. Falta el playtest con ventana (`agent/flows/pt024a_smoke.json` es solo un humo).

### F72 — Navegación, visión y elección de blanco (RFC-024, corte 024b)

> **Reemplazado (2026-10-18, RFC-035 035h/035i):** la grilla `NavGrid` se borró; la navegación es el navmesh de Godot (F201–F203).
Pathfinding en grilla (también para el jugador), visión por bando y puntaje de blanco de `updateTarget`.

Hecho y cerrado (review: B1 jitter de guardia por blancos vistos por el bando fuera de la vista de la unidad, corregido con desvío documentado; `reviews/REVIEW-RFC-024b.md`; playtest con ventana PASS en cruce, mago, blanco, guardia, escolta y red (f78, pt60), `agent/out/pt72/`). Deuda fuera de F72: con 150 unidades, 13–17 Manahoar quedan trabadas por apiñamiento (pasa igual sin PathFollower); el mago empuja a sus criaturas al atravesar la fila; el servidor loguea «Unable to send packet» al publicar picks a un peer que ya se fue (`_on_peer_disconnected` → `_publish_picks`); los edificios construidos después de armar la grilla no la bloquean (024c). `scenes/world/nav/` (`NavGrid`: 512×512 nodos de 5 m desde `Terrain.ground_cell_counts()`, bloqueos = cilindros de colisión de manantiales y altares + 1,5 m, componentes 4-conexos por tramos y A* con `AStarGrid2D` sin cortar esquinas más enderezado; `NavService` = `%Nav` en `high_noon`, arma la grilla una vez, tope de 3 búsquedas por tick; `PathFollower` hijo de `unit.tscn` y `wizard_body.tscn`: `go_to` para órdenes y `steer_point` para la persecución, `@export repath_s` 2 s, `arrive_m`, `advance_m`), `scenes/world/vision/side_vision.gd` (`%Vision`: último tick visto por bando y entidad, 384 ticks para criaturas y marca permanente para estructuras, un observador por bando por tick, el golpeado ve a quien lo golpea; sin campo de visión ni línea de vista: «aprox.») y `scenes/world/units/target_picker.gd` (hijo de `unit.tscn`: puntaje de `updateTarget`, filtrado por visible para el bando; `UnitBody.closest_foe` delega en él). `UnitBody.walk_to`/`WizardBody.walk_to` (orden con camino) y `begin_walk` (un tramo recto); `UnitOrders` usa `walk_to`; `UnitBody.is_valid_foe_of` estático compartido. Escenas `debug/nav_cross.tscn` (+ `nav_cross.gd`, `--grid-png=`, `--overview`, `--time-scale=`), `debug/nav_wizard.tscn` (mago 2 de `match_defeat` hacia el Druid; `--nofollow` reproduce el atasco de F57, `--aggro`) y `debug/target_pick.tscn`; casos `target_score_*`, `target_pick_*`, `target_vision_*`, `nav_*` en `debug/rules_suite` (`debug/target_cases.gd`, `debug/nav_cases.gd`; la suite ahora termina sola en headless). Medido y comandos en el informe del developer; el `digest` de `ai_match` seed 7 cambia respecto de F71 (el blanco ahora sale del puntaje).

### F73 — Poblados y NPC (RFC-024 adenda, corte 024b2)
26 Farmers pasivos, 6 Taurocks y 69 edificios neutrales de High Noon cargados desde el mapa; campesinos que se encogen y huyen; almas al morir, obtenidas con Convert.

Hecho y cerrado (review: B1 criterios del RFC corregidos a lo medido, B2 red con cliente tardío verificada; `reviews/REVIEW-RFC-024b2.md`; playtest con ventana PASS en aldea real, huida/encogerse, alma roja + Convert, casa derribada y red; Taurock corregido aislando la escena: elige a Hunter a 70 m y pelea, `agent/out/pt73w/`). Deuda: los Sac Doctors no tienen pathfinding (Convert lejos del altar poco fiable; decisión del usuario para 024c); la casa desaparece sin animación de caída; los Farmers se ven diminutos dentro del pasto. `tools/export_high_noon_ntts.py` (NTTS de criaturas y estructuras + SIDS → `cache/high_noon_ntts.json`) y `tools/export_stats.py buildings` (BLDG de los 4 wads de edificios: vida máxima, bit de refugio y componentes → `cache/data/buildings.json`; modelos MRMM de `jamesmod.wad` → `cache/look/buildings/` y catálogo; `tools/bake_bodies.gd` ahora guarda también la caja `box` de cada malla para que un servidor sin mallas forme la misma colisión). `SideRelations` (matriz del SIDS: slot = bando + 1; jugadores 1 y 2, Farmers 3, Taurocks 4, casas neutrales 0 = bando 31 que no es enemigo de nadie; sin archivo o bando no descrito, «otro slot = enemigo»): `UnitBody.is_valid_foe_of` pide enemigo por postura a lo que elige solo y deja atacar a cualquiera que no sea del propio bando cuando hay una orden (`ordered`, como `isValidAttackTarget`); `SideColors` da gris a los bandos NPC. `MapBuilding` (modelo por componentes del BLDG, `Health` si la vida > 0, grupos `structure`/`map_building`/`shelter`, caja de colisión desde el `box` horneado, sincronizador de la vida si es destructible; vida 0 = indestructible y la consola lo dice) y `MapPopulation` (`%Population` en `high_noon.tscn`: primero edificios en todos los peers, después criaturas solo en servidor o solo, `spawn_creatures` apagado por defecto y encendido en `high_noon.tscn`; las 59 escenas de `debug/` y `agent/fixtures/` que no quieren NPC lo apagan; imprime `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`). `peasant.tscn` (heredada de `unit.tscn`) con `PeasantBehavior` (sin refugio a ≤ 50 m se encoge; con refugio huye del enemigo a ≤ 50 m; `shelter_distance`, `scare_distance` con cita y `flee_leg_m`, `think_interval_s` @export) y `GrudgeMemory` (rencor al primer golpe con vida llena, manada a ≤ 80 m cada 0,1 s); `UnitBody.Mode.COWER` (modo replicado, el modelo se agacha). `BodySeparation` con grilla espacial de 16 m (misma cuenta que el lazo de pares: el digest de `ai_match` seed 7 no cambió; solo cambia el desempate sembrado cuando se gastaba en pares lejanos) y `sep_ms` en el informe. Almas: `Soul.origin`, `SoulSystem.soul_collected`, `SacrificeSystem.souls_converted` y el libro de `AiAudit` (`collected` / `converted` separados, `by_origin.npc/creature/wizard`, `npc_kills`, `npc_alive_end`, `npc_spawned`, `buildings_placed`, `shelters`). `NavGrid` bloquea cajas orientadas (los edificios con colisión). Escenas `debug/village.tscn` (+ `village_cower`, `village_taurock`, rules `village*.tres`, `ai_no_souls.tres`, `ai_npc_load.tres`), casos `village_*` en `debug/rules_suite`. Medido y comandos en el informe del developer; REA no se usó (ver informe): refugios = 11 por el bit 15 del BLDG [DATOS], daño a cadáveres según [S]. Fuera de este corte: ataque de la IA a NPC y percepción (024c) y la prueba con el dedicado (necesita 2 procesos).

### F74 — Cerebro mínimo del mago IA (RFC-024, corte 024c)
La IA convoca, ataca y defiende; solo pide lo que puede pagar.

Hecho y cerrado (review sin bloqueantes, `reviews/REVIEW-RFC-024c.md`; playtest con ventana: el mago IA derivaba ~100 m al borde porque sus criaturas se apilaban a 2–3 m en guardia y BodySeparation lo empujaba; corregido con retreat a radio +10 m como `state.d:13608` (`retreat_hold_m`); el mago queda fijo 3 min con y sin ventana; NaN de GuardTask sin almas protegido (desvío, caso `ai_guard_no_nan`); banco con eventos anclados al altar/Manalith; `agent/out/pt74/`). Fiel a shiny.d y documentado: la guardia del mago no intercepta hacia adelante (pelea solo lo que entra en la vista del ancla); la IA usa posición/vida reales de enemigos no vistos para agrupar y apuntar (N1/N2 de la review, a decidir en 024e); la reconstrucción de la grilla por estructura cuesta ~50 ms (medir en 024d). `scenes/world/ai/`: `AiSide` (reloj de 6 ranuras 12/60/6/6/60/12, `forceFlags`, mide `ai_ms`; solo corre en solo o servidor), `AiPerception` (`scanGlobal` al inicio con los 32 NPC y el altar enemigo; propios por evento; enemigos solo al verlos por `SideVision.marked`; `unseen_leaks`), `AiGroups`, `AiStance` (amenaza del mago), `AiTaskBoard` con `IdleTask` y `GuardTask`, `AiWizardBrain` con `SummonPhase` (wizSacrifice) y `AttackPhase` (wizAttack), `CreatureBrain`, `AiCommandPort` (única salida: `Caster.request_*`, `Orders.apply_for`, `request_walk`), cuentas puras `AiRater`/`AiField`/`AiRand` (rand() de MSVC), `AiProfile` (`data/ai/profile_original.tres`, cada número con su cita de `shiny.d`, todo «según [S]»: ninguno verificado con REA), `AiSeat`. `AiAudit`: summons con maná y almas antes/después, casts, rechazos, `mana_in` por fuente, órdenes. Modificados: `Orders.apply_for(slot, …)` (sin renombrar `_formation`, `_own_units` ni `last_*`), `ManaPool.add(amount, source)` y señal `fed`, `SideVision.marked`, `NavService` (reconstruye la grilla al entrar o salir una estructura: Manalith), `CreatureType.drain`, `amount2` en `SpellType`/`AbilityType`, `BenchRules` (+`ai_seats`, `structures`, `events`, `probe`), `debug/ai_match.gd` (asientos IA, estructuras, eventos, `--events`). Escenas `debug/ai_summon.tscn`, `ai_defend.tscn`, `ai_defend_far.tscn`, `ai_no_souls.tscn` (+ `rules/*.tres`); 12 casos nuevos en `rules_suite` (`debug/ai_cases.gd`). Desvíos: sin Manalith propio el original no convoca (pool de maná = máximo × Manaliths, shiny.d:3140), así que las escenas parten con uno en FountWest; el original deja viejas las posiciones de los enemigos que no vio (updateBase), así que `ai_defend` pone los Druids a 150 m y la variante a 330 m mide la reacción a ciegas; los seguidores se detienen a 8 m del líder (el original usa 0 y los cuerpos del port se empujan); la IA no pide órdenes `advance`/`attack` a un pacifista (Manahoar), que el juego rechaza; no lee las almas del mago enemigo sin verlo. Fuera de 024c (024d–f): `CaptureTask`, `ManahoarBrain`, `ConvertPhase`, `SupportPhase`, recoger almas, `AiRoster`, dificultades, botón; Sac Doctors sin pathfinding.

### F75 — Economía, captura y profanación de la IA (RFC-024, corte 024d)
La IA captura manantiales, convierte almas y desecra el altar enemigo.

Hecho y cerrado (review NEEDS WORK: B1 SCRIPT ERROR por blancos liberados en `unit_orders.gd`, corregido; p99 de la IA 3,1 → 0,7–0,9 ms quitando repeticiones de órdenes; mago con prioridad de paso sobre su escolta (`BodySeparation.wizard_passes_own`, desvío del port) y `_check_jam` quitado; `reviews/REVIEW-RFC-024d.md`; playtest con ventana PASS en los 7 puntos, `agent/out/pt75w/`). Deuda: `debug/ai_convert.tscn` usa `ai_no_souls.tres` y quedó sin Farmers desde la adenda 1.2 (correr con `--npcs=1` o darle reglas propias); verificar si la IA relanza Convert sobre la misma alma (5 en 45 s); en escenas de IA el HUD muestra el mago local, no el de la IA; la cámara puede quedar dentro de una choza al retroceder contra ella; `farmer_in_sight` de `ai_summon` 57 s por caos de escena (review NEEDS WORK, `reviews/REVIEW-RFC-024d.md`: B1 corregido junto con el volumen de órdenes y los nits, ver «Corrección de la review» al final del párrafo; el developer sacó capturas con ventana en `agent/out/pt75/`). `scenes/world/ai/`: `CaptureTask` (manantial libre → Manalith, Manalith enemigo, altar enemigo con `territorialScore`; reclama con el tope de almas de shiny.d:2262; no porta la rama «cazar mago enemigo»), `ManahoarBrain` (`mahoBrain`), `ConvertPhase` (`wizRetreat`: Convert sobre almas rojas, NPC incluidas, a `(1−parte)·(1−amenaza)·500` m), `SupportPhase` (Heal y Speedup de los 5 libros en `AiSpellEval`), ruta de almas del mago (`findBestNear`, `(1−amenaza)·100+80` m, `AiPerception.find_best_near`), `autoCapture` (el cuerpo sin maná va al Manahoar o edificio), bloque cmd 2 del mago (`castCachedInRange`, `pickGuardCreature` + Desecrate forzado), fantasma (espera Manahoars a 256 m o va al edificio de maná, desvío de sacengine), `GuardTask` con el altar bajo profanación (1.0). `ai_side_trivial.tscn` (sin captura, ataque, apoyo ni conversión: convoca y se queda; copia del `ai_side.tscn`, Godot no deja borrar nodos heredados) y `AiSeat.side_scene`. Doctores con camino: `DoctorBody.walk_to` usa un `PathFollower` hijo de `carrier_doctor.tscn` (los de la ronda del ritual no: están dentro de lo que la grilla bloquea); `StuckGuard` reinicia la medida cuando cambia el tramo. `NavGrid` guarda el terreno libre (reconstruir por estructura: 52 → 7 ms). `SideVision` marca los manantiales (sin eso la IA no se enteraba de que uno fue tomado); `SacrificeSystem.desecration_against/by`. Banco: `debug/rules/ai_vs_trivial.tres` (+ `debug/ai_vs_trivial.tscn`), `ai_guard`, `ai_endgame`, `ai_convert`, `doctor_path` (caso de prueba del doctor con muro: PASS en 47,5 s, 196 m caminados; control `--nofollow` FALLA trabado en el muro), `ai_match` con `--checkpoints`, `end_reason = desecration`, manaliths/desecrations/npc_touched en el informe. Medido (headless `--fixed-fps 60`, semillas 1–5, 30 min): victoria por ritual 5/5 (12,8–16,2 min), primer Manalith a los 19,4 s, `npc_kills`@10 min 14–22, `by_origin.npc`@10 min 9–20, ninguna alma de NPC por contacto, libro exacto, sin rechazos; `ai_ms` medio 0,10–0,15 ms y p99 de la decisión 0,57–0,69 ms, pero p99 con las llamadas al juego 2,06–3,16 ms (no cumple ≤ 2 tal cual: lo dominan las órdenes con camino ~100 µs y la instanciación de las convocatorias); RSS ≤ 430 MB; 30 min en 2,8–7,6 min de reloj. Desvíos: WORKAROUND `AiWizardBrain._check_jam` (el mago rodeado por sus criaturas, cuerpos sólidos que no empuja, quedaba 7 min trabado: las aparta y las deja 2,4 s sin llamado), `next_run` de k3 y k5 con 3 y 6 ticks de retraso (reparte el pico del tick 60), `Orders.apply_for` pasa nodos sin ir por `NodePath`. Sin REA: todo «según [S]». **Corrección de la review (2026-10-15):** B1: `UnitOrders` ya no tipa blancos liberados (`_live`, `_guardable`/`_alive`/`_in_sight` reciben Variant; `_hold` lee el blanco del cuerpo como Variant): 0 `SCRIPT ERROR` en las 5 semillas (antes 25–152). Órdenes: medido por motivo (`ai_order_stats` en el informe): ~15 % son la misma orden exacta reemitida porque la viva terminó (sacengine también la reemite, se deja) y ~60 % la misma orden con el punto corrido < 3 m (seguidores tras el ancla móvil del líder); lo caro no era el `print` sino que cada repetición pensaba en el acto (una búsqueda de blanco ~120 µs dentro del tick de la IA y otra en el tick siguiente). `UnitOrders.give` con la misma orden (GUARD/GUARD_AREA/ADVANCE, mismo blanco) solo toma el punto nuevo y piensa una vez en su próximo tick físico (`@export defer_repeat_think`); `Orders` imprime «orden …» solo para órdenes humanas (`log_orders`, `log_ai_orders`). p99 del tick completo de la IA 0,74–1,43 ms (antes 2,0–3,1). `_check_jam` quitado (con sus knobs `jam_*`, `AiTrack.hold_off_until`/`stuck_thinks` y `ai_jams`): con el mago con prioridad de paso no hace falta (5/5 por ritual sin él). `pick_guard_creature` excluye criaturas atadas por Guardian (`AiTrack.is_guardian_bound`, también usado por `CaptureTask`). `ai_side_trivial.tscn` pasa a `debug/`; `_wizard_info` pasa a `debug/ai_match.gd`; `ai_no_souls.tres` sin NPC. **Segunda ronda (orquestador):** (a) desvío de `positionAfterCollision`: `BodySeparation.wizard_passes_own` (encendido): un mago no choca con las criaturas de su propio bando (ellas sí con él, se apartan); sin esto, con escolta en guardia al dar la vuelta, el mago humano o IA retrocedía empujado (`debug/escort_jam.tscn`: antes 4/6 tramos y 35 s trabado con 4, 8 o 12 Troggs; ahora 6/6 en 51 s, igual que sin escolta; `--own-push` vuelve a la regla original). La escolta detrás del sentido de marcha no se hizo. (b) `PathFollower.retarget_m` (10 m): un objetivo nuevo cerca del que ya camina mueve el último tramo en lugar de buscar de nuevo (los seguidores de la IA, reordenados cada 12 ticks, gastaban las 3 búsquedas por tick y los demás caminaban en línea recta contra la aldea). (c) `AiProfile.soul_keep_factor` 1,25 (desvío, no [S]): el mago que va a un alma la sigue buscando con un alcance mayor; en el borde del alcance oscilaba entre el alma y su lanzamiento (semilla 3). (d) Se arreglaron dos instancias liberadas más: `AiGroups.souls_pair` y `BenchEvents._watch`. Semillas 1–5 (30 min): 5/5 por ritual (11,5–17,4 min), 0 `SCRIPT ERROR`, p99 0,71–0,93 ms. La esquina de `jhut` no era la causa del atasco de la semilla 1 (la caja de colisión de esa casa es de 4×4 m y el mago estaba a 12,8 m): era la escolta de Manahoars; la grilla ya bloquea bien una caja girada 45° (caso `nav_box_corner` en la suite, PASS, sin cambios en `NavGrid`). Pendiente: la sonda `farmer_in_sight` de `ai_summon` tarda 57 s en la corrida final porque la única criatura que lo ve ya está persiguiendo Taurocks (el criterio de 024c pide ≤ 2 s); con la regla original son 2 ticks.

### F76 — Dificultades y perfiles por dios (RFC-024, corte 024e)
Fácil, Normal (original) y Difícil sin trampa. Hecho, falta review y playtest. Criterios de la Adenda 1.3 cumplidos (ver «Corrección Adenda 1.3»); el primer «Medido» queda como historia.

Hecho: `AiDifficulty` (`scenes/world/ai/data/ai_difficulty.gd`) con `data/ai/difficulty_{easy,normal,hard}.tres` (Normal = original y por defecto en `AiSeat`; Fácil períodos ×2, agresividad 0,6, 0,5 s de retraso por pedido en `AiCommandPort`; Difícil ×0,75, 1,0, `perfect_information`); `resource_bonus` bloqueado en 0. Fácil y Normal usan solo lo último visto de lo que el bando no ve (`AiPerception` congela posición/vida/maná, olvida lo que se buscó y no está; `AiCommandPort.can_aim` no apunta a lo no visto y manda las órdenes a la posición vista); Difícil lee el estado real y lo cuenta en `unseen_state_reads`. `AiProfile.for_god` + `data/ai/profile_<dios>.tres` (mismos números del original). Banco: `debug/rules/ai_easy_vs_normal.tres`, `ai_perf60.tres`, `--difficulties=`, rótulo de dificultad en el estado de `ai_match`; `debug/ai_convert.tscn` con reglas propias y NPC. Suite: `ai_difficulty_files`, `ai_profiles_by_god`, `ai_limited_information`, `ai_convert_reserved_soul` (la IA no relanza Convert sobre un alma con ritual en curso: `Soul.reserve_for`), `ai_forget_checked`.

Medido (2026-10-16, headless `--fixed-fps 60`, verificación reducida por el orquestador): `rules_suite` PASS; `ai_easy_vs_normal` 5 semillas × 20 min: **Normal gana 2/5 (criterio ≥ 4/5: FALLA)**, las otras 3 por tiempo; **convocatorias de Fácil a 5 min = 124 % de Normal (media 15,6 vs 12,6; criterio ≤ 70 %: FALLA)**; rechazos por recursos 0, libro exacto, maná solo de fuentes, `unseen_target_reads` 0 en las dos, 0 SCRIPT ERROR. `ai_perf60` (5 min, NPC): `ai_ms` media 0,27/0,26 (pasa), p99 2,74/1,87 (**falla bando 1**), máx 10,1/11,3 en el tick 0 (**falla**; 8,2/6,8 sin el primer segundo). Regresión: `ai_vs_trivial` semillas 1 y 5 ganan por ritual con el mismo digest que antes; `ai_match` seed 7 con y sin `--npcs` mismo digest que antes. Diagnóstico: Fácil gasta menos maná en ataque y Convert (agresividad 0,6) y lo pone en convocatorias; ×2 en los períodos no frena las convocatorias (las limita el maná, no la frecuencia de decisión). Hace falta decisión del tech lead sobre los números de Fácil.

**Corrección Adenda 1.3 (2026-10-16).** `AiDifficulty.summon_interval_s` y `mana_reserve` (límites que la IA se pone, sin tocar recursos ni reglas; 0 y 0 en Normal y Difícil). Fácil: 40 s entre convocatorias (Manahoar incluido) y 30 % del maná máximo que no gasta en criaturas. Se aplican en `SummonPhase` (`AiWizardBrain.summon_interval_over` / `keeps_reserve`; reloj `AiCommandPort.now_tick`). Caso de suite `ai_difficulty_files.summon_pace`. Arreglo aparte: `AiPerception.add_node` ya no reconecta `died` / `state_changed` a un cuerpo olvidado y vuelto a ver (`is_connected`): 0 «already connected» en todas las corridas (antes 144 en una sola).
Medido (headless `--fixed-fps 60`, una tanda): `rules_suite` PASS; `ai_easy_vs_normal` 5 × 20 min: Normal gana **5/5** por ritual (≥ 4/5); convocatorias de Fácil a 5 min **16 %** de Normal (media 3,0 contra 18,8; ≤ 70 %); rechazos por recursos 0, libro exacto, maná solo de fuentes, `unseen_target_reads` 0. `ai_perf60`: `decision_ms` p99 **1,45 / 1,36** (≤ 2); tick completo informado: media 0,27/0,26, p99 2,63/2,25, máx 15,8/17,1 (12,6/12,9 desde el tick 60) — p99 y máx del tick completo pasan a RFC-027. 0 SCRIPT ERROR. Digests: `ai_match` seed 7 con y sin `--npcs` iguales; **`ai_vs_trivial` 1 y 5 y `ai_perf60` cambiaron** (siguen ganando por ritual, ahora antes: 32968 y 39849 ticks). Normal no pasa por el código nuevo (intervalo y reserva 0 = siempre permitido, sin consumir azar; la guarda solo evita una conexión que Godot ya rechazaba); entre las dos tandas otros cortes cambiaron `unit_body.gd`, `creature_type.gd`, `game_data.gd`, `map_building.gd`/`SplashDamage` y `match_command.gd`, que tocan hechizos y daño que usa la IA (los duelos sin IA no cambiaron). Atribución confirmada por corrida de control en la review (`reviews/REVIEW-F76-difficulty.md`): F76 no la causa con corrida de control.

**Ronda de balance tras el playtest (2026-10-16).** El playtest dio FAIL: a los 10 min Fácil tenía 2 Earthfling contra 18 de Normal (`agent/out/pt76/`). Con `mana_reserve` 0,15 e intervalo 40 s (5 × 20 min, conteo con `agent/tools/pt76_army.py`): criaturas de Fácil que no son Manahoar a los 10 min 0, 0, 0, 2, 0 (**criterio ≥ 3: FALLA**); Normal gana 5/5 por ritual; convocatorias de Fácil a 5 min 21 % de Normal; libro exacto, maná solo de fuentes, 0 rechazos por recursos, `unseen_target_reads` 0, 0 SCRIPT ERROR. La variante 30 s + 0,15 no se midió (descartada por el orquestador); `difficulty_easy.tres` vuelve a 40 s / 0,15. **Criterio nuevo (orquestador):** el ejército se mide contra el humano inactivo, porque contra Normal mide la presión de Normal. Fácil contra `ai_vs_idle.tres` (`--difficulties=easy`), seed 1, 12 min: a los 10 min **8 Earthfling + 2 Manahoar** (≥ 3: pasa); no gana en 12 min; con `--minutes=30` (misma semilla, mismo ejército a los 10 min) **gana por ritual a los 13,96 min** (tick 50262), más tarde que Normal (9,57 min): pasa. Libro exacto, maná solo de fuentes, 0 rechazos, 0 SCRIPT ERROR. El rótulo de `ai_match` dice «N Bot trivial» para un asiento con escena propia.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F76-difficulty.md`), con una corrida de control que demostró que F76 no mueve el digest de Normal. El playtest con ventana dio PASS en el rótulo, en el conteo por bando y en Normal y Difícil contra el bot trivial. Dio FAIL de balance en Fácil, que se resolvió así:
- Fácil quedó en 40 s entre convocatorias y 15 % de reserva de maná.
- El criterio de ejército se midió contra el humano inactivo, porque contra Normal mide la presión de Normal: 8 Earthfling a los 10 min.
- Fácil le gana al inactivo a los 13,96 min; Normal lo hace a los 9,57 min.
- Contra Normal, Normal gana 5/5 y Fácil convoca el 21 %.
- Deuda: los nits del review (caso unitario de la lógica de ritmo, estáticos privados y tick de la última convocatoria).

### F77 — Partida completa contra la IA (RFC-024, corte 024f)
Botón «Contra la IA» y prueba en el dedicado con `--ai-slots=2`. Hecho, falta review y playtest.

`AiRoster` (`scenes/world/ai/ai_roster.gd`, `%AiRoster` en `high_noon.tscn`): solo en solo o servidor; asientos de `MatchRules.ai_seats` (movido desde `BenchRules`) o, si no hay, `SacrificeFlow.solo_ai_seats`; por asiento: pick en `slot_picks` (`SacrificeFlow.set_ai_pick`, publicado por `slot_picks`), `WizardSpawner.spawn_slot`, `AiSide` hijo; imprime `ia slot N lista`; dios vacío = sorteado con la semilla. El banco (`ai_match`) lo apaga. `SacrificeFlow`: `solo_ai_seats`, `play_vs_ai(god)`, `--ai-slots=2 [--ai-god=]` en el dedicado (`max_players = 1` antes de `super._ready()`). `boot`: `%VsAi` («Contra la IA») y `%AiGod` («Rival: Aleatorio» o un dios); `%Solo` sin rival. `data/ai/seat_vs_ai.tres` (slot 2, dios al azar, Normal). Banco: `debug/ai_endgame_human.tscn` (hereda `ai_endgame`; el humano a 40 m del altar IA con un Manahoar), `debug/rules/ai_vs_idle.tres`, `BenchRules.human_start_near_altar_of`. Medido: desde boot, `Wizard2` a ~3 s y 3 criaturas del slot 2 a ~50 s, 32 NPC; el HUD local no cambió con 11–20 mensajes del caster IA; `ai_vs_idle` semilla 1 headless: «Derrota» (desecración) a 9,6 min de juego; `ai_endgame_human`: «Victoria» ~80 s tras lanzar Desecrate; dedicado `--ai-slots=2` + 1 cliente: slot 1, Wizard2 se mueve, 8 criaturas del slot 2, 32 NPC, el cliente sin `AiSide`. Capturas en `agent/out/pt77/`. Ronda de corrección de la review (`reviews/REVIEW-F77-vs-ai.md`): `host_lan()` y `return_to_boot()` vacían `solo_ai_seats`; comentario de `BenchRules` corregido; `run_pt77_net.sh` corre el servidor con `--fixed-fps 60`; `pt77_vs_ai` espera ≥ 1 criatura del slot 2 en ≤ 120 s (`AgentKit/pt77_watch.slot2_ok`). `pt77_vs_ai` con `--fail-on-error`: AGENT_OK (1.ª criatura del slot 2 a ~25 s, 12 a ~128 s, 32 NPC, HUD sin mensajes de la IA, 0 «already connected» tras el arreglo de F76). Regresión con `--fail-on-error`: `f24_cast`, `f25_summon`, `f30_souls`, `f31_ghost`, `pt61b_ritual_close`, `pt64t_solo` AGENT_OK (`agent/out/pt77/`).

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F77-vs-ai.md`). Playtest con ventana PASS (`agent/out/pt77play/`):
- Inicio, con rival aleatorio y con dios fijo: `Wizard2` aparece a los 3,7 s y su primera criatura a ~29 s. El HUD muestra el mago propio.
- «Victoria» a ~81 s y «Derrota» a ~97 s.
- Dedicado con `--ai-slots=2` más un cliente: `Wizard2` y sus criaturas se mueven, y el cliente no tiene `AiSide`.
- «Solo» sigue sin rival.

Deuda: falta probar la victoria y la derrota en el dedicado con IA (no hay un banco corto: el dedicado no acepta `--rules=`).

### F78 — Selección sin tope y clic en vacío (RFC-025, corte 025a)
Sin límite de unidades seleccionadas (también las órdenes y los grupos) y el clic izquierdo en vacío deselecciona. Reemplaza lo de «hasta 12» y «el clic en el suelo no deselecciona» de F27.

Hecho y cerrado (review NEEDS WORK por el clic sobre cadáver, corregido; `reviews/REVIEW-RFC-025a.md`; playtest con ventana PASS en los 7 puntos, `agent/out/pt78/`; pendiente subir los cambios de AgentKit a godot-studio-skills): `Selection` con `max_size` 0 (membresía por Dictionary, `clear/select_only/remove/has`, `count`, `last_rect_us`); `Orders` con `max_units` 0, `row_size` 12 (150 unidades = 13 filas), `_match` con claves float ordenadas en nativo (4 ms con 150) y `last_apply_us`; regla 3.2 en `match_command._is_empty_at`; assert `prop` y `shift`/`ctrl` en `drag` de AgentKit; bancos `debug/selection_many.tscn` (150, 3 tipos) y `selection_many_classic.tscn` (`max_size` 12); `agent/harness/selection_probe.gd`; flows `f78_many`, `f78_deselect`, `f78_classic`, `f78_four`, `f78_perf`, `f78_online_a` y `agent/run_f78_net.sh`. Medido: rect 1.0 ms; primera orden de 150 = 37 ms (arma una vez la malla del clip «run» por modelo, no es de la selección), las siguientes 5 ms. Criterio 9c (Δ frame_ms con 150 vs 0 seleccionadas ≤ 1 ms): NO MEDIDO; el frame base es de ~420 ms con la máquina cargada y el delta no se resuelve (CPU de proceso +0,3 ms, draw calls +4). La primera orden de 150 tarda 37,5 ms por la primera reproducción del clip «run» de cada modelo. Un cadáver bajo el cursor no deselecciona (máscara 15, flow `f78_corpse`).

### F79 — Panel de unidades seleccionadas (RFC-025, corte 025b)
Panel a la izquierda con el marco del original, 2×6; una celda por unidad hasta 12, por tipo con contador si hay más.

Hecho y cerrado (review NEEDS WORK: `reload()` solo para el harness y regresión sin aislar, corregidos; `reviews/REVIEW-RFC-025b.md`; playtest con ventana PASS en los 8 puntos, `agent/out/pt79/`; relleno corregido a columnas como el original; escala del HUD 480 vs 600 pendiente de decisión del usuario): `scenes/ui/hud_icons.gd` (`HudIcons`: `icon`, `sheet`, `region`, carpetas apuntables; `spell_book.gd` lo usa sin cambio de conducta); `scenes/ui/selection_roster/{selection_roster,roster_cell}` (marco `fram` espejado como el original, celdas 34×32 con barras (192,0,0) y (0,96,192), modo unidad ≤ 12 y modo agrupado con `%Count` solo dígitos, clic / Shift / Ctrl, `%Ability` con `ability_pressed` conectado a `_use_ability()`, tooltips apagables, pool de celdas, Timer a 10 Hz, oculto con `local_slot() == 0`, respaldo sin caché); instancia en `high_noon.tscn` tras `View`; sale `%Unit` de `hud.gd/tscn`; `agent/tools/migrate_unit_asserts.py` migró 23 flows (62 asserts); flows `f79_roster`, `f79_roster_many`, `f79_hit` (banco `debug/roster_hit.tscn`, `foe_aggro`), `f79_ability`, `f79_nocache`, `agent/harness/hud_cache_probe.gd` y `agent/run_f79.sh`. Desvíos: más tipos que huecos hacen scroll vertical (no crecen columnas: el marco es fijo; sin knob `max_columns`); knob `base_height` (480). Corregido tras la review: sin `reload()` en el panel (la sonda `hud_cache_probe` instancia una copia de la escena), habilidad compartida con `Selection.ability_tag()`. Flows online migrados `f27_pt_online_client` y `f25_online_client` PASS con dedicado + cliente (`agent/run_f79_net.sh`); el resto de los 12 no se corrió. Deuda previa, no del panel: `pt58_melee` falla igual con el panel oculto y congelado (paso 61, `DoctorMelee visible_in_tree false`, Health del doctor constante en 400; `agent/out/f79_reg/zz_pt58_noroster.log`), y `pt63_melee`/`pt63_melee2` fallan con el mismo assert; `pt59_select` falla por `%SacrificeSystem/Doctors/Doctor1` ausente (no corrido sin panel). `.gitignore` ignora `agent/out/f79_*/f79_3_side_by_side.png` (recorta el original); `agent/out/` ya tiene archivos versionados, no lo ignoré entero.

### F80 — Iconos en lugar de textos indicadores (RFC-025, corte 025c)
El hechizo, la orden o la habilidad armada se ve como icono en el cursor, con los iconos y cursores del original; los rechazos destellan el icono de «no». Hecho y cerrado (review NEEDS WORK: «Sin almas» dibujado fuera de Hud y dos rechazos mudos, corregidos; `reviews/REVIEW-RFC-025c.md`; playtest con ventana PASS en los 8 puntos, `agent/out/pt80/`; sin ejercitar con mouse real: cursor de hardware en Retina, cursor sobre la HUD y entre slots del libro; tooltips y escala del HUD pendientes de decisión del usuario) independiente: `tools/export_icons.py` suma 22 cursores (`cache/look/cursors`), `Matt/Mgua/Mgot/ncst` y 21 XMNU (`cache/look/xmenu`); `HudIcons` con `cursor/cursor_sized/xmenu/armed`; `scenes/world/command_log.gd` (`%Battle` pasa de Label a Node: `armed`, `armed_icon`, `armed_accepts`, `text` sin dibujar, `arm/disarm/say`); `match_command.gd` usa `arm/disarm/say` (setter de `_mode` desarma); `data/ui/command_cues.tres` + `CueSet`; `scenes/ui/command_cue/{command_cue,cursor_skin,target_probe,cue_set}` (TargetProbe nuevo: un solo rayo a 30 Hz que leen el cursor y el cue); grupo `hud_text_allowed`; `agent/harness/{hud_text_audit,cue_probe}.gd`; flows `f80_cues`, `f80_cues_orders`, `f80_cues_manalith`, `f80_hud_text`, `f80_nocache`. Desvíos: `TargetProbe` extra; `CommandCue` va al final de `Hud` (dibuja sobre todo); `arm()` lleva `prompt` y `accepts`; `%Mirror` (copia del cursor en el viewport, apagada) porque las capturas no incluyen el cursor del sistema. No verificado: el cambio de cursor sobre la HUD con el mouse real (AgentKit no mueve el mouse del sistema); el cursor de hardware en pantalla; el menú «avance/guardia/retirada» sigue sin ejecutar su acción (fuera de alcance).

### F84 — Tamaño del HUD (RFC-025, desvío «escala 480 vs 600»)
Una sola perilla de tamaño para el libro de hechizos, el panel de seleccionadas, el icono armado y el cursor; por defecto el tamaño del original (0,8 = base 600), 1,0 = sacengine (base 480), libre entre 0,6 y 1,4.

Hecho y cerrado (review PASS con nits, aplicados; `reviews/REVIEW-F84-hud-scale.md`; playtest con ventana: PASS en tamaño por defecto (panel 42,7 % vs 41,5 % del original), 0,6, icono bajo el cursor, cambio en caliente; FAIL a 1,4 (el libro tapaba el panel) corregido con tope 1,2 y guarda geométrica que achica el panel para no pisar el libro, verificado a 720 y 1080; `agent/out/pt84/`, `agent/out/f84/`). Pendiente: menú de opciones (llamará a `HudScale.set_scale`) y mover el valor a un servicio de settings; barras del panel finas a 720. `scenes/ui/hud_scale.gd` (`HudScale`, Resource: `base_height` 480, `default_scale` 0,8, `min_scale`/`max_scale`, `get_scale`/`set_scale`/`factor`; emite `changed`) y `data/ui/hud_scale.tres`, compartido por `SpellBook`, `SelectionRoster`, `CommandCue` y `CursorSkin` (`@export var hud_scale`, por defecto ese `.tres`; reemplaza `BASE_HEIGHT`/`base_height` 480 de los cuatro). Elección del jugador en `user://settings.cfg` (`[hud] scale`, la escribe `set_scale`); `--hud-scale=` en la línea de comandos manda en esa corrida y no se guarda. No hay menú de opciones todavía: sin texto nuevo en pantalla. Medido (`agent/flows/f84_hud_scale.json`, `debug/orders_group.tscn`, 4 seleccionadas y hechizo armado): 1280×720 escala 1,2 con 0,8 y 1,5 con 1,0; 1920×1080 1,8 y 2,25; icono armado y cursor 38/48/58/72 px (≤ 256); el marco del panel ocupa ~42,6 % del alto con 0,8, igual que `orig_4_manantial.webp`, y ~53 % con 1,0; lado a lado en `agent/out/f84/f84_{720,1080}_side_by_side.png` (ignorado por git). Regresión con 0,8: `f79_roster`, `f79_roster_many`, `f80_cues`, `f80_hud_text` (auditoría 0) y `polish_spellbar` AGENT_OK. Review PASS (`reviews/REVIEW-F84-hud-scale.md`); nits aplicados: `HudScale.px` (redondeo y tope 8–256) para el cursor, el icono armado y el espejo; valor de `settings.cfg` y `--hud-scale=` validado (número finito, si no el valor por defecto con aviso); error de `config.save` registrado (y no se pisa un archivo ilegible); aviso en los cuatro nodos si `hud_scale` no es `data/ui/hud_scale.tres`. `agent/harness/hud_scale_probe.gd` cambia la escala en caliente sin guardar: con `--hud-scale=` 0,6 / 0,8 / 1,4 y luego 1,4 → 0,6 en caliente, libro y panel 0,9 / 1,2 / 2,1 e icono = cursor 29 / 38 / 67 px, sin recargar; `f80_hud_text` auditoría 0. Playtest (`agent/out/pt84/`): PASS a 0,8 (panel 42,7 % vs 41,5 % del original), 0,6, icono bajo el cursor, cambio en caliente y legibilidad; FAIL a 1,4 (el libro tapaba el borde inferior del panel). Corregido: `max_scale` 1,2 en `hud_scale.tres` y guarda geométrica `SelectionRoster.avoid` (= `SpellBook` en `high_noon.tscn`, `avoid_margin` 4 px, `fitted_factor`): si el panel, centrado a la izquierda, llegaría al libro, se achica hasta lo que entra entre el centro y el borde superior del libro (por geometría pasa desde ~1,15). Re-corrido: 1,2 y `--hud-scale=1.4` (limitado a 1,2) a 720 → libro 1,8, panel 1,656, 4 px de separación, icono = cursor 58 px; a 1080 → 2,7 / 2,5 / 4 px / 86 px; 0,8 sin cambio (1,2 / 1,2, 110 px de separación); lámina `agent/out/f84/f84_p12_p14_side_by_side.png` sin superposición; `f80_hud_text` auditoría 0. Pendiente: mover el valor a un autoload de ajustes cuando exista el menú de opciones.

### F108 — Pasto en James, Stratos y Charnel (RFC-022e, corte 022e4b)
Los cinco biomas tienen pasto con el mismo mecanismo: un `GrassSet` por bioma que apunta al `meadow.tres` compartido (misma forma) más una `GrassPalette` con el color del suelo; sin código nuevo en el juego.

Hecho, review NEEDS WORK (`reviews/REVIEW-F108-grass-biomes.md`) con una ronda de corrección aplicada; falta re-review y playtest. `data/look/grass/{james,stratos,charnel}_grass.tres`, `data/look/grass/palettes/{james,stratos,charnel}.tres`, `grass =` en `data/look/{james,stratos,charnel}.tres`, `debug/rules/biome_{james,stratos,charnel}.tres`. `tools/sample_grass_palette.py` propone la paleta (media del slot 0 del atlas ponderada por uso, transferencia HSV de Persephone; autocontrol error 0) y documenta que en suelos cálidos satura de más; las paletas finales se ajustaron con medida, no con la propuesta.
Corrección (2026-10-16): **color en sombra** medido con un banco determinista nuevo (`agent/fixtures/grass_bench_shade_<dios>.tscn`, vistas `shade_a`/`shade_b` sobre la sombra del altar; flows `agent/flows/rfc022e4b_shade_<dios>.json`; métrica `agent/shade_metric_022e4b.py`: pasto (A) contra suelo con la capa de pasto apagada (C) en los mismos píxeles, sombra/sol por Otsu, distancia RGB de las medias). Pyro (referencia): sombra 15,5 / 13,3, sol 30,7 / 49,1. Charnel antes: sombra 38,7 / 35,6, sol 59,8 / 58,5; **después** (`color_mid` 0,67/0,55/0,50, `color_tip` 0,95/0,83/0,74): sombra 10,0 / 11,5, sol 20,0 / 19,9 (pasa). Stratos sin cambios: sombra 12,3 / 10,3, sol 27,2 / 36,5 (ya pasaba; dos variantes más claras bajaban el sol pero subían la sombra de `shade_a` a 16,5–19,2 > Pyro, descartadas); el tono azulado en sombra es el ambiente de `stratos_light.tres` y lo tiene igual el suelo. James antes: sombra 38,5 / 42,1, sol 48,7 / 58,1; **después** (`color_mid` 0,68/0,60/0,53, `color_tip` 0,98/0,88/0,78): sombra 8,2 / 7,5, sol 20,0 / 31,1 (pasa). **Original (desvío aceptado por el orquestador):** el High Noon original usa el tileset James, así que Stratos y Charnel en High Noon no existen en el original; para James haría falta el permiso de grabación de pantalla, que no se toca. Evidencia: no tiene captura de pantalla (`Bindable.screenShot` → `unsupported()` en `source/dagonBackend.d:1091`) y `screencapture` desde la shell falla («could not create image from display», sin permiso de grabación de pantalla); además High Noon tiene tileset James (`A_AJ` en el `.scp`; `levl.detectTileset`, `source/levl.d:43`), así que sacengine no puede mostrar High Noon con Stratos ni Charnel. Capturas por flows AgentKit con `--fail-on-error` (`agent/run_022e4b.sh`, `agent/flows/rfc022e4b_<dios>.json` sobre `agent/fixtures/biome_pick_<dios>.tscn`): AGENT_OK; láminas `agent/out/rfc022e4b/sheet_{james,stratos,charnel}.png` (juego, giro, alejado al máximo; no es la cámara RTS de `look_gallery`). Workaround `biome_shots.gd` retirado. Cambio de tema en caliente: `sheet_hotswap.png`.

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F108-grass-biomes.md`): paletas de Charnel y James medidas en sombra, y retiro del workaround. Playtest con ventana PASS en los 5 criterios (`agent/out/pt108/`, láminas `sheet_<dios>.png`):
- Caminata sin huecos alrededor del mago.
- Giro de 360° y zoom máximo sin parches.
- Vista RTS de la galería: grano continuo; el pasto cubre el 20–30 % de los píxeles.
- Cambio de bioma en caliente sin errores.
- Persephone y Pyro iguales a antes.

Desvío aceptado: sin referencia del original. High Noon solo existe con el tileset James; para capturar James hace falta el permiso de grabación de pantalla, que no se toca.

Aprobado a ojo por el usuario el 2026-10-16 (vista alta y biomas).

### F92 — Estadísticas del mago como en el original (RFC-028, corte 028a)
Arriba a la derecha, el bloque del original (sacengine `renderStats`): marco de almas 64×96 con el alma azul animada (15 cuadros/s) y el número en la fuente `fn10`, más maná y vida como barras 32×96; sin la línea «Vida/Maná/Almas». «Mago · Dios» y «Fantasma» quedan como texto debajo de los marcos (P1 = a).

Hecho y cerrado (2026-10-16). Review PASS (`reviews/REVIEW-F92-hud-souls.md`). Playtest con ventana PASS a 720p y 1080p: el alma pasa de 0 a 1 y anima; Heal deja el maná en 0,70; el texto «Fantasma» queda debajo del bloque; la escala 0,6–1,2 no pisa el libro ni el panel (`agent/out/pt92/`). La costura de 1 px también está en el original (lámina `pt92_sheet_vs_original.png`). Deuda menor: «Mago · Dios» y «Fantasma» quedan pegados al borde derecho (0–2 px), cuando antes tenían 24 px de margen; asserts más estrictos en `f92_stats`. `scenes/ui/wizard_stats/` (`WizardStats`, `StatBar`, `SoulCounter`), `scenes/ui/bitmap_digits.gd` (`BitmapDigits`), `scenes/ui/text_readout.gd` (`%Stats` pasa a `Node` con `text`, misma cadena, sin dibujar); `hud.gd` llama `WizardStats.show_values(vida/máx, maná/máx, almas)`. `tools/export_icons.py` escribe `cache/look/hud/{spir,fn10}.png` y las 6 franjas `stat_{mana,health}_{top,mid,bottom}.png` (leídas de los arreglos de `sacobject.d` del checkout local; nada en git). Escala con `HudScale` (F84) y se rehace al cambiar escala o ventana. Sin caché: barras de color plano y número en Label (`hud_text_allowed`). Medido (`agent/flows/f92_stats.json`, `f92_ghost.json`; `agent/out/pt84/f92_*`): 1280×720 escala 0,8 → 153,6 × 116 px en (1126,4, 0) (alto redondeado por el contenedor); 1920×1080 → 230,4 × 173; en caliente 1,2 / 0,6 → 230,4 × 173 / 115,2 × 87 a 720; alma 8 cuadros en 0,533 s; almas 0 → 1 al juntar; Heal: `mana_fraction` = 0,7 con maná 700/1000 (y 0,8227 = 822,7/1000 en pleno drenaje); fantasma: `health_fraction` 0, «Fantasma» en y = 158 bajo el bloque. Regresión AGENT_OK: `f80_hud_text` (auditoría 0), `f30_pt_pickup`, `pt31_ghost`, `f79_roster`, `f84_hud_scale`.

### F93 — Vida de edificios al hacer clic y daño de área a estructuras (RFC-028, corte 028b)
Clic izquierdo sobre una casa, un cactus, un Manalith u otra estructura con vida muestra su barra sobre el modelo sin cambiar la selección; el clic en vacío deselecciona y la quita. Wrath, Fireball y Swarm dañan también edificios, como en el original.

Hecho, review NEEDS WORK corregida, falta playtest. `scenes/world/structure_inspector.gd` (`StructureInspector`, `%Inspector` en `high_noon.tscn`: `inspect`/`clear`, una barra a la vez, local y sin RPC; se limpia si el edificio muere o sale del árbol; altar e indestructibles sin barra); `match_command._left_at`: criatura → selección, si no edificio → `inspect`, si no vacío → `Selection.clear()` + `Inspector.clear()`. `unit_health_bar.gd` knob `only_when_selected` (visible solo inspeccionada, nunca con máximo ≤ 0); la barra (3 × 0,32 m) instanciada en `map_building.tscn` y `structure.tscn`, centrada sobre la caja a `lift` 0,45 m del tope. `scenes/world/spells/splash_damage.gd` (`SplashDamage`: `wizard`, `unit`, `structure`, distancia a la caja con caja girada y cilindro, `amount·(1 − d/r)`, sin daño a máximo ≤ 0), usado por Wrath, Fireball y Swarm. Banco `debug/wrath_splash_building.tscn` (`rock_hit.gd` con `building_scene/tags/spots`: Druid a 40 m, `jcc2` a 3 m a su lado, cerca `jfn1` indestructible); `agent/harness/splash_probe.gd`; flows `f93_inspect` (village) y `f93_splash`. Medido: casa → `inspected.tag` jhut, fracción 1,0, 1 barra, selección 1; cactus → jcc2, 1 barra, selección 1; Hunter con `order_units` lo baja a 0,947 en ≤ 30 s; suelo → nada inspeccionado, 0 barras, selección 0. Wrath: Druid 550, cactus 293,2 con d = 2,334 m contra la caja del modelo (esperado 550·(1 − d/5) = 293,2, calculado por `splash_probe` desde `cache/baked/props.json`), cerca 0/0 sin daño. Corrección de la review (`reviews/REVIEW-F93-structures.md`): B1 `MapBuilding.hit_box()` (caja del modelo, sin `collision_inset`) es la que mide `SplashDamage.box_distance` (antes 250,1 contra la colisión achicada); N4 el clic inspecciona solo si el edificio es el primer collider (máscara 15), un mago o cadáver delante no; N5 `splash_probe.watch()` engancha `Spells` una vez; N6 d esperada independiente; N1 caja girada en el marco del edificio contra AABB del original, anotada como decisión del port. Deuda: N2 (edificio de varias piezas: caja unida contra el componente más cercano), N3 (barra buscada por nombre). Regresión tras la corrección: `f93_inspect`, `f93_splash`, `final_wrath_splash` AGENT_OK, `rules_suite` 88 PASS. `ai_match` seed 7 sin y con `--npcs`: digest igual antes y después (`d0cd7283…`, `08551430…`). Fuera: caja del cursor quieto (P2), daño a widgets, modelo destruido.

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F93-structures.md`). Playtest con ventana PASS en los 6 criterios (`agent/out/pt93/`):
- Choza, cactus y suelo.
- Altar sin barra.
- Un cactus que cae mientras está inspeccionado pasa a null sin errores.
- Un mago o un cadáver delante no inspecciona lo de atrás.
- Wrath hace 293 al cactus.
- La barra se lee a 20 y a 40 m.

Notas:
- Desde unos 50 m, con niebla, la barra es una línea tenue.
- A 2 m de la cámara, el cactus se ve como un cilindro rojo liso (¿LOD o material de cerca?); queda para verificar.
- Deuda N2/N3.
- Fireball y Swarm contra edificios, sin probar en el playtest.

### F94 — Animaciones de Farmer y Taurock (RFC-028, corte 028c)
Los Farmers y Taurocks de la aldea se mueven con sus clips reales: quieto, correr o huir, encogerse (a veces hablando encogidos), cavar cuando están tranquilos y atacar (Taurock). **Cambio de look:** todas las criaturas y el mago reproducen ahora sus clips a la velocidad real, la mitad de rápido que antes.

Hecho, falta review y playtest. Exportador (`tools/export_stats.py`): `EXTRA_ANIM_SLOTS` lee las ranuras CRE8 32/33/35/37 (`animations.d`) solo en campesinos (`PEASANT_TAGS`, `nttData.d:133`; en el resto son clips de vuelo) y descarta los tags «00»; `creatures.json` gana `extra_animations {cower, pull, work, talk_cower}` (`zepe`: PEcw, PEpu, PEdi, PEtc; `raeb` vacío); `NPC_ANIM_CREATURES = ("zepe","raeb")` exporta idle, walk, run, attack0 y cower/talk_cower/work (no PEpu). Caché: `epez` PEi1 34, PErn 32, PEa1 26, PEcw 56, PEtc 56, PEdi 198 (402 cuadros, 107 MB); `eber` ya tenía BEi1, BErn, BEa1. `CreatureType.extra_animations`. `ClipPosePlayer`: `signal clip_looped(role)` (en el tick físico que vuelve al cuadro 0, en todos los peers) y `has_role(role)`; los roles nuevos entran en el precalentado de 027b sin cambios. `UnitBody`: roles `cower`, `talk_cower`, `work`; COWER reproduce el clip y elige `talk_cower` cuando `(hash(name) + vueltas) % 5 == 0` (sacengine `state.d:8164-8171`, sin `randi()`); el aplastado de `Tilt` queda solo si el modelo no tiene clip; `set_idle_role()` cambia el clip del modo IDLE. `PeasantBehavior`: `work_when_calm` (encendido) y `work_role` («trabajar el campo» es decisión del port: está en el FSM del original sin regla). Muerte: sigue el tween de `Corpse` (P3 = b). **Doble avance corregido:** `UnitBody` y `WizardBody` llamaban `advance` del `ClipPosePlayer` además de su propio `_physics_process`, así que los clips de criaturas y magos corrían al doble de su framerate; ahora el reloj es solo del `ClipPosePlayer` y el cuerpo elige el rol. Banco: `debug/npc_anim_gallery.tscn` (hereda `unit_parity_gallery.tscn`; `unit_parity_gallery.gd` gana `unit_tags`, `cycle_roles`, `mana_probe`; `check_tick` cicla los 6 roles), `agent/harness/pt94_clips.gd` (solo observa: clip por cuerpo, resumen por modo, secuencia de vueltas, cuadros por segundo del clip, tiempo de cuadro), flows `f94_gallery`, `f94_cower`, `f94_village`. Digest: el de los bancos con NPC cambió a `ac6b9176…` (antes `08551430…`) por el cuerpo de `epez` re-horneado desde su idle en F112, no por este corte; A/B de 028c con clones congelados en el scratchpad (A = árbol vivo sin el diff de 028c), seed 7: sin NPC A = B `ff4895e7…`, con NPC A = B `7ba047fa…` (las líneas base se movieron por otros cortes entre corridas, no por 028c), 0 SCRIPT ERROR, RSS ≤ 517 MB, headless sin mallas. Medido con ventana (`agent/out/pt94/`, flows AGENT_OK): galería, tag esperado en los 6 roles (Farmer PEi1, PErn, PEa1, PEcw, PEtc, PEdi; Taurock BEi1, BErn, BEa1 y sin clip en cower/talk_cower/work) y el cuadro avanza ~16 cuadros en 0,5 s; velocidad del clip medida 29,9 cuadros/s contra 30 del clip (ratio 1,00) en Farmer, Taurock, mago cwa0, Trogg y Manahoar (antes del arreglo era 2×); `village_cower`: Farmer6 en COWER con PEcw/PEtc, `Tilt` escala 1,00 (sin aplastado), 30,4 cuadros/s, secuencia de 14 vueltas idéntica en dos corridas (`talk_cower,cower×4,talk_cower,cower×4,talk_cower,cower×3`); `village`: 24 Farmers tranquilos en IDLE con PEdi, 2 encogidos (PEcw/PEtc), 6 Taurocks con BEi1; tiempo de cuadro con 26 + 6 NPC: process 16,1 ms y physics 10,8 ms de media (sin línea base A, no hay `FrameBudget`). Sin medir: Farmer huyendo con PErn (ninguno huyó en `village`) y `village_taurock` (BErn, BEa1); la captura de `village_cower` queda tapada por el pasto. Deuda: los Farmers que despiertan juntos cavan sincronizados (mismo cuadro). Desvíos: BEa2 no se exporta (ningún rol lo usa); el reposo sigue siendo `idle0`, no `stance1`.

**Cierre (2026-10-16).** Review PASS en código (`reviews/REVIEW-F94-npc-anim.md`). Playtest con ventana PASS (`agent/out/pt94play/`):
- El Farmer huye con PErn a 29,7 cuadros/s.
- El Taurock persigue con BErn y ataca con BEa1, con daño real.
- Con 26+6 NPC despiertos, el frame no empeora (−0,02 ms; está limitado por render) y la física sube 3,9 ms.
- Regresión `pt73w_house` y `f79_roster` con AGENT_OK.
- Velocidad nueva de los clips: mago y Trogg a 29,8 cuadros/s; el paso se ve natural.

Deuda:
- Un DEAD en el suelo del servidor muestra el último rol (RFC-023).
- Los Farmers que despiertan juntos cavan en sincronía.
- Unificar el socket `_clip_pose`.

### F95 — Shader de sprites moderno (RFC-029, corte 029a)
Los sprites de los efectos se funden contra el suelo en vez de cortarlo en línea recta, mezclan un cuadro del atlas con el siguiente en vez de saltar y pueden llevar una rampa de color por vida. La sangre, la tierra y la roca (los 11 tipos mix) reciben luz y niebla; los aditivos se desvanecen con la niebla de profundidad del mapa. Fundido e interpolación se encienden por preset (bajo no; medio y alto sí). Mismos atlas, colores y tiempos de sacengine.

Hecho, review NEEDS WORK corregida (`reviews/REVIEW-F95-sprite-shader.md`), falta playtest. `scenes/fx/sprite_particle.gdshaderinc` (fundido por profundidad con `soft_distance_m`, interpolación con `frame_wrap`, rampa `color_ramp`; globals `fx_soft_particles`, `fx_frame_blend`; `FX_LIT` y `FX_FOG_FADE`), `sprite_particle_add.gdshader` (sigue con `fog_disabled`: Godot 4.7 suma la luz de la niebla a un aditivo; atenúa con `smoothstep(begin, end, d)·density` de los globals `fx_fog_density/begin/end` que escribe `ThemeApplier` junto al Environment), `sprite_particle_mix.gdshader` (sin luz) y `sprite_particle_mix_lit.gdshader` (nuevo). `ParticleType`: `soft_distance_m` 0,6, `frame_blend`, `color_ramp`, `lit` (false por defecto, true en los 11 `.tres` mix). `FxAtlas.shader_for`. `LookQuality` grupo «VFX y clima (029)»; `QualityApplier.apply_fx_globals`; `project.godot` `[shader_globals]` en 0 (sin preset = look previo). Determinismo: `portal_disc.gd` con RNG propio; `FxBus.next_particle_seed()` (RNG propio, `particle_seed` constante) da la semilla a `SpriteParticles` y `SpriteEmitter`, ambas escenas con `use_fixed_seed` (probado con ventana: `restart()` ya no consume el RNG global; `CPUParticles3D.new()`/`instantiate()` sí lo consume, eso queda para la tarea de `MatchSeed`). Lab `debug/vfx_lab.tscn` (cámara `fx` libre en (1500, 21, 1560), F2 ×3; slots 9 × 4 m; `HealSlow` una partícula quieta de un ciclo, `debug/fx/heal_slow.tres`), `debug/look/quality_medium_fx_legacy.tres`; fixtures `agent/fixtures/vfx_lab_legacy.tscn`, `vfx_lab_additive.tscn` (los aditivos), `perf_f95*.tscn`; flows `f95_vfx_lab`, `perf_f95`, `perf_f95_legacy`. Medido con `--fixed-fps 60` y semilla fija: ruido entre dos corridas 0,000 %; criterio 1 (aditivos, legacy contra antes) 0,633 %; lab completo legacy contra antes 2,756 % (los mix con luz, aceptado). Medio contra legacy 16,4 %: el fundido se ve en `agent/out/f95/pt95_soft_zoom.png`. `HealSlow`: pasos entre 6 capturas seguidas, legacy 0,0039–0,0509 (un salto, máx/media 2,35), medio 0,0068–0,0267 (máx/media 1,50). GPU: `FrameBudget` con los efectos en el aire, medio 14,50 ms contra legacy 14,41 ms de frame (render CPU 12,90 contra 12,91), una corrida cada uno: +0,09 ms, por debajo de la resolución del método (no resuelve 0,3 ms). Luz en sangre y roca para el usuario: `agent/out/f95/pt95_lit_blood_rock.png`. `ai_match ai_vs_trivial --seed=1 --minutes=3` A/B (copia en el scratchpad) digest `047a3a7c…` igual; `rules_suite` PASS; `grep randf(` en `scenes/fx` 0. Fuera: luces, calcos, pool y estelas (029b–e).

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F95-sprite-shader.md`). Playtest con ventana PASS (`agent/out/pt95/`):
- Lab en bajo y en medio, sin errores.
- Reproducibilidad: 0,000 % de diferencia en 15 capturas.
- Rock y Wrath en juego se funden con el suelo, sin líneas rectas.
- Sangre y roca quedan sombreadas: la sangre pasa a un rojo más oscuro y la roca a un gris con sombra. Se le mostró al usuario.
- `final_wrath_splash` da AGENT_OK.

Criterio 3b no observable: la niebla de los biomas apenas actúa a 90 m (≈ 1 %). La atenuación queda verificada solo por código (con densidad 0 el resultado es idéntico).

Criterio 4: +0,09 ms, por debajo de lo que el método puede resolver.

Deuda: `CPUParticles3D.new()` sigue consumiendo el RNG global; se resuelve con la tarea del RNG propio de `MatchSeed` (adenda de RFC-024).

### F96 — Pool de emisores y estelas por tiempo (RFC-029, corte 029b)
`FxBus` reusa los emisores de cada tipo en vez de crear uno por efecto, y las estelas de los proyectiles salen por tiempo: igual cantidad a 30, 60 o 120 fps.

Hecho, review NEEDS WORK corregida (`reviews/REVIEW-F96-fx-pool.md`), falta playtest. `FxBus`: pool por tipo (libres + activos, el más viejo se reinicia al llegar al tope), tope `ParticleType.pool_max` (respaldo `FxBus.max_pooled_per_type` 12), armado completo al cargar (`prewarm`, antes de que `MatchSeed` siembre: un `play` caliente no consume el RNG global, probado con ventana). `SpriteParticles.pooled` + `replay()` (`restart(true)`, se oculta al terminar). `FxTrail` (`scenes/fx/fx_trail.gd`, `interval_s`, `emitting`, señal `puffed`) reemplaza `TRAIL_EVERY` en `rock_projectile`, `wrath_strike`, `swarm_projectile`, `fireball_projectile` y `ranged_shot` (`ShotLook.trail_every / 60` s). `pool_max`: `wrath_trail` y `rock_trail` 80, `spit_trail` 160 (ritmo × vida × 4 proyectiles × 1,25), explosiones de wrath 8. Pool total 596 nodos; prewarm +16,1 MB estáticos, +21 MB RSS, arranque +4–29 ms (ruido). Lectura del pool desde los hijos (`debug/fx_pool_count.gd`): `fx_gallery` la imprime en `check_tick` y a los 4 s; `rock_hit` imprime `fx_trail <n>`; harness de solo lectura `agent/harness/fx_pool_probe.gd`. Bench `debug/fx_pool_bench.tscn` (4 wraths, 4 ekbas, 4 rocas en vuelo; con ventana): picos 60–64/80, 124/160, 60–64/80 sin tocar el tope a 30, 60 y 120 fps; a los 4 s todo ocioso; `play` de estelas 3,7–11,8 µs; explosión de wrath 0,19–0,36 ms por evento (criterio 3 enmendado, RFC-029 §13). Estelas: 60 en 2 s a 30 y a 120 fps (antes 30 y 120). `ai_match` A/B (copia en el scratchpad): `ai_vs_trivial` seed 1 3 min `047a3a7c…`, seed 7 `--npcs` `ac6b9176…`, seed 7 `d0cd7283…`, iguales. Pendiente del playtester: criterio 4 (capturas `rock_hit`/`wrath_splash`), `f96_pool.json`, roca real en `rock_hit`, arreglo de `f23_fx_gallery.json` (los emisores ahora se llaman `<tipo>_<n>`). Deuda: `carry_rope.gd` y `red_vortex.gd` siguen instanciando (tarea del RNG de `MatchSeed`).

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F96-fx-pool.md`). Playtest con ventana PASS (`agent/out/pt96/`):
- Pool: 596 hijos, 0 excesos en 10 `check_tick` y queda ocioso a los 4 s.
- Roca real a 27 y 55 fps: 44 contra 43 puffs; esta Mac no llega a 120 fps en `rock_hit`.
- Cuatro escupidas de Earthfling llegan a un pico de 31/160 y ninguna estela se corta.
- La roca se ve idéntica a pt95.
- `f23_fx_gallery` quedó arreglado y `final_wrath_splash` da AGENT_OK.
- En `wrath_splash` el ambiente cambia de una corrida a otra porque el banco sortea el bioma con `randi()` sin semilla, no por F96. El destello del efecto es el mismo.

Deuda: Wrath múltiples en vuelo sin probar en juego (sí en el bench).

### F97 — Luces de efectos (RFC-029, corte 029c)
Los poderes iluminan el suelo y lo que tienen cerca: cada ráfaga con `ParticleType.light` pide una `OmniLight3D` sin sombra a un pool de la capa `Look/Layers/FxLight`, con tope por preset (bajo 0, medio 8, alto 16).

Hecho, review NEEDS WORK corregida (`reviews/REVIEW-F97-fx-lights.md`), falta playtest. Cambios:
- Nuevos: `FxLightSpec` (`scenes/fx/fx_light_spec.gd`) y `FxLightLayer` (`scenes/world/look/fx/fx_light_layer.gd` + `.tscn`, quinta capa del rig, KP5 en la galería).
  - Prioridad = energía × nivel × alcance / distancia a la cámara. Con el tope lleno roba la luz más débil.
  - Mientras una luz sube (`attack_s`) compite con su pico (B1).
  - Sin luces en modo clásico, con la capa oculta, en headless ni en el dedicado.
- `SpriteParticles` pide la luz por el grupo `fx_light_pool`, atada al emisor: un emisor del pool que vuelve a sonar reinicia su luz.
- `LookQuality.fx_max_lights` (solo el grupo 029).
- `data/fx/lights/{wrath_burst,heal_glow,cast_glow,rock_spark,teleport_flash}.tres`, con el color medio del atlas, en `wrath_explosion1` (Wrath, Fireball, Swarm), `heal`, `cast_*`, `summon`, `teleport_*` y `rock`.
- Debug: `debug/fx_light_steal.tscn` (casos A–D del robo, `fx_robo total ok`; con la prioridad vieja falla A, C y D); `fx_gallery` imprime `fx_luces activas`.
- Harness de solo lectura `agent/harness/fx_light_probe.gd`; fixtures `agent/fixtures/f97_{rock_hit,wrath_splash}_persephone.tscn` (bioma fijo para comparar capturas).

Medido en `vfx_lab`, cámara `fx`, medio, `--fixed-fps 60`:
- Criterio 1: suelo a 6 m de `wrath_explosion1` +39,9 % de pico y ≥ 30 % durante 0,25 s (ON contra OFF con la misma semilla, solo puntos no tapados por sprites). La luz dura 0,58 s.
- Criterio 2: 8/8 en medio, 0/0 en bajo y 8/16 en alto (8 tipos con luz).
- Criterio 3: 0 luces con sombra.
- Criterio 4 (proxy enmendado en §13): CPU de render ON 0,41–0,42 ms contra OFF 0,41–0,43 ms; 413,9 draws en ambos; GPU no medible en Metal.
- Criterio 5: con la capa apagada la luminancia es igual a la de antes (Δ ≤ 0,001).
- `ai_match ai_vs_trivial` 3 min, A/B sobre dos clones del mismo árbol: seed 1 `047a3a7c…`, seed 7 y seed 7 `--npcs` `0f34e004…`, iguales.
- Capturas antes/después de Wrath, Heal, `rock_hit` y `wrath_splash` para el usuario (scratchpad de la sesión, `f97/compare/`).

**Ronda tras el playtest (FAIL por cortes, 2026-10-16).** En la pelea de 3×3 `check_tick`, 18 luces robadas mientras brillaban se apagaban de golpe.
- Ahora una luz que pierde su lugar (robada, o su emisor vuelve a sonar en otro sitio) pasa a fundirse en su propio nodo durante `fade_out_s` (0,1 s), y la luz nueva toma un nodo libre.
- Los nodos que se funden no cuentan para el tope: como máximo `max_fading` (4) a la vez. Si no hay lugar, se corta como antes.
- `report()` suma `fundiendo <n>`.
- Con `agent/flows/pt97_robo.json` y `fx_light_watch`: 0 cortes (`cortes_lugar 0`, `cortes_salto 0`). Activas 8/8 con hasta 4 fundiéndose, 0 sombras y `fx_robo total ok`.
- El digest A/B sigue igual: seed 1 `047a3a7c…`, seed 7 y seed 7 `--npcs` `0f34e004…`.

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió (`reviews/REVIEW-F97-fx-lights.md`): prioridad durante el ataque y renombre a `wrath_burst`. Playtest con ventana (`agent/out/pt97/` y `pt97b/`):
- Lab: el suelo se ilumina +16 % y la luz se apaga sola.
- Presets 0/8/16, 0 sombras; KP5 deja la escena como estaba sin luces.
- En juego: Wrath y Heal iluminan el suelo y las criaturas.
- `fx_robo total ok`.
- Tras la corrección del fundido (`fade_out_s` 0,1 s, `max_fading` 4), 0 cortes de golpe en la pelea 3×3, contra 18 antes.
- `final_wrath_splash` y `f95_vfx_lab` dan AGENT_OK.

Criterio 4 (GPU) cubierto por el proxy enmendado: CPU de render y draws sin aumento.

Pendiente de la opinión del usuario: la intensidad (hoy sutil).

### F86 — Clips precalentados (RFC-027, corte 027b)
La primera orden a muchas unidades no traba el cuadro: el cliente arma de antemano, repartido entre cuadros, el primer cuadro de cada clip (quieto, correr, atacar) del modelo, y la malla del cuerpo se reasigna solo cuando cambia el cuadro o el rol.

Hecho y cerrado (2026-10-16). Review PASS con nits (`reviews/REVIEW-F86-clip-warm.md`). Primer playtest FAIL por 45,9 ms de precalentado en la Gargoyle; tras la corrección (cola repartida entre cuadros), el playtest con ventana dio PASS: primera orden de 150 en 6,1–6,4 ms, máximo de 13,9 ms y 1 malla por cuadro, animaciones sin cuadros congelados (`agent/out/pt86b/`). Deuda: hornear los cuadros de clip a `.res`; la orden de atacar con 150 tarda 17 ms (RFC-027). Detalle original: `ClipPosePlayer` (`scenes/world/components/clip_pose_player.gd`): `_warm_model()` en `setup` encola (cola estática compartida) los primeros `warm_frames_per_role` cuadros de cada rol, una vez por modelo y clip, solo si `BodyCatalog.loads_meshes()` (el dedicado headless no arma nada); `_process` (solo encendido mientras hay cola) arma mallas hasta `warm_budget_ms` por cuadro (4 ms, mínimo una malla), así ningún cuadro paga más de un OBJ por el precalentado, ni al cargar ni al invocar. Si un cuadro se muestra antes de que la cola llegue a él, se arma en el momento como antes. `warm_frames_per_role` 0–8 (por modelo: el primer cuerpo decide; 0 apaga). Log por cuadro solo con el argumento `--clip-warm-log`; se sacó `warm_us_by_model`. `_apply_frame_mesh` no escribe malla, posición ni rotación si el cuadro, el rol, la malla y la base no cambiaron. Reloj del clip sin cambios. Flow `agent/flows/perf027_first_order.json` sobre `debug/selection_many.tscn`. Medido: precalentado por cuadro máx. 14,6 ms en `selection_many` (1 malla por cuadro, 9,9–14,6 ms; antes 21–45,9 ms por modelo de una vez) y 13,7 ms al invocar la Gargoyle en `summon_unit` (`f25_flying_summon`); primera orden de 150 36,4 → 6,2 ms (`Orders.last_apply_us`); `ai_match ai_vs_trivial --seed=1 --minutes=3` digest `328438de…`, igual al último par A/B; corrida anterior: `rules_suite` PASS, `f78_many` y `f79_roster` AGENT_OK. Desvío: se precalienta solo el cuadro 0 de cada rol (cada OBJ cuesta ~9–14 ms en GDScript; todos los cuadros serían 1,0–1,6 s por modelo); los cuadros siguientes se siguen armando la primera vez que aparecen. Si el cuerpo que encendió la cola se libera antes de vaciarla, la cola espera al próximo `setup` (los cuadros faltantes se arman en el momento). Fuera: hornear los cuadros a `.res`.

### F85 — Medición de rendimiento con 150 criaturas (RFC-027, corte 027a)
Tabla de costos por subsistema (selection_many 0/50/150, quietas y en marcha, y partida real) que confirma o descarta H1.

Hecho y cerrado (2026-10-16). Review sin bloqueantes (`reviews/REVIEW-F85-perf-measure.md`). Corte de medición sin cambio de producto: sin playtest de jugador; el reviewer repitió la corrida y las partes independientes de BodySeparation reproducen a ±1 ms. Las cifras de ahorro de pasto y sombras se corrigieron al render de CPU (RFC-027). `agent/perf/frame_budget.gd` (`FrameBudget`, reemplaza a `agent/perf/perf_probe.*`, borrado, y absorbe sus barridos por cuerpo): ventanas de 120 frames de pared (media, p95), ticks por frame, tick de script (de `SceneTree.physics_frame` a su `_physics_process`, que corre último), tick completo (entre dos `physics_frame` del mismo frame), proceso de scripts (de `process_frame` a su `_process`), render de CPU (`frame_pre_draw` → `frame_post_draw`, incluye la espera de la GPU), contadores existentes (`BodySeparation`, `TargetPicker`, `SideVision`, `AiSide.tick_ms`, `Orders.last_apply_us`), draws, prims, VRAM, RSS; render base con el árbol en pausa y restas EN VIVO (sin pasto, sin barras, sin sombras del sol, sin mallas de cuerpos, cada una contra una base tomada justo antes); `PERF_TABLE <json>` y `agent/out/perf027/<caso>_r<n>.md`; corta con RSS + VRAM > 2,5 GB. Fixtures `agent/fixtures/perf027_many.tscn` (+ `_0`, `_50` heredadas, solo `own_count`) y `perf027_match.tscn` (`debug/ai_match.tscn` + `FrameBudget`); flow `agent/flows/perf027_many.json`; `agent/run_perf027.sh RUN [casos]` (de a uno, `godot_busy` antes de cada caso, watchdog de RSS y tiempo, marca `CONTAMINATED` si aparece otro Godot) y `agent/run_perf027.sh table`. Medido 2 veces cada caso, máquina libre, 1280×720, medio, con el `ClipPosePlayer` final de 027b: 150 quietas 245 ms de frame (8,0 ticks/frame en los 120 frames, tick 30 ms, separación 24,7 ms), 150 en marcha 227–229 ms (8,0 ticks, tick 28 ms, separación 20,5 ms); 50: 21,7 / 29,5 ms (1,3 / 1,8 ticks); 0: 16,4 ms; partida ai_vs_trivial semilla 1 (≈45 cuerpos) 24,7 ms con tope 60 (1,5 ticks, tick 4,9 ms, render de CPU 16,9 ms); explicado 100 % con el render medido (109 % con la base en pausa, que se superpone con la CPU). **H1 confirmada** para 150 (el tope de 8 pasos en cada frame; el juego corre a ~0,55× de tiempo real); con 50 y en la partida, 1,3–1,9 ticks por frame. Digest de la partida con ventana y medición `328438de…`, igual en las dos corridas y al de 027b. Desvíos: las restas de capas se hacen en vivo (en pausa el pasto, tras apagarse y prenderse, dibuja una fracción de sus primitivas); macOS presenta como mucho al refresco (120 Hz, 8,33 ms) aun con `--disable-vsync`, así que las paredes por debajo de 16,7 ms y las restas en 0/50 quedan cuantizadas y ruidosas; `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` son el máximo del último segundo y se informan solo como referencia. Deuda vista: `debug/orders_group.gd` con `own_count = 0` divide por cero en `_grid` (el caso 0 queda sin Druid); en este flow la orden de 150 sobre el Druid tarda 17,7 ms (`Orders.last_apply_us`, criterio de 027b ≤ 12 ms, medido allí con otra orden en 6,2 ms).

### F112 — Datos y cuerpos del bestiario (RFC-030, corte 030a)
Cada dios tiene en datos sus 10 criaturas más el Manahoar, con el nivel de mago de cada entrada como en sacengine `computeDefaultSpells` (1,1,1,2,3,4,5,6,7,9). Las 35 nuevas tienen clips de reposo, carrera, ataque y disparo, además de cuerpo horneado. El juego no cambia: `GameData.book(god)` sin nivel devuelve el libro de nivel 1 de siempre. Criterio: `res://debug/f110_bestiary_gallery.tscn` (F6, Enter para ciclar idle/run/attack) muestra las 51; `python3 tools/audit_unit_parity.py` da 0 faltantes; el digest de `ai_match` seed 7 no cambia, con y sin NPC.

Hecho; review NEEDS WORK corregida (`reviews/REVIEW-F112-bestiary-data.md`), falta playtest. Cambios:
- `tools/export_stats.py`: `books.json` con las 11 criaturas y `"levels"`. Exporta `stance1` (slot 0) a `stance_animation` en `creatures.json` (nueva clave en las 71) y su clip para las criaturas de nivel ≥ 2 (`STANCE_POSE_MIN_LEVEL`). `_export_all_frames` corta sacengine al tener todos los cuadros del SXSK y borra los OBJ parciales; al reusar un clip exige la cantidad de cuadros del SXSK.
- `tools/bake_bodies.gd`: hornea esas 35 desde el cuadro 0 de `stance1`; las 16 de nivel ≤ 1 siguen desde `idle0` hasta RFC-023.
- `tools/audit_unit_parity.py`: cubre las 51 y compara cada clip contra su SXSK. `tools/audit_body_pose.gd` mide el clip del horneado (`pose_source`).
- `scenes/data/game_data.gd`: `book(god, max_level := 1)` y `creature_level`. `debug/unit_parity_gallery.gd`: `max_level` y `row_per_god`.

Digest seed 7: sin NPC `d0cd7283…` igual en todas las corridas. Con NPC, `08551430…` igual hasta antes del re-horneado de esta ronda. Después da `ac6b9176…`: el horneado tomó el clip nuevo del Farmer (`epez`, de 028c, exportado a las 04:12), y con la entrada vieja de `epez` vuelve a `08551430…`. El cuerpo del Taurock no lo cambia. Disco: `cache/look/anim_f37` pasó de ~1,6 a ~3,8 GB; los clips `stance1` de esta ronda suman ~0,7 GB más. `bodies.json`: las 32 entradas posadas de antes siguen idénticas.

**Declarado (cambio de juego visible):** el Taurock NPC (`eber`, en `village_taurock` y `ai_npc_load`) ahora sale de un clip. Su radio pasa de 0,711 a 0,986 m, su alcance de 1,745 a 2,374 m y su altura de 5,79 a 2,95 m. Además, anima con sus clips en las escenas con mallas.

**Pose (cierre):** hornear desde `stance1` no corrigió los 5 dudosos: el cuadro 0 de `stance1` da la misma altura que el de `idle0`. La causa probable es la malla respecto del desplazamiento de raíz del SXSK; queda para investigar en RFC-023. Se mantiene `stance1` porque es la pose de reposo fiel. Hay `BodyPoseOverride` en `data/bodies/pose_overrides.tres`, con la altura medida por `tools/audit_body_pose.gd` y la cápsula al alto del cuerpo, para Yeti (`aprc`: +0,40 m, cápsula 6,71 m), Netherfiend (`prcy`: +1,04 m, 6,25 m), Hellmouth (`ddmn`: +1,68 m, 10,47 m) y Rhinok (`edmn`: +1,40 m, 9,52 m). `audit_body_pose` da OK en 67 modelos; el único FAIL, declarado, es **Phoenix** (`fdrg`): flota +3,26 m con `DFst` y su cápsula mide 12,96 m contra 9,70 m de la pose. Pasa a 030e. Capturas de los 3 roles: `agent/out/f112/sheet_pose_override.png`. Rhinok no está cabeza abajo. Digest sin NPC con los overrides: `d0cd7283…`, igual. Con NPC: `ac6b9176…`, por el cuerpo del Farmer de 028c (declarado en F94). Las híbridas (Blight, Gremlin, Ikarus, Pyrodactyl, Seraph, Dragon, Hellmouth, Rhinok, Silverback) se completan en 030e.

**Cierre (2026-10-16).** Review con NEEDS WORK, corregido en dos rondas (`reviews/REVIEW-F112-bestiary-data.md`). Playtest con ventana (`agent/out/pt112/`):
- Las 51 criaturas están en la galería y cambian de clip en los 3 roles.
- En nivel 1 el juego no cambia (`f25_summon` y `f21_pick` dan AGENT_OK, con las 4 criaturas de siempre).
- El Taurock mide 2,95 m y anima.
- Yeti, Netherfiend y Hellmouth están corregidos.

Desvíos declarados:
- **Rhinok:** ya no queda cabeza abajo, pero en el idle flota entre 0,6 y 0,75 m. Su `stance1` (`Eds1`) es el mismo tag que el vuelo. Pasa a 030e (híbridas) junto con Phoenix.
- **Squall (`alab`):** idle y attack usan el mismo clip, `ABa1`, porque así viene en `creatures.json`. Hay que confirmar contra el CRE8 original en RFC-023.
- **Pies algo hundidos (~0,3 m):** Storm Giant, Necryl y Basilisk.
- **Silverback:** un cuadro del idle cae 1 m bajo el suelo.

Todo esto pasa a RFC-023, junto con la causa de raíz (la malla respecto del desplazamiento del SXSK).

### F113 — Nivel del mago y libro por nivel (RFC-030, corte 030b)
El nivel del mago es una regla de partida: `MatchRules.wizard_level` (1–9, default 1 en el script) → `WizardSpawner._place` → `wizard_body.level` (replicado como `god`) → `Spellbook._rebuild` con clave (dios, nivel) → `GameData.book(god, level)`. El libro muestra solo lo de nivel ≤ el del mago (sacengine `getSpells`); lo de nivel superior no se dibuja y el servidor lo rechaza («Blanco inválido»). Criterio: `res://debug/f111_bestiary.tscn` (F6, Enter, `creature_5`…`creature_8`, clic derecho sobre una enemiga).

Hecho; review NEEDS WORK con ronda de datos (`reviews/REVIEW-F113-wizard-level.md`), falta playtest. Cambios:
- `scenes/data/match_rules.gd` (grupo «Libro»), `scenes/world/wizard/wizard_body.gd` y `.tscn` (`level`), `wizard_spawner.gd`, `scenes/world/spells/spellbook.gd` (TODO N2: un cambio de nivel borra los cooldowns; se resuelve con la XP).
- Banco: `debug/bench_rules.gd` (`human_god`), `debug/ai_match.gd` (`_apply_human_god` antes de poblar), `debug/f111_bestiary.tscn`, `debug/rules/f111_bestiary_<dios>.tres` ×5 (nivel 9, 60 almas, maná lleno) y `f111_level3_james.tres`. Enemigas: las nuevas de nivel 2 y 3 del dios, quietas en el anchor (1454, 1601), a unos 80 m al noroeste del mago del slot 1; el camino no pasa por el atasco de (1488, 1511).

Medido:
- Casillas: nivel 9 → 11 en orden de `spell_order` (los 5 dioses); nivel 3 → 6; nivel 1 → las 4 de siempre.
- A 1280×720 el libro de 11 (y 624–720) no se superpone al panel de seleccionadas (y 206–514); el bloque de stats (F92) no se pisa.
- Mago de nivel 3 pide `nomd` → «Blanco inválido», sin criatura.
- Ronda 2, con ventana, sin rellenar maná ni matar por script (escena reiniciada por criatura): en Charnel y Stratos las 8 de ≤ 1000 de maná pegan o disparan (ranged en 1,0–1,6 s; melee en 7–10 s tras 40–75 m). Mueren en combate Blight (2 veces) y Squall (2 veces), alma del slot 2 a 1,5–1,7 m del cadáver. El mago termina con 1500 de vida en las 8.
- «Sin maná» con 1000 de maná: las de 1100, 1300 y 1900 (el RFC nombraba solo 1300/1900).
- Digest seed 7: sin NPC `d0cd7283…`, con NPC `ac6b9176…`, iguales. `rules_suite` PASS.

Desvíos declarados: el atasco en (1488, 1511) (le pasa también a la Trogg de nivel 1; se revisa tras 027c3/027d). El criterio 4 se probó con `request_summon` en solo (misma `_try_summon` que la RPC). Las medidas de tiempo de cuadro de la ronda 1 (pico de convocatoria 22–65 ms, precalentado ≤ 19,2 ms/cuadro) pudieron correr junto a otro Godot por el fallo viejo de `godot_busy.sh`: contaminadas, se repiten en el playtest.

**Cierre (2026-10-16).** El review dio NEEDS WORK y se corrigió con una ronda de datos del banco (`reviews/REVIEW-F113-wizard-level.md`). Playtest con ventana y solo input real: PASS en los 5 criterios (`agent/out/pt113play/`).
- Libro: 11, 6 y 4 casillas según el nivel.
- Combate: 14 de 14 criaturas nuevas convocan, caminan y pegan o disparan; 1100/1300/1900 dicen «Sin maná».
- Almas: 5 muertes en combate, y cada una deja su alma roja visible.
- Online en nivel 1: AGENT_OK.

Hallazgos:
- **Rendimiento:** la primera convocatoria de un modelo nuevo deja cuadros de hasta 121 ms y unos 40 cuadros de más de 25 ms. No viene del precalentado (2 cuadros de unos 15 ms), sino de armar los cuadros de clip siguientes la primera vez que aparecen. Va a RFC-027 como corte «hornear cuadros de clip a .res».
- **Visual:** junto al anchor de Stratos y Charnel se ve un cilindro naranja sin textura. Parece el mismo caso del cactus visto de cerca en F93, y queda para verificar.

### F87 — Costo de BodySeparation (RFC-027, corte 027c3)

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F87-body-separation.md`): equivalencia bit a bit, con 0 diferencias en ~920 000 llamadas, fuzz hostil incluido. Con 150 cuerpos:
- Quietas: la separación baja de 24,8 a 4,3–4,4 ms por tick, y el frame de 245 a 22 ms.
- En marcha contra el Druid: de 20,6 a 5,0 ms.

Playtest con ventana (`agent/out/pt87/`):
- **Destino lejano (160 m):** las 150 caminan toda la ventana, con 5,08–5,11 ms de separación por tick, ~1,96 ticks por frame y un frame de 32,7 ms. Queda 0,1 ms sobre la meta de 5 ms. Se acepta como desvío declarado: el barrido sin instrumento da 3,4–4,2 ms, y 027d apunta a ≤ 3 ms.
- **Marcha y llegada:** sin cuerpos encimados (`min_ratio` ≥ 1,5 tras reformar).
- **Partida de 2 min:** AGENT_OK.
- **Regresión:** `f78_many` y `perf027_first_order` dan AGENT_OK.

### F88 — Apiñamiento en BodySeparation (RFC-027, corte 027d)

> **Reemplazado (2026-10-18, RFC-035 035h/035i):** la grilla `NavGrid` se borró; la navegación es el navmesh de Godot (F201–F203).

**Ronda de corrección (2026-10-16), sobre `reviews/REVIEW-F88-crowding.md`.** Implementado en `scenes/world/body_separation.gd`, `scenes/world/body_grid.gd`, `scenes/world/make_way.gd` y `debug/crowd_cases.gd` (caso `crowd_150` en `rules_suite`). Es un desvío del port: con `BodySeparation.make_way` apagado vuelve la regla de sacengine (además hay que apagar `wizard_passes_own`).
- **Paso 1, sin cambio de conducta:** se extrajo `MakeWay`, se documentó el re-archivado a mitad del tick y el «modo original» de `use_grid`, y `frame_budget` guarda y restaura las tablas. El A/B sobre clones congelados da igual en los tres casos: seed 1 `3678de90…`, `ai_duel_seeded` seed 7 `2544ee1a…` y seed 7 `--npcs` `0bc14063…`.
- **Paso 2, digest nuevo:**
  - El desliz queda solo para el grupo `unit`.
  - Los pedidos de ceder respetan el vencimiento y toman la dirección del caminante más cercano.
  - No ceden las criaturas que fingen estar muertas o están ocultas (`is_targetable`) ni las que tienen `ordered`.
  - Las que cedieron o fueron empujadas vuelven a su lugar 60 ticks después.
- **`crowd_150` (orden a 80 m):**
  - 0 trabadas > 2 s (antes del corte, 28); la peor quedó quieta 0,78 s.
  - Todas llegan en 15,2 s.
  - `off_slot` = 45 de 150 a más de 2 m (111 sin el regreso), con un umbral de 60.
  - `sep_ms` medio: 2,1 ms.
- **Causa del `off_slot`:** el reparto greedy de casillas en `Orders` cruza la formación. Queda como deuda de `Orders`.
- **`run_perf027.sh` con 150 cuerpos (RUN `d2`, archivo `d2_many150_r1`):**
  - Quietas: separación 1,83 ms por tick (c3: 4,3), tick 6,95 ms, 1,37 ticks por frame, frame 22,8 ms.
  - En marcha: separación 2,77 ms (c3: 5,0), tick 11,3 ms, 2,06 ticks por frame, frame 34,4 ms.
- `rules_suite` PASS.

**Línea base de digests desde F88** (`ai_match`, 0 errores):
- `ai_vs_trivial` seed 1 (3 min): `9037ccbcd3befa687919081932d3893d57c9e76715855c442e29be7ef4de70d5`.
- `ai_duel_seeded` seed 7 (2 min): `039b7736fbc8f48f00734f620e6a1a0fbc294f001ec0efeac27b3795f241a2fe`.
- `ai_duel_seeded` seed 7 `--npcs` (2 min): `ff5e0d1e1bf7290610d639109207adf975d0b5b079bb0635abc861a75d3b633b`.

**Ronda 2 tras el playtest (2026-10-16).** El playtest con ventana encontró criaturas trabadas para siempre al pie de los tipis (Manahoar29 y otras, cerca de (1488, 1511)).
- **Causa:** la NavGrid libera un nodo de 5 m por su centro, pero `line_clear` toma todo su cuadrado. La caja del tipi entra ~1 m en ese cuadrado y la recta la atraviesa. Además, Godot no desliza de frente contra la pared (`wall_min_slide_angle` de 15°).
- **Arreglo en la navegación:**
  - `NavGrid.crosses_box`: segmento contra caja con holgura `box_clearance_m` 0,5.
  - `line_clear` exacto contra cajas.
  - `find_path` pone primero el nodo de partida si el primer tramo cruza una caja.
  - `PathFollower._may_advance`.
- **Caso nuevo `debug/crowd_tipi.tscn`:** de 2 trabadas para siempre a 0; todas llegan en 21,8 s.
- `rules_suite` PASS. En la ventana, Manahoar29 sale del tipi.
- **Digest:** seed 1 pasa a `2ad66932…`; seed 7 queda `039b7736…` y con `--npcs` `ff5e0d1e…`, sin cambio.
- **Descartado:** `wall_min_slide_angle = 0`. Era más fiel al deslizamiento del original, pero solo no alcanza.

Deuda:
- 31–35 pares encimados que tiemblan junto a la roca grande.
- Verificar a Trogg7 contra su casilla.
- El reparto greedy de casillas de `Orders`.

**Ronda 3 (2026-10-16): la ladera junto a la roca.** La causa era el `floor_max_angle` de Godot (45°): convertía en pared una ladera de unos 48°, cuando sacengine no tiene límite de pendiente. Arreglos:
- `unit.tscn` pasa a `floor_max_angle` de 85°.
- `Orders._match_rows`: las filas se asignan por avance y, dentro de cada fila, de izquierda a derecha, para que la formación no se cruce. Solo aplica con más de una fila; es un desvío del port, porque sacengine forma una sola línea de 12.
- `BodySeparation`: también hace slide cuando la segunda pasada anula el paso.

Caso `debug/crowd_rock.tscn`:
- Trabadas: de 29 (34,7 s) a 0.
- Manahoar29 queda a 0,27 m de su casilla.
- Todas llegan en 13,2 s.

`rules_suite` y `crowd_tipi` dan PASS.

Digests nuevos: seed 1 `1bb3a8b0…`, seed 7 `12633046…`, seed 7 `--npcs` `ff7b9e73…`.

Pendiente:
- El regreso a su lugar cuando un corredor cruza la formación (2 de 149).
- Los magos siguen con 45°.
- La escena del caso no repite cifras exactas entre corridas: hay que revisarlo.

**Ronda 4 (2026-10-16).**
- **Magos en laderas:** el `floor_max_angle` del mago también pasa a 85°. En el caso `debug/wizard_slope.tscn`, el mago sube 18 m en 3,8 s; antes se frenaba a 13 m.
- **Regreso a su lugar:** `MakeWay` ahora espera 20 ticks en lugar de 60 y vuelve al paso propio de la criatura. Casos `crowd_return` (antes 4 fuera de lugar, ahora 0) y `crowd_return_held` en `rules_suite`.
- **Determinismo:** la variación entre corridas venía del banco: `orders_group.tres` no fijaba `match_seed`. Ahora los casos usan `debug/rules/crowd_cases.tres` (semilla 88) y dos corridas de `crowd_rock` dan resultados idénticos.
- **Digests nuevos:** seed 1 `9e595f8c…`, seed 7 `f98fbe79…`, seed 7 con `--npcs` `cfb2c4ff…`.

**Ronda 5 (2026-10-16).** Un corredor que cruzaba una formación quieta arrastraba criaturas por delante, hasta unos 20 m, y las desplazadas no volvían a su lugar. Arreglos:
- `BodySeparation._without_carry`: sin empuje en el sentido de la marcha sobre las quietas o las que ceden.
- `MakeWay.slide`: solo las que caminan piden paso.
- `MakeWay`: conserva el «home» original. Antes lo borraba a menos de 0,15 m y la criatura iba derivando.

Caso `crowd_return_grid`: el desplazamiento máximo baja de 4,09 a 1,76 m y quedan 0 criaturas fuera de lugar (antes 16). `rules_suite` PASS completo; `crowd_tipi`, `crowd_rock` y `wizard_slope` PASS.

Digests nuevos: seed 1 `752c58f7…`, seed 7 `4915c884…`, seed 7 `--npcs` `44b89859…`.

Deuda: si el corredor se detiene sobre el lugar de otra, esa criatura no busca el punto libre más cercano; tampoco cede hacia el lado más libre.

**Cierre (2026-10-16).** Playtest final con ventana (`agent/out/pt88d/`):
- **Corredor A:** cruza la formación sin arrastrar a nadie. Desplazamiento máximo de 0,90 m; todas vuelven a 0,15 m o menos.
- **Trabadas:** ninguna; la peor quedó quieta 0,40 s.
- **Errores:** ninguno.
- **Regreso a su lugar tras un corredor que sale:** lo cubre el caso headless `crowd_return_grid`.

Deuda declarada:
- Si un corredor queda detenido pegado a la formación, las que estaban en ese lugar quedan corridas 1–1,35 m.
- Ese corredor perdió la orden a 7 m de su punto, junto al borde: falta investigarlo.
- 5 de 150 terminan a más de 2 m de su casilla (reparto de `Orders`).

### F114 — Efectos del nivel en el mago (RFC-030, corte 030c)

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F114-level-effects.md`): `CastTime` coincide con sacengine en 7 casos verificados a mano. Playtest con ventana PASS (`agent/out/pt114/`):
- Producto en nivel 9, con HUD de 1950/1900.
- Styx y Rhinok se convocan. El lanzamiento de Styx dura 2,07 s.
- Trogg: 12 ticks en nivel 9 contra 25 en nivel 1. Manalith de la IA: 5,55 s.
- Contra la IA de producto sin errores; la IA convoca Flurry (criatura nueva).
- Se actualizaron los 14 flows con aserciones viejas, con los plazos del fantasma ×1,3. `f20_solo`, `pt20_solo` y `f20_client_a/b` dan AGENT_OK.
- `rules_suite` PASS.

Cambios de ritmo declarados:
- El fantasma tarda más en volver, porque su vida máxima ahora es 1950.
- La IA de producto convoca criaturas de nivel alto.

Escenas de `debug/` que heredan el nivel 9 sin medir al mago: `ability_spit`, `advance_tick`, `biome_gallery`, `camera_edges`, `idle_tick`, `look_bench`, `look_gallery`, `melee_duel`, `move_order`, `rock_hit`, `sky_motion`, `state_tick`, `village_net` y `walk_order`.

Deuda:
- `CastTime.frames()` no tiene llamadores.
- `f111_level3_james` sin stats.
- 10 flows actualizados sin correr.
- Aviso de mayúsculas en el ícono `HRba.png` (se guarda como `hrba.png`).
- En la partida de prueba contra la IA, su mago murió dos veces sin que el humano lo atacara. Falta investigar la causa.

### F98 — Rayo fiel de Lightning (RFC-029, corte 029d)
Hecho (2026-10-16). Lightning dibuja un `BeamFx`, port de `LightningBolt` de sacengine (`state.d:2815-2850, 16322-16386`, `sacobject.d:2189-2295`, `renderer.d:264-272, 1873-1905`), en lugar de `wrath_explosion1`. Se apoya en `BeamType.tres`, `FxBus.broadcast_beam` (un RPC unreliable por rayo) y un pool de 6.

Review NEEDS WORK, corregida (`reviews/REVIEW-F98-lightning.md`). Playtest PASS (`agent/out/pt98/`):
- El rayo vive 1,050 s y cambia de forma 10 veces, igual que el original.
- Lámina lateral `lamina_lateral.png`.
- Dedicado + cliente: el cliente ve el rayo (1,050 s) y el servidor no da errores.
- `final_wrath_splash` AGENT_OK.
- El digest de seed 1 no cambia.

**Cerrado (2026-10-16).** El desvío de 15 m que se vio en el cliente de red era un error del harness, no del juego: el blanco era un Farmer que murió y salió del grupo `unit`, así que el harness midió contra otra criatura. Con el harness corregido, que ahora mide contra el nodo que sigue el rayo, el cliente informa blanco Taurock2 y desvío de 0,00 m (`agent/out/pt98/net2/`).

Follow-ups para un RFC de simulación:
- El daño y las chispas deberían llegar en el frame 12.
- Falta el redireccionado por `collideRay`.

### F89 — Cuadros de clip horneados a .res (RFC-027, corte 027h)
Hecho y cerrado (2026-10-16). `tools/bake_clips.gd` hornea 16 633 cuadros de clip a `cache/baked/clips/*.res` (solo geometría, 942 MB, incremental; `-- --force` si cambia `obj_mesh.gd`). `ClipPosePlayer` los carga con `ResourceLoader` (~1 ms) y, si no están, cae al OBJ.

En la primera convocatoria de un modelo nuevo, los cuadros de más de 25 ms bajan de 31–97 a 1. Primera orden de 150: de 3,3 a 2,8 ms. Digest igual. Malla idéntica bit a bit. Review PASS (`reviews/REVIEW-F89-baked-clips.md`). Playtest con ventana PASS (`agent/out/pt89/`):
- Partida contra la IA: 1587 cuadros horneados y 0 armados desde OBJ, mallas con textura.
- Primera convocatoria del Flummox: 1 cuadro de más de 25 ms en 4 s (63,4 ms, el de la convocatoria).
- Galería: clips a 29,9/30.

No hay captura de una criatura convocada corriendo en partida porque la cámara sigue al mago; la reemplaza la galería de paridad en «run».

Deuda: el cuadro de la convocatoria sigue en 62–74 ms. Son 38 ms fijos de convocar más la primera vez del modelo (material y pipeline). Propuesta de corte: precalentar los modelos del libro al empezar la partida y perfilar el costo de convocar.

### F115 — Elegir el nivel del mago (RFC-030, corte 030d)

Fila «Nivel del mago» (1–9) en el boot, junto al rival. También existe `--level=N` para el servidor dedicado. El nivel elegido se reinicia en `play_solo`, `host_lan` y `return_to_boot`, así que no queda pegado de una partida a otra. En red lo decide solo el servidor.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F115-level-pick.md`). Playtest con ventana PASS (`agent/out/pt115/`):
- **Nivel 4 contra la IA:** Maná 1400/1400, libro con 7 casillas y los dos magos en nivel 4.
- **«Jugar solo»:** nivel 9, Maná 1900/1900, libro con 11 casillas.
- **Dedicado con `--level=2`:** el cliente ve Maná 1200/1200 y libro con 5 casillas (`oham, ycro, palk, sohe, guls`).
- **Errores:** ninguno.

Deuda:
- Desde la partida no hay forma de volver al boot con input, así que el reinicio del nivel dentro del mismo proceso no se pudo probar como jugador.
- El dedicado se probó con un solo cliente.

### F116 — Voladoras híbridas: despegue, vuelo y aterrizaje (RFC-030, corte 030e)

El nodo `Flight` (hijo de `unit.tscn`) tiene cuatro estados: GROUND, TAKEOFF, FLYING y LANDING. Las híbridas despegan si `takeoff + d/vuelo < d/tierra` (sacengine `state.d:12335-12339`), vuelan recto a `flying_speed` y aterrizan cuando se quedan quietas. El estado se replica y el cliente saca de ahí el clip y la velocidad. `export_stats.py` exporta takeoff, fly y land (slots CRE8 32-34) con la regla de descarte de sacengine.

**Cierre (2026-10-16).** La review (`reviews/REVIEW-F116-flyers.md`) dio FAIL por un único bloqueante: la sonda usaba tokens prohibidos. Se corrigió en una ronda, y en la misma se agregó un tope de velocidad en el aire (`_cap_air_pace`). Playtest con ventana PASS (`agent/out/pt116/`):
- **Destino a 150 m:** el rectángulo seleccionó las 10 y se dio clic derecho. Las 8 que tienen clips pasan por TAKEOFF → FLYING → LANDING → GROUND. Despegan en 0,87–1,98 s. La velocidad máxima en el aire es igual a `flying_speed` (exceso máximo 0,35 %).
- **Destino a 5 m:** caminan.
- **Red:** servidor dedicado con `--level=9` y 2 clientes. A y B ven la misma secuencia: despegue de 0,85 s y altura de 4,5 m. Capturas `net_a_air.png` y `net_b_air.png`.
- **Regresiones:** `f25_flying_summon` dio AGENT_OK. El digest de seed 7 no cambia (`4915c884…`). `rules_suite` PASS.

Excepciones fieles a sacengine:
- Rhinok no vuela, porque sus slots de vuelo repiten `stance1`.
- Phoenix vuela siempre, incluso hacia un destino a 5 m, y no tiene clips de takeoff ni de land.

Deuda:
- **030e2:** pose y cápsula.
- **Combate en el aire:** al perseguir o atacar, la voladora baja a tierra.
- **Clips y estados de vuelo:** faltan `hover`, `badLanding` y morir en el aire.
- **Relieve:** el vuelo no lo sigue y llega a 25–32 m sobre un cañón.
- **Ikarus sobre el manantial:** aterrizó encima del manantial (h = 3,1 m en GROUND), y eso después lo hizo despegar con un destino a 8,8 m.
- **Silverback:** tarda de 5 a 10 s en recorrer 5 m. Es un problema anterior a este corte.
- **`unit_body.gd`:** pasa las 1000 líneas.

### F134 — Reposo con stance1 y pose medida en tierra (RFC-030, corte 030e2a)

El rol `idle` repite el `pose_source` horneado: `stance1` desde nivel 2, igual que sacengine en `state.d:7957-7960`, en lugar del gesto idle0. Esto arregla que «Rhinok flote» y que Silverback llegue a 14 m. `BodyPoseOverride.rest_hovers` marca a Phoenix: flota a propósito. La auditoría `tools/audit_body_pose.gd` suma la sección HIBRIDA, que recorre todos los cuadros horneados. Bancos de perfil congelados: `debug/f134_hybrid_pose_{small,big}.tscn`.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F134-rest-pose.md`). Playtest con ventana PASS (`agent/out/pt134/`):
- **Pies en reposo:** de −0,08 a +0,02 m en las 9 que caminan. Phoenix queda arriba, como está aceptado.
- **Tags de reposo:** CKst, SPst, CKst, CKst, SPst, DGst, DMst, Eds1, ADst y DFst.
- **Colaterales:** cambian 25 criaturas no híbridas de nivel ≥ 2. Pasan a `*st`, sin poses raras, con los pies en ±0,31 m.
- **Regresión:** `f25_flying_summon` AGENT_OK. El digest de seed 7 no cambia y `rules_suite` PASS.

Decisión: C2 (cápsula en tierra de 7 híbridas) pasa a F135, porque cambia la simulación (`MeleeAttack` usa `info().height`).

Deuda:
- La auditoría sigue en FAIL hasta F135. Faltaría marcar los casos `C2_F135`.
- `verdict = ["HIBRIDA"]` tapa otros veredictos del cuadro 0.
- En el banco big, `GroundLine` mide menos de 1 px.
- Rhinok se ve de frente en el banco de perfil.
- Gammel (`gamm`) no tiene `pose_source`.
- Los gestos idle al azar (1 de cada 5) quedan fuera.

### F135 — Cápsula en tierra y en vuelo (RFC-030, corte 030e2b)

`BodyCollider` (hijo de `unit.tscn`) es el **único** dueño de la cápsula. La calcula como una función idempotente de (modelo, estado de vuelo) y la recalcula con `model_changed`, `ready` y `Flight.state_changed`. `UnitBody._apply_model` ya no crea la cápsula y `Flight` volvió a ser solo una máquina de estados. Cuando llegue la caja por cuadro de RFC-023, es el único lugar que hay que cambiar.

Los datos van en `BodyPoseOverride.capsule_height` y en `capsule_height_flying`, según el p95 de los cuadros horneados:
- **Tierra:** adrg 12,18, drag 12,75, ddmn 11,02, edmn 10,07, fdrg 15,21, sprg 3,91 y sprl 3,89.
- **Vuelo:** adrg 17,78, dcak 7,19, ecak 6,98, fcak 7,19, drag 13,10, sprg 5,86 y sprl 5,86.

La auditoría da `POSE AUDIT PASS`, con C1, C2 y C3.

**Cierre (2026-10-16).** La primera review dio NEEDS WORK: el cliente que entraba tarde veía la cápsula de tierra en vuelo, y faltaba declarar el cambio de simulación. Un primer arreglo, con un one-shot dentro de `Flight`, falló en la red real. Por pedido del usuario se rediseñó con un solo dueño, porque parchear el orden entre dos escritores no escala. La segunda review dio PASS.

Playtest (`agent/out/pt135/`):
- **Bancos de perfil:** alturas idle y fly iguales a lo esperado, con `fly_bad 0`.
- **f114 a 150 m:** sin cambios respecto de F116.
- **Red con un cliente que entra tarde con Ikarus en vuelo:** B ve 6,98 desde el primer tick, con `fly_bad 0` en 1156 ticks.
- **Regresión:** `f25_flying_summon` dio OK. El digest de seed 7 no cambia y `rules_suite` PASS.

**Cambio de simulación declarado:** cambia la altura de tierra de 7 modelos y, con ella, la caja de `MeleeAttack`, `BodySeparation`, el origen del disparo y la mira en vuelo. Afecta a las partidas con esas híbridas, que aparecen desde el nivel 2. Ningún digest lo cubre.

Deuda:
- TAKEOFF y LANDING usan la cápsula de tierra.
- `MeleeAttack`, `BodySeparation` y `HealthBar` usan la altura de tierra también en vuelo.
- No se probó el choque contra el techo de una estructura alta.
- Hay comentarios viejos en `pt116_flight.gd` y en la nota de adrg.
- Pendiente 030e2-R (REA).

### F117 — Pasivas de daño: Taurock y Firefist (RFC-030, corte 030f)

`DamagePassive`, hijo de `unit.tscn`, es el único que calcula el factor de `passiveOnDamage`. `Health` y `MeleeAttack` le preguntan por un socket. Los datos viven en `data/passives/korq.tres` (Taurock recibe ×(0,25 + 0,75·h), `state.d:9010-9015`) y en `ahtf.tres` (Firefist pega ×(1 + 1,5·(1−h)) cuerpo a cuerpo, `state.d:8886-8890`). En ambos casos, h es la vida relativa antes del golpe. `export_stats.py` exporta `passive_on_damage` sin sacar el slot 2 de `abilities`, porque lo usan la IA y el `hmba` del Manahoar.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F117-damage-passives.md`). Playtest con ventana PASS (`agent/out/pt117/`):
- **Taurock:** al 50 % recibe ×0,6250. Los 13 golpes siguen la fórmula con un error de ±0,0003.
- **Firefist:** ×2,2281 con h = 0,181 y ×2,2824 con h = 0,145. El blanco recibe el factor una sola vez.
- **NPC Taurock** (`pt73_taurock`): AGENT_OK. Cambia su registro, y eso estaba declarado.
- **Regresión:** `f25_flying_summon` AGENT_OK. Los digests de seed 7, `--npcs` y `npc_load` no cambian. `rules_suite` PASS.

Deuda:
- Falta la excepción del daño por caída: el port todavía no tiene caída.
- `gcil` (rayo ×0,25) va a necesitar una firma que reciba el tipo de daño.
- `tdhg` y `tfhg` quedan sin efecto.
- En el banco, las unidades aparecen recién al largar.

### F118 — Nubes al morir (RFC-030, corte 030g)

`DeathCloudSpawner`, hijo de `unit.tscn` y activo solo en el servidor, escucha `Health.died`. Instancia una nube por cada pasiva del CRE8 que tenga su `.tres` en `data/death_clouds/`. Como en sacengine, la nube actúa en un solo update y desaparece (`state.d:25216-25254`, `25674-25697`); lo que dura queda en el cuerpo.

| Nube | Criaturas | Efecto |
|---|---|---|
| Vapor (`goc@`) | Cog, Phoenix | `SplashDamage` 300·(1−d/10) |
| Veneno (`cen@`) | Necryl | Dosis `Poisoned` de 23,08/s durante 5 s, en 5 m |
| Cura (`tum@`) | Mutant, Dragon, Sirocco | `HealEffect` de hasta `maxHealth` a 240/s, solo aliados, en 30 m |

El humo sale por `FxBus.broadcast`. El export lee los SPEL de `@PRC.SCAT` con `args`.

**Cierre (2026-10-16).** La review dio NEEDS WORK (`reviews/REVIEW-F118-death-clouds.md`): la cura no tenía fin. Se corrigió en una ronda (`add(maximum)` + satAdd). Playtest con ventana PASS (`agent/out/pt118/`):
- **Humo:** las tres nubes tienen captura.
- **Vapor:** el enemigo pierde 236,8 y el aliado 0.
- **Veneno:** el enemigo pierde 115,38 y el aliado 0.
- **Cura:** el aliado sube de 400 a 800, con 496 de cura total, por debajo del máximo de 800.
- **Arreglo del orquestador:** el aliado mostraba el humo verde de la dosis aunque no recibía daño. Ahora el humo de `Poisoned` solo sale si `Health` aceptó el veneno. Repetí la prueba: AGENT_OK y los mismos números.
- **Regresiones:** `f25_flying_summon` AGENT_OK. El digest de seed 7 no cambia. `rules_suite` PASS.

Divergencia heredada: no hay fuego amigo (AUDIT-2026-10-12:152). En sacengine el vapor hace ×0,5 a los aliados y el veneno ×1. Queda para un RFC aparte, que espera la decisión del usuario.

Deuda:
- Red sin verificar con input real: hace falta un segundo cliente que mate la criatura.
- Phoenix y Dragon no están en el banco.
- `Poisoned` hace 300 ticks y sacengine 301.
- `bodies_within` duplica a `SplashDamage`.
- `HealEffect.on()` duplica a `caster.gd`.
- Las perillas de `Poisoned` no se pueden editar.
- Los debuffs del veneno quedan para 030k y `ignite` para 030r.

### F119 — Impacto con salpicadura (RFC-030, corte 030h)

`ShotImpact` (`apply(shot, target, point, ability)`, que se compone con hijos `ShotImpact`) se asigna por disparo en `ShotLook.impact`. `RangedShot._burst` lo instancia solo en el servidor; si un disparo no tiene impacto, mantiene el golpe directo. `SplashImpact` usa las perillas `direct_hit` y `radius_source`. `SplashDamage.bodies_within` es el único recorrido de cuerpos: lo usan las nubes de F118 y el `kind` del daño.

| Criatura | Golpe al tocado | Salpicadura |
|---|---|---|
| Mutant (`babt`) | entero | `damage_range` 10, sin el tocado |
| Abomination (`tugt`) | entero | `damage_range` 10, sin el tocado |
| Flummox (`crba`) | sin golpe entero | `effect_range` 8, incluye al tocado |

Fuentes en sacengine: `state.d:24381`, `24432`, `24059`, `9400`. El Scarab no entra en este corte: su disparo cura. Pasa a 030h2.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F119-splash-shots.md`). El orquestador corrigió que se perdía el nodo cuando el impacto no era un `ShotImpact`. Playtest con ventana PASS (`agent/out/pt119/`):
- **Mutant:** el tocado recibe 382,50. A 1,05 m, 342,53, y a 1,18 m, 337,47.
- **Abomination:** el disparo cayó al suelo y aplicó solo el área: 220,07 a 4,25 m, 287,02 a 2,50 m y 262,20 a 3,15 m.
- **Flummox:** 315,00 a 0 m y 276,87 / 277,30 a 0,97 m.
- Una choza recibió 71. El tirador no se daña a sí mismo.
- La roca del Flummox se ve como un proyectil razonable.
- **Regresiones:**
  - `f25_flying_summon` y `pt118_bench` dan AGENT_OK. El vapor sigue bajando la vida de 743 a 506.
  - El digest de seed 7 no cambia y `rules_suite` PASS.

Deuda:
- **Sin probar:** el golpe directo de la Abomination (mismo código que el Mutant) y un segundo disparo.
- **030h2:** el Scarab hoy hace 150 de daño directo a enemigos y en sacengine solo cura aliados (gravedad alta). También van ahí las gotas de la Abomination.
- **Visual:** bolas de reserva en Mutant y Abomination.
- **Limpieza:** hay un segundo recorrido de cuerpos solo para el log, y `who()` está duplicado.

### F136 — Telaraña que cura del Scarab (RFC-030, corte 030h2)

El blanco de una criatura a distancia se decide en `TargetPolicy` (Resource por tag del ataque, en `TargetPicker.policies`). `WoundedAllyPolicy` (`data/targeting/slba.tres`) elige al aliado más herido (`state.d:12949-12958`, `28828-28842`). La telaraña es `HealImpact`: cura a los del bando del tirador en 5 m con `HealEffect.heal_full`, la misma regla que `tum@` (`23609-23627`). En `ShotLook`, `hits_allies`, `sweep` y `burst_at_range_end` reproducen el choque, el barrido y el estallido al final del alcance de sacengine. `is_foe` sigue significando enemigo; la política solo decide qué blanco conserva el cuerpo. No hay ningún `if scarab`: sin política, el código es el de antes.

**Cierre (2026-10-16).** La review dio PASS (`reviews/REVIEW-F136-healing-web.md`). Antes del playtest se hicieron tres ajustes de documentación: la descripción del banco, los desvíos en el RFC y el contrato `is_foe`/`_is_valid_foe`. El playtest con ventana dio PASS (`agent/out/pt136/`):
- **Carril A:** el primer disparo fue al Druid aliado a 85 m, no al enemigo a 6 m. Lo llenó en 1,28 s, de 459 a 800 a 240/s. El enemigo no recibió cura, y el Scarab dejó de disparar cuando el aliado quedó lleno.
- **Carril B:** con la orden de atacar, el enemigo quedó en 550/550 y el aliado a 2 m pasó de 289 a 550.
- **Carril C:** con un enemigo en contacto, 6 golpes cuerpo a cuerpo y ninguna cura.
- **Regresiones:** `f25_flying_summon` y `pt119_splash` (382,50) dieron AGENT_OK. El digest seed 7 no cambió y `rules_suite` dio PASS.

Declarado: con nivel ≥ 2, la IA que convoca Scarabs ahora cura.

Deuda:
- **Capturas:** la barra de una unidad propia solo se dibuja cuando está seleccionada, así que no hay captura de la barra llena del aliado.
- **Estallido:** falta el efecto visual.
- **Edificios propios:** no se verificó si frenan la telaraña.
- **Duplicaciones:** la regla de enemigo está escrita 3 veces, y `is_patient` copia la validez.
- **`fired`:** sigue informando 150 de daño.
- **Órdenes:** el jugador no puede ordenar curar a un aliado.

### F139 — Fuego amigo como regla de simulación (RFC-031, corte 031a)

`Health._side_factor` decide el factor de bando y nadie más lo hace:

| Caso | Factor |
|---|---|
| Mismo bando, fuego amigo encendido | ×`ally_damage_factor` (0,5) |
| Mismo bando, fuego amigo apagado | 0 |
| Veneno (`ignore_friendly`) | ×1 |

Fuentes: `state.d:8961`, `9005`, `28892-28899`, `9415-9419`.

`MatchRules.friendly_fire` vale `false` en el script, para que bancos y digests no cambien, y `true` en `data/match_rules.tres`, como el `options.d:98` de producto. `MatchState.take_rules()` lee `world.rules` y lo manda en el snapshot.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F139-friendly-fire.md`). Playtest con ventana (`agent/out/pt139/`):
- **Vapor con FF on:** propio ×0,500 (124,81 de 249,61). Enemigo 237,33.
- **Veneno con FF on:** propio y enemigo 115,38 cada uno, relación 1,00.
- **FF off:** propio 0 de vapor y 0 de veneno, sin humo de la dosis.
- **Fireball (input real):** Cogs propios ×0,500 a 1,28 m y a 3,89 m. Rencor N/A: ningún cuerpo propio tiene `GrudgeMemory`.
- **Regresiones:** dan AGENT_OK `f25`, `pt118`, `pt119`, `pt136`, y también `f28_rock`, `f26_duel`, `f29_spit` y `f10_walk`, que ahora heredan FF on. `rules_suite` PASS.
- **Digests:** sin cambios. Referencia que discrimina, `ai_match` seed 7, 0,5 min:

  | Reglas | Digest |
  |---|---|
  | `f139_ff_clouds` (dos corridas) | `af04fefb…` |
  | `f139_ff_off_clouds` | `01853244…` |
  | `f116_death_clouds` | `01853244…` (igual al anterior) |

  `ai_duel_seeded_ff` no discrimina: no hay daño entre aliados.

Deuda:
- **Criterio 5 sin verificar (disparo en línea).** El banco `f139_ff_shot_line` nace sobre la fuente: el Druid propio no queda sobre la línea y el chorro tapa las capturas. Hay que moverlo y fijar al Druid. El filtro `_can_hit` no cambió en este corte (F119/F136).
- `unruled`: dos defaults sin `MatchState`.
- Rencor contra atacante aliado (sacengine lo marca y el port no).
- La petrificación de 030i tiene que entrar también por `damage()`.

### F140 — MatchSetup, flag del dedicado y la regla en los clientes (RFC-031, corte 031a2)

`MatchSetup` (`scenes/flow/match_setup.gd`, RefCounted) reemplaza a `level_override` y `_cli_level`.
- `from_cli()` lee `--level=N` y `--friendly-fire` / `--no-friendly-fire` (`app.d:333-355`).
- `apply_to(rules)` devuelve un `duplicate()` con los overrides. Si no hay overrides, devuelve el mismo objeto.
- `HighNoon._enter_tree` lo aplica en la autoridad antes de `MatchSeed.begin`.
- `WizardSpawner` lee `rules.wizard_level`.
- Precedencia: boot > flag > reglas.
- La regla llega a los clientes por el snapshot de `MatchState`.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F140-match-setup.md`). Dos nits resueltos por el orquestador: un comentario de `high_noon.gd` y la precedencia cuando se pasan los dos flags. Playtest con ventana PASS (`agent/out/pt140/`):
- **Dedicado `--no-friendly-fire --level=2` con 2 clientes:** los dos clientes, también el que entró 8 s más tarde, muestran «fuego amigo: no», maná 1200 y 5 casillas.
- **«Contra la IA», nivel 4:** «sí (×0.50)», maná 1400 y 7 casillas. El `.tres` sigue sin tocar: nivel 9 y FF on (`same=false`).
- **Solo:** nivel 9, 11 casillas.
- **Digests:** seed 7, `f139_ff_clouds` y `f116` sin cambio. `rules_suite` PASS.

Deuda:
- Con los dos flags gana `--no` (sacengine se queda con el último).
- 031d: `--souls` choca con el flag propio de `ai_match`.
- No se volvieron a correr seed 1, `--npcs` ni `ai_duel_seeded_ff`.

### F141 — Menú de pausa y Salir al menú (RFC-031, corte 031b)

`PauseMenu` (`scenes/ui/pause_menu/`) es un CanvasLayer con `process_mode ALWAYS`.
- Se abre y se cierra con Esc (acción `pause_menu`).
- **En solo** pausa el árbol. **En red** no pausa y solo muestra «Partida en curso».
- Mientras está abierto entra al grupo `menu_open`. Con eso se callan `match_command`, `wizard_body._read_forward`, `world_camera` y `soul_system`, y `%Dim` se come el clic.
- **Salir** pide confirmación dentro del mismo panel y después hace `paused = false` y `return_to_boot`.
- El servidor registra `peer_left`.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F141-pause-menu.md`). Playtest con ventana (`agent/out/pt141/`):
- **Pausa:** el Manahoar se mueve 0,000 m en 3 s pausado y retoma al continuar.
- **Esc con hechizo armado:** el hechizo sigue armado y se lanza con el clic siguiente.
- **Clic y órdenes con el menú abierto:** no tienen efecto (el control con el menú cerrado sí cambia la selección).
- **Salir:** vuelve al boot en ≤ 2 s sin pausa. «Contra la IA» nivel 4 da 7 casillas, con lo que **se cierra la deuda de F115**.
- **Red:** el menú de A no pausa. El mago de B avanza 28 m en 3 s con el menú de A abierto (corrida del developer). Cuando A sale, el servidor registra `peer_left` y B sigue.
- **Regresiones:** `f25` y `f10_walk` dan AGENT_OK. Los digests de seed 7 y `f139_ff_clouds` no cambian.

Deuda:
- **Dueño único del input al mundo:** pasa a 031c como primer paso (`WorldInput`).
- **Criatura de B en red sin medir:** solo se midió al mago, y la orden del playtest fue «avanzar» a un Manahoar.
- **Esc en la confirmación:** cierra todo el menú.
- **Cursor del hechizo:** queda encima del menú.
- **Panel:** offsets fijos.

### F142 — Opciones → Gráficos (RFC-031, corte 031c)

**Piezas**
- **`WorldInput`** (`scenes/ui/world_input.gd`): es el único que decide si el input del jugador llega al mundo. `blocked()` revisa el grupo `MODAL`, y lo consultan `match_command`, `wizard_body`, `world_camera` y `soul_system`.
- **`UserSettings`**: es el único que lee y escribe `user://settings.cfg`. Escribe de forma atómica (`.tmp` + rename) y no pisa un archivo que no pudo leer.
- **`GraphicsPrefs`** (Resource compartido): preset (`LookQuality` existentes), pantalla completa, VSync, tope de FPS. `HudScale` migra a `UserSettings`.
- **`GraphicsApplier`** (en el boot y en el mundo):
  - Solo actúa en la escena que está corriendo.
  - Queda inerte en el editor, en headless, en el dedicado y bajo AgentKit, salvo que se pase `--apply-graphics`.
  - Respeta los flags del motor de esa corrida.
- **`OptionsMenu` → pestaña Gráficos**: se abre desde el boot y desde la pausa. Esc cierra primero las opciones.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F142-graphics-options.md`). La corrección única trajo tres cosas: el applier inerte bajo AgentKit, la escritura atómica y un solo oscurecido de fondo.

Playtest con ventana (`agent/out/pt142/`):
- **Calidad en vivo:** Baja se aplica en 23–45 ms sin cortar la partida. El peor cuadro fue 142 ms. Las capturas Media/Baja muestran el cambio.
- **Persistencia:** al reiniciar arranca en Baja.
- **HUD:** el tamaño cambia en vivo a 0,6 y 1,2.
- **Esc:** primero cierra las opciones y después la pausa, sin oscurecer dos veces.
- **Sin `--apply-graphics`:** no se aplica ninguna preferencia.

**Bug encontrado en el playtest y arreglado por el orquestador:** Godot consume sus propios flags (`--max-fps`, `--disable-vsync`, `-f`/`-w`) antes de `OS.get_cmdline_args()`, así que la preferencia «Sin tope» pisaba el `--max-fps 60` de las pruebas. Ahora el applier detecta esos overrides comparando el estado al arrancar con los project settings. Lo hace una vez por proceso, antes de tocar la ventana. Verificado: `engine_fps=60` en toda la corrida, con la preferencia sin tope.

**Regresiones:** `f25`, `f10_walk` y `pt141_solo` dan AGENT_OK. El digest de seed 7 no cambia (`4915c884…`).

**`settings.cfg` del usuario:** no existía antes de las pruebas y quedó ausente después. Las copias de prueba están en el scratchpad.

Deuda:
- **Pasto en pausa:** al cambiar el preset con la partida en pausa, el pasto queda en 0 celdas hasta que se despausa.
- **Pasto al reiniciar en Baja:** una vez arrancó inactivo. Fue intermitente y no se pudo aislar.
- **Botón Cerrar con HUD 1,2:** un clic falló una vez y no se reprodujo.
- **Sin ejercitar:** los interruptores de Pantalla completa y VSync, y el look final (031-R).

### F143 — Opciones → Jugabilidad (RFC-031, corte 031d)

**Qué hace**
- **`GameplayPrefs`** (`[partida]`): fuego amigo, soltar almas con P y almas iniciales. `to_setup` fija **solo lo que el jugador eligió explícitamente**.
- **`MatchSetup`:** suma `drop_soul`, `starting_souls`, `--souls`, `--[no-]drop-soul` y `overlaid_by`. Es el único dueño de `--souls`; `ai_match` ya no lo parsea.
- **Precedencia final:** elección explícita del jugador > flag > reglas.
- **`MatchState`:** manda las tres reglas en el snapshot.
- **`GameplayTab`:** se edita en el boot y en partida es de solo lectura (lee `MatchState`).
- **`UserSettings` es el único dueño de `settings.cfg`.** Bajo AgentKit, sin `--user-settings=`, trabaja en sandbox: lee los defaults y escribe solo en memoria. Así los playtests nunca leen ni escriben el archivo del jugador. `--user-settings` reemplaza a `--apply-graphics` de F142.

**Cierre (2026-10-16).** La review dio FAIL por B1: los playtests leían y pisaban las preferencias del jugador. Se corrigió en una ronda con el sandbox y la elección explícita. Playtest con ventana (`agent/out/pt143/`):
- **Fuego amigo desde el boot:** apagarlo da «fuego amigo: no». Captura de la pestaña editada.
- **Almas:** con 6, los dos magos arrancan con 6. Con soltar apagado, P no suelta (6→6). El contraste encendido baja 6→5→4.
- **Persistencia:** las preferencias sobreviven al reinicio (`--user-settings`).
- **Sandbox:** sin `--user-settings` muestra los defaults.
- **Solo lectura en partida:** con la nota visible.
- **Red:** un dedicado `--souls=6 --no-drop-soul` con un cliente que entra 8 s tarde. Los dos ven en la pestaña los valores del servidor y arrancan con 6 almas.
- **El jugador queda aislado:** con un `settings.cfg` sembrado con FF off, una corrida bajo agente igual dice «sí» y el SHA del archivo no cambia. Con `--no-friendly-fire` gana el flag.
- **Regresiones:** `f25`, `f10_walk` y `pt141_solo` dan AGENT_OK. El digest de seed 7 no cambia.

Deuda:
- **Fireball real desde el boot con FF off sobre una criatura propia en el radio: sin medir.** El flow no logra apuntar el Fireball, porque el Caster no acepta aliados como blanco directo (`caster.gd:333`, flag `disallowAlly`). El 0 sale de la cadena ya probada: el boot da «no», con `MatchSetup.friendly_fire = 0` el Fireball sobre Cogs propios hace 0 (dev F143) y F139 cubrió ×0 y ×0,5.
- **Abiertos:** N4 (`print` en cada P), N5 (rango 1-30 contra `--souls=0`) y N6 (defaults antes del primer snapshot en el cliente).
- **Look:** queda pendiente 031-R.

### F120 — Estado común y aturdir: Flummox (RFC-030, corte 030i-a)

**Qué es.** `Afflictions` (hijo de `unit.tscn`) es el único que decide `holds`, `immobilized`, `damage_factor`, `cc_protected` y `clip_role`.
- **Estados:** cada uno es un hijo `Affliction`, con sus datos en un `AfflictionType` (`.tres`).
- **Prioridad:** cuál gana lo decide el dato `cancels`.
- **Red:** `shown` es una máscara de bits que se replica.
- **`Stunned`:** el enfriamiento es de 480 ticks y la duración la da el clip, `(knock + get_up)·2` o `fly_damage` (`state.d:8546-8568`, `8138-8146`).
- **`StunImpact`:** está en `flummox_impact.tscn` y aturde antes de dañar. Alcanza a todo cuerpo a 8 m o menos, sin filtrar bando y con el tirador incluido (`24059-24067`).
- **`Flight`:** consulta a `Afflictions`. Un híbrido aturdido no despega ni aterriza.
- **`unit_body.gd`:** la puerta se fundió con `_playing_dead`. Pasó de 1046 a 1043 líneas.
- **WORKAROUND:** hoy la caída y el levantarse son un Tween de reserva sobre `Tilt:z`, con el pivote levantado. Los clips knock/get_up costarían unos 1,6 GB; cuando existan, el Tween no corre.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F120-stun.md`). La corrección única cubrió:
- un híbrido aturdido en el aire queda fijo a 3,017 m, con 0 de deriva;
- en el suelo, con una orden, no despega;
- el pivote ya no se hunde;
- al morir no salta;
- se corta el lunge.

Playtest con ventana (`agent/out/pt120/`):
- **Carril A:** 3 Druids, 226 cuadros exactos, con deriva ≤ 0,003 m y ningún golpe mientras están aturdidos. Vuelven a pelear. Un disparo con enfriamiento dice «en enfriamiento» y aun así hace daño.
- **Carril B:** Earthfling 112, Druid aliado 226 y el propio Flummox 116.
- **Captura** `a_druid_down.png`: caídos de costado, sin hundirse.
- **Regresiones:**
  - `f29`, `f25` y `f10_walk`: AGENT_OK.
  - Play Dead (flow nuevo `pt120_play_dead`): quieto, sin activar la máscara.
  - Digest seed 7 sin cambio; `--npcs` igual al A/B de HEAD; `f139` sin cambio.
  - `rules_suite` PASS.

Deuda:
- **Sin verificar:** la red (no hay banco de red con Flummox) y el cliente que entra tarde (N4).
- **Look del Tween:** cae de costado y no hacia atrás, y se queda en idle de pie (V3). Pasa a `studio-visual` o a los clips.
- **`PathFollower`:** vuelve a planear la ruta mientras está aturdido.
- **«Blanco inválido»:** es el texto que se muestra para un cuerpo aturdido.
- **Aturdido por melee** (`state.d:9246-9262`): no está.
- **Magos (030i-c):** no se aturden.
- **Play Dead:** ahora revienta sobre un pozo y en el aire muestra idle.

### F137 — Petrificar y la mirada del Basilisk (RFC-030, corte 030i-b)

`petrified.tres` (holds, immobilizes, damage ×0,2, cc_protects, `cancels [stunned]`, `drops_fliers`, `breaks_special_modes`) es la base de `Petrified`:
- Cuenta su duración en ticks propios, así que no avanza con el juego en pausa. Termina en `frame++>=lifetime` (`state.d:23760`).
- Al terminar lanza `Stunned.knock(240)` y 32 rocas. Si el cuerpo muere petrificado, suelta las rocas igual.

Piezas que lo rodean:
- `StoneLook` y `stone.gdshader`: gris 0,3 + 0,7·brillo·(1, 1, 0,8) sobre sRGB (`bone.d:189-192`). Vuelve a vestir solo cuando cambia la malla.
- `ClipPosePlayer.frozen`.
- `Health._state_factor()`: un único factor que usan tanto `damage()` como `damage_typed()`.
- `Flight.is_dropped()`: el volador cae.
- `PetrifyImpact` en `dpsf.tres`: no hace daño, y el Basilisk deja de hacer sus 150 directos. Duración `min(10, 10000/máx)` s, mago 2,5 s (`11631-11645`).
- `unit_body.gd`: 1043 → 1045 (+2: al quedar retenido sale de Rockform, según el dato).

**Cierre (2026-10-16).** La review dio FAIL por dos bloqueantes, corregidos en una ronda:
- B1: el reloj del motor seguía corriendo en pausa.
- B2: Rockform no se rompía, y el daño quedaba en ×0,01.

Playtest con ventana PASS en 10 de 11 criterios (`agent/out/pt137/`):
- Druid: 600 de piedra y después aturdido 226. Flummox: 263 y después 116.
- El impacto no hace daño.
- Los 14 golpes del Trogg sobre la piedra hacen exactamente ×0,200.
- Deriva 0 y pose congelada.
- Un segundo impacto informa «protegido».
- El Druid vuelve a pelear.
- La Gargoyle queda a 0,004 m del suelo y después vuelve a 4,5 m.
- Con 5 s de pausa la piedra no avanza, y la vida final es idéntica a la corrida sin pausa.
- Hay captura de las rocas.
- Regresiones: `pt120_bench` y `f25` dan AGENT_OK. Los digests seed 7 y `f139` no cambian. `rules_suite` PASS.
- La captura `p_a_druid_stone_90.png` se lee como una estatua gris.

Deuda:
- Red sin verificar.
- B2 no se probó con input real: ninguna IA le apunta a una roca.
- N1: sacengine usa dos manos y aquí hay un solo proyectil.
- N3: un híbrido tirado mientras está FLYING usa el aturdido de vuelo estando en el suelo.
- N4: la caché de StoneLook nunca se libera.
- N5: Skin of Stone va a necesitar convivir con StoneLook.
- N6: un cliente que entra tarde ve la pose de reposo.
- La barra de vida de la Gargoyle de piedra queda alta.

### F138 — Magos aturdidos y petrificados (RFC-030, corte 030i-c)

**Cómo funciona.** `wizard_body.tscn` incorpora el mismo `Afflictions` (`Stunned`, `Petrified` con `StoneLook`). La malla pasa a `Tilt/Mesh` y se replica `shown`.
- **Bloqueo de acciones:** `WizardBody.can_cast()` exige además `not holds()`. Con eso, `Caster` corta el lanzamiento y el maná drenado se pierde (`state.d:15138`, `15206-15213`). También frena a la IA y al input del jugador.
- **Movimiento:** mientras está retenido, el mago no camina ni gira. La orden queda guardada y se ejecuta al soltarse.
- **Regeneración:** no regenera vida (`1429`).
- **Pose:** `Afflictions.pose_role()` queda compartido con `unit_body`.
- **Duración:** `(knock + get_up)·2` (Jadugarr 114, Marduk 104). El arreglo de `hitFloor` no la cambia (`sacobject.d:844-874`). La piedra dura 2,5 s.
- **Quién puede ser afectado:** solo un mago vivo puede quedar aturdido o petrificado. Un fantasma o un mago muerto no.
- **Sin chequeos de tipo:** cada cuerpo responde `clip_type()` / `is_targetable()`.

**Cierre (2026-10-16).**
- **Review: NEEDS WORK.** El bloqueante B1 era que un mago que muere aturdido quedaba flotando. Se corrigió en una ronda con `Stunned.corpse_lays_down`, desactivado en el mago. Headless: al morir y al revivir, `Tilt.y` = 0.
- **Playtest con ventana** (`agent/out/pt138/`):
  - **Aturdido:** 104 cuadros, deriva 0, sin lanzamientos. Captura del mago caído.
  - **Piedra:** 150 de piedra (151 cuadros en gris), deriva 0 y factor 0,20. Después, aturdido de 104. Captura del mago gris.
  - **Vuelve a actuar:** el mago se recupera y a los 6–11 ticks lanza Rock.
  - **Regresiones:**
    - `pt120_bench` (226/112/116), `pt137_main` (600/263), `pt141_solo` y `f10_walk`: AGENT_OK.
    - Digest de seed 7 sin cambio. `rules_suite` PASS.
- **Verificado solo en headless:**
  - «se corta Rock slot 2» al petrificarlo mientras lanza;
  - B1.

**Deuda**
- **Corte de lanzamiento por aturdido:** no hay un caso determinista, porque la IA decide distinto con ventana (ver determinismo).
- **×0,2 sobre el mago:** no se probó con un golpe real.
- **Red:** sin verificar.
- **`f20_solo`:** el fallo «click missed %God_persephone» (pointer did not hit) no se reproduce: pasa en HEAD 2 de 2 (2026-10-17). El selector no cambió desde c79753e, así que es un flake de la entrega del clic sintético de AgentKit. Si vuelve a pasar, poner una sonda de eventos reales de mouse y foco en esa corrida.
- **Determinismo (alarma, preexistente desde el primer commit):** `spellbook.gd` descuenta los enfriamientos en `_process(delta)`, con el reloj de render. Por eso la IA decide distinto con ventana. Va en un corte propio.

### F144 — Banco de determinismo y línea base (RFC-032, corte 032a)

**Qué es.** `agent/run_determinism.sh <caso|all|table> [modos]` corre `ai_match` en tres modos y compara cada uno contra `fixed`:
- **`fixed`:** headless con `--fixed-fps 60`.
- **`stress`:** headless con `--max-fps 6`; con el tope de 8 pasos de física por cuadro da unos 48 ticks por segundo.
- **`window`:** `--max-fps 60` con `--autostart --quit`.

Todo pasa por `godot_run.sh`. Un vigía mide RSS y tiempo y marca `CONTAMINATED`, y la comparación muestra la primera línea de `events` que difiere. Las salidas quedan en `agent/out/det/`. El corte no cambia el producto; solo documenta `ai_match`.

**Cierre (2026-10-16).** La corrida `window` sirvió de playtest con ventana. Los 4 casos dan `fixed` = `fixed2`. Ninguna corrida quedó contaminada; RSS máximo 744 MB. Una pasada completa tarda unos 12 minutos.

**Digests 032a (línea base en HEAD):**

| Caso | fixed | stress | window |
|---|---|---|---|
| s7 (`ai_duel_seeded`, 2 min) | `4915c88453c02814584f26cff3596e4aed817e42f04e9021a04f658344f5597d` | igual | igual |
| s7_npcs | `7179b17d6f6cd03b4ba4c61ab8a6a5d0d6d4f0d79e1a1cd387211a2c512d86f6` | igual | igual |
| s1_trivial (`ai_vs_trivial`, 3 min) | `e076abe1cf0e70cbac9898c5211e5601a1973ee42cc955743bf665a049f42bf9` | **`8ee40cbc…`** ≠ | **`37768d9c…`** ≠ |
| f139 (`f139_ff_clouds`, 0,5 min) | `af04fefbb80252e24a6e642d60759e4c8efaa90c34fdf2f83a7460897b26bb6d` | igual | igual |

**El banco discrimina.** En `s1_trivial`, el modo `stress` diverge en la línea 91 de `events` (un summon 12 ticks antes) y `window` en la línea 171. Es el enfriamiento de `Spellbook`, que se calcula en `_process`; lo corrige 032b.

### F145 — MatchClock y enfriamientos por tick (RFC-032, corte 032b)

**Qué cambia:**
- **`MatchClock`** (`scenes/world/match_clock.gd`, estático) es el único reloj de la simulación. Se engancha a `SceneTree.physics_frame`, no avanza en pausa y se reinicia en `HighNoon._enter_tree`.
- **`Spellbook`** guarda `_ready_tick`, con `cooldown = (ready − now)/60`, y ya no tiene `_process`. Cada cliente convierte el RPC a su propio `now`.
- **`rules_suite`** suma los casos `spellbook_cadence` y `match_clock_pause` (`debug/determinism_cases.gd`).
- **Banco `run_determinism.sh quick`** (para cortes intermedios, unos 2 minutos): corre `s1_quick` en los 3 modos y `s7`/`f139` en fixed contra `agent/det_baseline.txt`.

**Cierre (2026-10-16).** Review PASS (`reviews/REVIEW-F145-match-clock.md`).
- **`all` → DETERMINISM PASS en los 4 casos × 3 modos.** `s1_trivial` ahora da `e076abe1…` también en stress y en window; en F144 divergía.
- **`quick`:** PASS en 1 min 45 s.
- **HUD del libro con ventana:** el enfriamiento baja en vivo (3,2 → 1,7 → listo).
- **Online, dedicado más un cliente** (`pt145_net`): el cliente ve 3,1 → 1,6 en 1,5 s, lo mismo que en solo salvo la latencia. AGENT_OK.
- **`f25`:** AGENT_OK. **`rules_suite`:** PASS.

**Digests 032b:**

| Caso | Digest |
|---|---|
| s7 | `4915c88453c02814584f26cff3596e4aed817e42f04e9021a04f658344f5597d` |
| s7_npcs | `7179b17d6f6cd03b4ba4c61ab8a6a5d0d6d4f0d79e1a1cd387211a2c512d86f6` |
| s1_trivial | `e076abe1cf0e70cbac9898c5211e5601a1973ee42cc955743bf665a049f42bf9` (ahora en los 3 modos) |
| s1_quick | `44d78b49ebad84f3cddf817ea1655bd7a312ee3f6e2a395300dcc175344743d8` |
| f139 | `af04fefbb80252e24a6e642d60759e4c8efaa90c34fdf2f83a7460897b26bb6d` |

**Deuda:**
- El redondeo a ticks puede correr un enfriamiento hasta 1 tick.
- Subir de nivel a mitad de partida limpia los enfriamientos (`_rebuild`, igual que antes).

### F146 — Un dueño del azar (RFC-032, corte 032c)

`MatchSeed.rng(parts)` y `MatchSeed.seed_rng(rng, parts, override)` son el único fallback de azar. La convención es `[sistema, id estable]`, sin `instance_id`. El RNG global queda sembrado con `derive(["presentation"])` y es solo para presentación; ningún digest cambió, así que no había consumidores ocultos. Se migraron `unit_body` (ahora 1040 líneas), `ghost_form`, `guardian_tether`, `ai_roster`, `match_biome` y `melee_attack`. El caso `sim_rng_lint` de `rules_suite` revisa 172 archivos sin infractores y se probó saboteado: falla con un `randf()` sembrado. Con `--seed=0` cada corrida sortea una semilla distinta.

### F147 — Plazos y vidas útiles en ticks de partida (RFC-032, corte 032d)

`make_way`, `petrified` y `stunned` usan `MatchClock.now()`. Si el reloj retrocede, `make_way._prune` vacía las tablas. `red_vortex` cuenta su vida en ticks de física, solo en el servidor. Casos `make_way_pause` (0 ticks en 120 de pausa) y `vortex_life` (60/60).

**Cierre de F146 + F147 y del RFC-032 (2026-10-17).** Review PASS (`reviews/REVIEW-F146-F147-rng-ticks.md`). Evidencia:
- `quick`: PASS.
- `rules_suite`: PASS.
- Una corrida con ventana con `pt137_main` y `pt141_solo`: AGENT_OK. La petrificación dura lo mismo.
- **Pasada completa `all`: DETERMINISM PASS.** Los 4 casos dan el mismo digest en `fixed`, `stress` y `window`:

| Caso | Digest |
|---|---|
| s7 | `4915c884…` |
| s7_npcs | `7179b17d…` |
| s1_trivial | `e076abe1…` |
| f139 | `af04fefb…` |

**Digests 032c/032d:** iguales a 032b.

**Deuda:**
- El lint se puede burlar a propósito (exención por archivo, lista blanca por texto) y solo cubre `scenes/world`.
- La vida de `red_vortex` cuenta llamadas y no `MatchClock`.
- Queda destrabado 030h3, las gotas de la Abomination, que va con `MatchSeed.rng`.

### F148 — Gotas de la Abomination (RFC-030, corte 030h3)

**Piezas:**
- **`ShotDropper`** (`ShotLook.dropper`): hijo del disparo `tugt`, corre solo en el servidor. En cada tick suelta una gota con probabilidad 3/4, según `!!state.uniform(4)` (`state.d:24445`), con `MatchSeed.rng(["drops", nombre del disparo])`.
- **`DropletRain`:** un pool de arrays empaquetados en `high_noon.tscn`. La gota cae a 10 m/s² y, al chocar (caja de 0,25 contra cualquier bando), hace 50 de daño directo a distancia con `Health.damage_typed`. Si cae bajo el suelo, termina sin daño (`24488-24505`).
- **Clientes:** ven un `trail_fx` puramente visual (`abom_drip`).

**Cierre (2026-10-17).** Review PASS (`reviews/REVIEW-F148-droplets.md`). El orquestador puso los logs del producto apagados por defecto; el bench los enciende. Medido con `f148`:
- **Gotas:** 155 de 201 ticks de vuelo (0,77).
- **Daño:** 45 por gota al Druid (50 × 0,9).
- **Determinismo:** `f148` da `ca532e1b0db6c9dbf82e51acef7ec27f1587dbfa3dc545480de450b2d9c6bf26` en fixed, stress y window. `quick` PASS.
- **Costo:** 0,19 ms por tick con 197 gotas, por debajo del tope de 0,5 ms.
- **Ventana:** captura `agent/out/pt148/d1_drops.png`.
- **Salpicadura de `f117`:** sin cambios. Las gotas además rematan al Druid golpeado, como en el original.
- **`rules_suite`:** PASS.

Deuda:
- Las gotas que se ven no son las simuladas.
- Los edificios no absorben las gotas.
- La distancia se mide al origen y no a la hitbox.
- Fuera del mapa, el tope es de 600 ticks.

### F121 — Empuje, vórtice y catapulta (RFC-030, corte 030j)

**Piezas:**
- **`Tumbling`:** estado de `Afflictions` (`data/afflictions/tumbling.tres`). Mueve el cuerpo con `Afflictions.steer`: gravedad 9,81 y amortiguación 0,99/0,998. Aterriza en la tierra o sobre lo que toque (`is_on_floor`). Daño de caída `max(0, −vz−3)·20` y después `Stunned.fall_down`, (hitFloor+getUp)·2.
- **Squall (`amba`):** `PushImpact` + `Pushback`, 22,5 m/s durante 40 ticks.
- **Vortick (`cita`):** `DirectImpact` + `Vortex`, 2 s; arroja durante 45 ticks y aplica el campo hasta el tick 90.
- **Flurry (`caba`):** `SplashImpact` + `Implosion`, 20 m a 0 en 1,5 s.
- Los efectos que duran varios ticks corren solo en el servidor, bajo `Shots`, con prioridad de física −1.

**Cierre (2026-10-17).** La review pidió cambios (`reviews/REVIEW-RFC-030j.md`): B1, el aterrizaje sobre algo que no es tierra, y B2, el criterio de la implosión. Los dos se corrigieron en una ronda.
- **Squall:** 15,00 m en 40 ticks.
- **Vortick, Druid:** ápice 6,91 m (réplica 6,91), aterriza a 6,34 m (réplica 6,31), caída 162. Aturdido 286 ticks; se levanta y vuelve a pelear.
- **Flurry:** el Druid lejano termina a 1,30 m del centro.
- **Determinismo:** `f121` da `fcefa9a3` en fixed, stress y window. `quick`: s7, s1_quick, f148 y f139 (con 030k-a aparcado) iguales a la línea base.
- **Playtest con ventana** (`agent/out/pt121/`, RSS 688 MB): 4 PASS. El punto 3 falla en lo visual: el Druid aterriza sobre la caja de colisión de la choza, 17 m sobre la tierra y al lado del cono. La causa es la colisión preexistente de `MapBuilding`, que es una caja; F121 aterriza bien sobre lo que colisiona.

Deuda:
- **Edificios:** la colisión de `MapBuilding` es la caja del modelo y no su forma; los cuerpos quedan parados en el aire junto a techos cónicos.
- **Pose:** dos escritores de `Tilt.rotation:z` (Stunned y Tumbling, m1). El tumbo usa un Tween de reserva, sin clips `tumble`/`hitFloor`; se resuelve con el sistema de animaciones.
- **Rutas por string** en `BodyNudge` y `Tumbling` (m5).
- **Divergencias declaradas en el RFC:**
  - las cápsulas no se atraviesan (implosión y choque en el aire);
  - un petrificado no se puede arrojar;
  - Rockform aterriza con `fall_down`;
  - `fasterStandupTimes` de los magos;
  - `BodySeparation` desvía el tumbo.
- **Estado de caída:** `Stunned` deduce la caída de `previous`; un cliente que entra tarde cuenta knock.
- **Sin probar:** el mago arrojado en partida, `net_local` y las partículas del vórtice y la implosión.

### F122 — Veneno a distancia (RFC-030, corte 030k-a)

**Piezas:**
- **`Poisoning`** (hijo de la unidad y del mago): único dueño de los agregados del veneno. Deriva en cada consulta, a partir de sus dosis vivas:
  - la resistencia extra (`ires`·1e-3, en todo daño);
  - la regeneración (×Π`freg`);
  - el bloqueo de maná (a los 120 ticks de cada dosis);
  - el contagio (caja +2 m, enfriamiento `vida+180`, ida y vuelta).
- **`Poisoned`:** extiende `DamageOverTime` (base compartida con el fuego de 030l), con `lifetime+1` actualizaciones.
- **`PoisonImpact`/`DiseaseImpact`:** el tirador se cura `amount·drain` y el blanco recibe la dosis (sin daño directo); un edificio recibe daño directo.
- **Disparos:** `cena` (Necryl, contagia), `lfda` (Deadeye) y `mhba` (Hellmouth).
- **Nube `cen@`:** ahora trae `ires 1000` / `freg 0`.

**Cierre (2026-10-17).** La review pidió cambios por un solo bloqueante: `Poisoned.start` era API que solo usaba el harness. Lo corrigió el orquestador (`reviews/REVIEW-RFC-030k-a.md`); `rules_suite` da PASS.
- **Deadeye:** 499,3 en 601 actualizaciones; drain +360.
- **Hellmouth:** 110,8 en 120 ticks; drain +400.
- **Necryl:** drain +100 y regeneración ×0. Contagia a Druid2 y este reinfecta una vez a Druid1. Druid3 nunca se infecta. Druid1 muere en la actualización 546 (réplica 546) y Druid2 queda con 514,5.
- **Determinismo:** `f122` da `aab853fc` en fixed, stress y window. `f139` se regrabó (`5ade9305`, igual en los 3 modos; tiene un Necryl). `quick`: s7, s1_quick, f148 y f121 iguales.
- **Playtest** (`agent/out/pt122/`): la lógica da PASS en los 5 puntos. El carril A estaba dentro de la estructura `bld3` y se movió a (1335, 1220). En las capturas se ven el humo y las barras de los dos infectados, y la barra limpia de Druid3; el pasto alto tapa los cuerpos.

Deuda:
- **Contagio por bando:** el contagio ignora el bando, como en sacengine, así que el Necryl en melee se infecta de su propio blanco.
- **Portador muriendo:** un portador en modo `dying` no contagia (en sacengine sí, 1 tick).
- **`nerf_factor`:** está duplicado.
- **Accesos sin tipo** en `PoisonImpact`.
- **`f116` y `f117`:** se corren en la pasada `all` del cierre del RFC.
- **Encuadres:** el pasto alto tapa los cuerpos en las tomas rasantes.

### F123 — Disparos de fuego (RFC-030, corte 030l)

**Piezas:**
- **`Burning`** (extiende `DamageOverTime`) es su propio dueño: un fuego no suma con otros. Cuelga del cuerpo y hace `lifetime+1` actualizaciones de `damage/lifetime`, más el drenaje de maná.
- **`BurnImpact`** tiene tres variantes:
  - `heat_ray_impact` (Tickferno `sfba`): drena el 0,5 del maná.
  - `rocket_impact` (Pyromaniac `lffa`): `pierce_shield`.
  - `bombard_impact` (Bombard `cfba`): `SplashImpact` más un fuego visual de 60 ticks.
- **`Health.damage_typed(..., pierce_shield)`** saltea `damage_factor` y `_state_factor`, que son solo escudos; queda documentado en `affliction_type.gd`.
- **`ManaPool.drain()`.**

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030l.md`). El playtest falló en lo visual: el fuego salía blanco sobre la nieve y la Bombard no mostraba explosión. Se corrigió en una ronda.
- **Tickferno:** 216,9 en 61 actualizaciones; el maná del blanco queda en 49,17.
- **Pyromaniac:** 866,9 en 301, sin daño directo.
- **Bombard:** 517,5 / 386 / 354.
- **Vuelo:** sfba 49, lffa 51 y cfba 32 ticks.
- **Determinismo:** `f123` da `d7db648e` en fixed, stress y window. `quick` PASS y las líneas base no cambian. `rules_suite` PASS.
- **Look:**
  - `fire` usa un atlas con alfa derivada del brillo (`firy_a`) y mezcla normal. En la caja del cuerpo da R>G>B con luminancia 0,61 (Druid) y 0,54 (Trogg), y la barra se lee (`agent/out/pt123/k1`, `k5`).
  - Bombard: `bombard_fire`, 60 partículas en 6 m (`k2`).

Deuda:
- Sin incendio de edificios ni `DamageMod.ignite` (030r).
- El rayo y el humo del cohete usan visuales de reserva.
- No hay fuego visual sobre un cuerpo que acaba de morir (M3).
- El carril de la Bombard está a 25 m: a 60 m hay un hueco del mapa.

### F149 — Congelar a distancia (RFC-030, corte 030k-b)

**Piezas:**
- **`Frozen`:** hijo `Affliction` (`data/afflictions/frozen.tres`, bit 3, inmoviliza, `cc_protects`, `cancels [stunned]`).
  - **Entrada:** `try_freeze_with_cooldown` con `MatchSeed.rng(["freeze", nombre])`.
  - **Duración:** `ceil(60·1000/vidaMáx·20)` en float32 exacto; un mago, 300.
  - **Rotura:** se rompe con `Health.hit` > 0.
  - **Deshielo:** 150 de hechizo con esquirlas.
- **`ShotInFlight`:** hijo de vuelo de un disparo. `ShotDropper` (Abomination) y `GrowingWave` (Silverback `rdba`; antes `FrostWave`, F162) heredan de él.
- **`GrowingWave`:** (F162; antes `FrostWave`) onda que crece hasta 7,5 m y no choca (`ShotLook.collides = false`). Tiene memoria de tocados: el blanco pedido recibe 100 % directo y el resto, salpicadura con caída.
- **Un dueño:** `Afflictions._show` es el único que escribe la pose congelada (`clip_pose.frozen`) y el look del mesh, a través de un único `StoneLook` (`Afflictions/Look`). El tinte sale de `AfflictionType.look_tint` y `look_priority`: la piedra gana al hielo.

**Cierre (2026-10-17).** La review pidió CHANGES por B1: piedra e hielo escribían los dos el material del mesh. Se corrigió en una ronda con un dueño único del look (`reviews/REVIEW-RFC-030k-b.md`).
- **Congelado:** el Trogg recibe 450 y queda congelado 1250 ticks. El Druid recibe 14 de salpicadura y queda 1500. Deriva de 0,0000 m mientras duran.
- **Deshielo:** 0 al Trogg (es inmune) y 150 al Druid, sin derribo.
- **Rotura:** el dardo del Deadeye rompe el hielo en el cuadro 104 y el daño del deshielo entra en el 105.
- **Determinismo:** `f149` da `bf28b3fd` en fixed, stress y window. `quick`: s7, f139, s1_quick, f148 (después del refactor), f121, f122 y f123 iguales a la línea base.
- **Otras pruebas:** `f137` sigue gris y sin deriva. `rules_suite` PASS.
- **Playtest con ventana:** PASS en los 4 puntos (`agent/out/pt149/play/`).

Deuda:
- **Golpe de 0:** no rompe el hielo; en sacengine sí.
- **Hielo:** es un tinte gris azulado sutil, no el cubo `frez`.
- **Esquirlas:** se tiñeron de azul para que se vean sobre la nieve.
- **Fuera de este corte:** `healBlocked` y el sonido.
- **Sin captura:** que E1 vuelva a moverse después del deshielo.

### F124 — Rayo del Gnome y golpe del Styx (RFC-030, corte 030m-a)

**Piezas:**
- **`ShotLook.strike`:** escena `ShotStrike` que reemplaza el vuelo. La instancia `RangedAttack._strike` como hijo, solo en el servidor.
- **`RayStrike`** (`gnome_ray.tscn`): un rayo `collideRay` en el mismo tick. Lo frena cualquier cuerpo, de cualquier bando. Hace 600 directos y el fuego amigo lo decide `Health`.
- **`TargetStrike`** (`styx_strike.tscn`): golpe en T+1 sobre el centro del blanco vivo, con la salpicadura del Mutant.
- **`ShotImpact.land`:** único dueño de lo que pasa donde pega, para disparos y strikes.
- **`ShotAim.scatter`:** la precisión de sacengine, movida sin cambios.
- **`ShotLook.for_tag`:** única búsqueda de looks.
- **`BeamType.blend`:** `ADD` o `MIX` (`beam_mix.gdshader`). El fogonazo `gnome_flame` usa `MIX` con el atlas `gmfl_a`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030m-a.md`). El fogonazo no se veía sobre la nieve; se corrigió con la mezcla `MIX` y quedó medido en verde, luminancia 0,736 contra 0,690 de la nieve.
- **Gnome:** 540 al Druid en el mismo tick de `fired`. El maná del Gnome pasa de 200 a 187.
- **Aliado que frena:** el Trogg aliado frena el rayo con 0 de daño. El Druid de atrás queda en 800.
- **Styx:** golpe en T+1. Hace 450 / 280,35 / 0 y el maná pasa de 500 a 467.
- **Determinismo:** `f124` da `c5abf4c8` en fixed, stress y window. `quick`: s7, f139, s1_quick, f148, f121, f122, f123 y f149 iguales a la línea base. `rules_suite` PASS.
- **Playtest con ventana:** PASS en los 4 puntos (`agent/out/pt124/play/`).

Deuda:
- **Fogonazo:** sale a la altura del disparo (unos 0,9 m adelante), no en el arma del hombro. Falta un hueso de mano y va con el sistema de animaciones.
- **Rayo del Styx:** se ve recto y liso, termina un poco antes del blanco y no tiene `StyxExplosion`.
- **Salpicadura:** no tiene anillo visible.
- **Bench:** la línea de kill del banco usa una base de ticks distinta a la de `fired`.
- **Styx gibeado en T:** el golpe no cae (M4).
- **Caso sin ejercitar:** el tirador que muere en T.
- **Menores M1-M3:** `source` sin tipo y `shot_origin()` sin caller hasta 030m-b; el watch lee una variable privada.

### F125 — Abanico del Boulderdash y fuego del Phoenix (RFC-030, corte 030n-a)

**Piezas:**
- **`ShotLook.volley`** (`emba` = 3): `RangedAttack._fire` dispara varias balas con una sola tirada de puntería y le pone a cada una `volley_index` y `aim_distance`.
- **`ShotLook.range_factor`** (`emba` = 2): multiplica el alcance.
- **`RangedShot.spawn_data`:** guarda el paquete con que nació el disparo; es de solo lectura.
- **`ShotSplit`** (un `ShotInFlight`): gira las piedras laterales ±3,5° después de moverlas, en el tick en que `max(0, d−60)` cruza 0.
- **Phoenix `rdra`:** reusa `heat_ray_impact` (el fuego del Tickferno).

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030n-a.md`).
- **Abanico:** ±3,5000° a los 8,138 m. Las 3 piedras pegan en Druid2/1/3 a ≤0,003 m de `f125_expect.py` y hacen 450 cada una.
- **Phoenix:** 732,0 en 61 actualizaciones, sin daño directo, y drena 50,83 de maná. El Druid termina en 82,5 porque está dentro del radio de `FountSouth`, igual que en sacengine.
- **Determinismo:** `f125` da `c06a1501` en fixed, stress y window. `quick` PASS sin cambios en las líneas base. `rules_suite` PASS.
- **Playtest con ventana:** PASS en los 4 puntos (`agent/out/pt125/play/`).

Deuda:
- **Pasto:** tapa las piedras en vuelo (vuelan a ~1 m) y a los Druids. Viene apareciendo en todos los cortes; conviene un tema aparte (cámara, altura del pasto o recorte alrededor de las unidades).
- **Giro visual:** cada piedra tiene el suyo; en sacengine lo comparten.
- **Final del alcance:** `>=` contra `<0` de sacengine.
- **Phoenix:** sin el tubo de 30 cuadros y dispara desde tierra (deuda de 030e).

### F151 — Rhinok: disparo pegado al suelo y anillos de púas (RFC-030, corte 030n-b)

**Piezas:**
- **`GroundHug`** (un `ShotInFlight` con `holds_height() = true`): es el único dueño de la altura del disparo, que va a 0,05 m sobre `RangedShot.ground_height()`. Esa altura cuenta techos, igual que `getHeight`. `RangedShot` ya no hace su chequeo de suelo para este disparo.
- **`SpikeImpact`:** al tocado le hace 500 `splash_ranged`. Al blanco pedido le hace daño solo si de verdad se agotó el alcance (`range_spent()`).
- **`SpikeWave`:** anillos en +14/29/44/59/89 cuadros, cada uno de 1 + 5,75·i a +6 m. Dañan criaturas, magos y edificios sobre tierra y a ≤10 m de altura, sin el tocado ni aliados. Hacen un golpe por anillo.
- **Púas visuales:** `scenes/fx/spike_field` es un MultiMesh con la malla de `makeSpikeMesh` y la textura `jspk`. `FxBus.broadcast_scene` manda un RPC con parámetros por anillo: 10 por disparo en vez de unos 70.

**Cierre (2026-10-17).** La review pidió CHANGES por B1: el disparo reventaba contra manantiales y estructuras, y el blanco pedido recibía 500 desde lejos. El playtest falló en lo visual: las púas se veían como puntitos. Las dos cosas se corrigieron en una ronda (`reviews/REVIEW-RFC-030n-b.md`).
- **Anillos:** C0 recibe 450 al chocar. De C1 a C5 reciben 450 cada uno en +14, +29, +44, +59 y +89. C6 (aliado) y el Rhinok no reciben nada. La jhut y los dos jcc2 reciben 500.
- **Carril D:** el disparo pasa por encima del manantial jfnt (sube a 19,10 m) y choca con D1 a 16 m.
- **Determinismo:** `f125` da `04bb9085` en fixed, stress y window, con `f151_expect` y `f125_expect` en PASS. `quick` y `rules_suite` dan PASS.
- **Look:**
  - el muro de púas se ve de costado (`agent/out/pt151/pt/p3_ring5_side.png`);
  - desde arriba, la franja del anillo gana entre 2 y 4 puntos de píxeles oscuros contra el interior y el exterior (`f151_bands.py`).

**Desvío aprobado:** las púas de cada anillo duran 0,4 s y no 2/3 s. Con 2/3 s se ven tres anillos a la vez y no se lee cuál daña.

Deuda:
- La rama «alcance agotado con el blanco vivo» no se puede provocar con la IA del banco. La cubre solo la guarda.
- El blanco pedido aliado pasa por el fuego amigo (m3, declarado).
- La señal visual cenital es débil y el pasto sigue tapando a los cuerpos.
- `SpikeWave` vive en el contenedor de disparos (R4, sin probar en red).

### F126 — Catálogo de habilidades, LifeShield y Protector (RFC-030, corte 030o-a)

**Piezas:**
- **`AbilityCatalog`** (`data/abilities/ability_catalog.tres`, con `{"HSba": protector.tscn}`): asocia cada tag con un `AbilityEffect`.
  - `ActiveAbility` instancia el efecto y le delega `status()` y `fire()`.
  - El gasto de maná y el enfriamiento siguen siendo de `ActiveAbility`.
  - La rama vieja del `match` pasó a `_apply()`.
- **`LifeShield`** (componente de `unit.tscn`): es el único dueño del escudo.
  - `is_on()` se deriva de `MatchClock` en el servidor y del `shown` replicado en el cliente.
  - `start_for(ability)` arranca el escudo.
  - La burbuja usa un shader fresnel en MIX, escalada ×1,4 de la caja (`renderer.d:3511`).
- **`Health.shield_factor()`** = `damage_factor` (Rockform) · `life_shield.factor()`. `pierce_shield` lo saltea.
- **Protector (Ent):**
  - Gasta 300 de maná y se pone el escudo.
  - En T+1 se lo da a los aliados del mismo slot que estén a ≤ 30 m (3D, centro a centro). No incluye magos, inválidos ni a quien ya tenga escudo.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030o-a.md`). El playtest falló en un punto visual: la burbuja sobre un Druid no se leía. Se corrigió en una ronda con el shader fresnel; azul − rojo da +27,8 contra el pasto y Druid4 sin escudo da −2,7.
- **Protector:** `mana 500->200`. En T+1, Druid1 a 10 m lo recibe, Druid2 ya tenía y Druid3 a 35 m queda fuera. El enemigo no aparece.
- **Escudo:** el rayo del Gnome deja a Druid1 en 530 (sin escudo quedaría en 260). Los escudos terminan en T+1200 y el de Druid1 en T+1201.
- **Life Shield del Druid:** migrado. Ahora se ve como burbuja y no como transparencia.
- **Determinismo:** `f126` da `446809b6` en fixed, stress y window. `quick` PASS sin cambios en las líneas base. `rules_suite` PASS.

Deuda:
- **Enfriamiento de `ActiveAbility`:** se descuenta con `delta` y no con ticks. Es de antes; se migra en 030o-b.
- **Bando:** se compara por slot.
- **Ent muerto en T:** no reparte el escudo en T+1. Falta confirmarlo contra el original.
- **Escudo tras revivir:** un cuerpo que vuelve a la vida no recupera la burbuja.
- **Textura:** la `ent1.TXTR` animada del original no está en los datos exportados.
- **Duración mínima:** se perdió el piso de 1 s. No afecta a los datos actuales.

### F152 — Preparación de habilidades y Firewalk del Warmonger (RFC-030, corte 030o-b)

**Piezas:**
- **`UsingAbility`** (aflicción `using_ability.tres`, bit 4, `holds`): las habilidades con `windup()` retienen el cuerpo hasta el shoot tick de shoot1.
  - `ActiveAbility` cobra el maná en ese tick aunque el efecto falle, y pone el enfriamiento solo si estaba en 0.
  - Si un aturdimiento, petrificación, congelación o tumbo corta la preparación, no gasta nada.
- **`Firewalking`** (`firewalking.tres`, bit 5, `holds` + `hides`): `steer()` es el único que escribe la posición.
  - Recorre 60 cuadros: lineal hasta 20 m y, más allá, en dos mitades de ±10 m con un salto en el medio.
  - Durante la caminata no es blanco ni obstáculo, no recibe daño y no se lo puede inmovilizar.
  - Es invisible y deja una estela de llamas (`firewalk_trail`) con un estallido al empezar y otro al terminar.
- **`AfflictionType.hides`** → `Afflictions.hides()`, que leen `is_targetable` e `is_obstacle` (neto 0 líneas).
- **Firewalk (`wfhg`)** en el catálogo: alcance 200·0,75.
- **Enfriamientos en ticks:** el de `ActiveAbility`, el de Stealth y el de Play Dead pasan a contarse en ticks de `MatchClock`.
- **Banco:** las acciones `ability` y `stun` viven en `debug/`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030o-b.md`). El playtest falló en lo visual: la estela no se leía, porque el pool de `fire` era de 16 y se vaciaba. Se corrigió en una ronda; R−B quedó +70,7 sobre el pasto, con 4× más píxeles de fuego.
- **Preparación:** 150 ticks; el maná pasa de 500 a 250 y el enfriamiento queda en 600 ticks.
- **W1:** salta 40,36 m en el cuadro 31 y termina en (1280, 1290).
- **W2:** avanza 0,25 m por cuadro.
- **W3:** a 160 m queda «Fuera de alcance», sin gastar maná.
- **Corte:** si se lo aturde durante la preparación, sale `preparación cortada` y no gasta.
- **Determinismo:** `f126` (carriles A + B) da `45d8baca` en fixed, stress y window. Las otras 10 líneas base no cambian con la migración a ticks. `quick` y `rules_suite` dan PASS.

Deuda:
- Con la cámara alineada con el recorrido, la estela se ve como una bola de llamas y no como un rastro.
- El print de `ActiveAbility` sigue siempre encendido (R6, 030v).
- Fuera de alcance rechaza la habilidad en vez de acercarse.
- Mientras camina, la cápsula sigue en la capa de unidades.

### F127 — Halo of Earth del Rhinok (RFC-030, corte 030p-a)

**Piezas:**
- **`HaloOfEarthAbility`** (`HRba` en el catálogo): crea el coordinador `HaloOfEarth` en el contenedor de disparos. Corre solo en el servidor, con prioridad −1.
- **`HaloOfEarth`:** es el único dueño de las 6 rocas.
  - Nacen en T+1 dentro de la caja ×1,25.
  - Sin blanco, orbitan con Hermite.
  - Con blanco, persiguen sumando 3 por tick hasta 30.
  - Explotan al chocar con un no aliado, al tocar el suelo desde la edad 35 o al cumplir 2100 ticks.
  - Hacen 600 de daño de hechizo directo.
  - Usan `MatchSeed.rng(["halo", …])`.
- **Las rocas** son `RangedShot` (look `halo_rock`, `collides false`) que crea `ShotSpawner.spawn_shot`, que ahora devuelve el nodo. Cada roca usa `RangedShot.touching()`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030p-a.md`).
- **Gasto:** el maná pasa de 750 a 100 y el enfriamiento es de 2400 ticks.
- **Blancos:** la roca 0 va a Druid1 y la roca 1 a Trogg2.
- **Daño:**
  - Druid1 recibe 600 y después 211 (200 más 11 de regeneración), y muere.
  - Trogg2 es inmune: recibe 4 golpes de 0.
  - El aliado y el Druid a 65 m nunca son blanco.
- **Fin:** el coordinador termina en el tick 248.
- **Determinismo:** `f127` da `d165115b` en fixed, stress y window. `quick` y `rules_suite` dan PASS.
- **Playtest:** las rocas en órbita se ven bien y el impacto sobre Druid1 también.

Deuda:
- Las rocas que persiguen vuelan a ras del suelo y el pasto las tapa (es el corte del pasto, pendiente).
- Si el Rhinok muere antes de T+1, el coordinador termina (en el motor queda vivo).
- El choque usa la cápsula en lugar de cajas.
- La línea de vista es un rayo.
- La órbita usa un RNG propio.
- Sin temblor ni sonido.
- Sin probar en red (R3).

### F153 — Breath of life del Dragon (RFC-030, corte 030p-b)

**Piezas:**
- **`BreathOfLifeAbility`** (`filb` en el catálogo):
  - Preparación tomada del clip (`AbilityEffect.windup_from_clip`, un solo `windup()` en la base).
  - El blanco se resuelve de alma a cadáver. Tiene que estar muerto, ser del mismo slot, con el alma en NORMAL o EMERGING, y a ≤ 40 m.
- **`BreathOfLife`:** solo servidor, prioridad −1. Mueve un `RangedShot` con `v = 60·(t − p)` y tope 60.
- **`FastRevive`:**
  - Es hijo del cuerpo y dura 150 ticks.
  - Vida al máximo y alma en REVIVING.
  - Sube 1,97 m y gira 2π.
  - Al final quita el alma y llama a `Captive.finish_revive()`, que devuelve el cuerpo a IDLE, a su capa y al grupo `unit`.
- **`match_command._ability_at`:** el clic busca cuerpo, alma, cadáver y suelo, en ese orden. El alma y el cadáver solo se buscan si la habilidad tiene `targetSouls` o `targetCorpses`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030p-b.md`).
- **Rechazos:** «Blanco inválido» con un cadáver enemigo y «Fuera de alcance» a 48 m, sin gasto.
- **Gasto:** preparación de 52 ticks, maná de 750 a 700 y enfriamiento de 240.
- **Aliento:** sale en el tick 152 y llega en el 172 (±1 respecto de la réplica).
- **Revivir:** D1 vuelve con 800/800 en el tick de llegada, sube 1,9733 m y queda IDLE a los 150 ticks, en el grupo `unit` y sin alma.
- **Determinismo:** `f153` da `130a619b` en fixed, stress y window. `quick`, con las 12 líneas base iguales, y `rules_suite` dan PASS.
- **Playtest con ventana:** PASS en los 5 puntos.

Deuda:
- El aliento dorado se ve pálido y chico sobre la nieve.
- En red, el path del `Soul` en `submit_ability` no está probado (m1).
- El clic real sobre un alma o un cadáver no se probó en ventana.
- Sin re-selección ni vuelco final.
- El aliado se decide por slot.

### F150 — Ráfaga del Warmonger (RFC-030, corte 030m-b)

**Piezas:**
- `strikes/warmonger_gun.tscn` es un `RayStrike` con:
  - 16 ráfagas de 2 rayos, la primera en el tick 2 y luego una cada 4 ticks;
  - puntería sorteada en cada rayo;
  - origen que sigue al tirador (`follow`) y `foes_only`.
- Si el tirador muere, la ráfaga se corta.
- No tiene fogonazo propio. Donde pega cada rayo salen chispas `warmonger_hit` (`wsqb_a`, MIX).
- `RangedAttack` ahora tiene `class_name`. `ShotStrike.source` quedó tipado y `shot_origin()` se llama directo (M1 y M2 de F124).

**Cierre (2026-10-17).** La review aprobó el corte (`reviews/REVIEW-RFC-030m-b.md`).
- **Carril C:** salen las 16 ráfagas y los 32 rayos, en los ticks 109 a 169. Druid6 recibe 5 rayos de 72. Trogg2, aliado pegado al blanco, frena rayos sin recibir daño y queda en 960. El maná baja de 500 a 467 una sola vez.
- **Carril E:** sale `ametralladora fhga cortada: tirador muerto tras la ráfaga 7/16` y después no hay más rayos.
- **Carriles A, B y D:** dan las mismas líneas que antes.
- **Determinismo:** `f124` da `3a9bb548` en fixed, stress y window. `quick` y `rules_suite` dan PASS.
- **Playtest:** PASS en los 4 puntos. Las chispas se distinguen de la nieve (R−B ≈ +130).
- **Desvío:** el carril C se movió a (1375, 1155), porque la choza `jhut` y una loma cortaban la línea de tiro.

Deuda:
- Las chispas salen también cuando el rayo termina en el aire.
- No se probó en red.

### F128 y F154 — Web pull del Gremlin y Cage pull del Seraph (RFC-030, cortes 030q-a y 030q-b)

**Piezas:**
- **`Pull`** (`AbilityEffect`): preparación de 54 ticks y `starts_cooldown = false`. Es un knob nuevo de la base y `ActiveAbility._spend` lo respeta.
  - `status`: el blanco tiene que ser no aliado, sin Life Shield y estar a ≤ 50 m.
  - `fire`: tira un rayo de rebote al primer cuerpo vivo del camino.
- **`Pulling`** (afflicción del usuario, bit 6, `holds`): es el único dueño de la simulación del tirón.
  - Tira en el último cuadro del clip: aturde 480 ticks y lanza `catapult(−16,5·dir + 0,8175 arriba)`.
  - Durante una ventana de 25 ticks le pisa la velocidad al blanco con `Tumbling.drive`.
  - También maneja el tirón extra y el fin.
  - `stunned`, `petrified`, `frozen` y `tumbling` lo cancelan.
- **Hilo** (`pull_thread`): hebra de color oscuro para la Web y rayo azul para la Cage, en MIX. Se dibuja con `FxBus.broadcast_scene` y se libera con el bit replicado.
- **`BodyNudge.fixed()`** (`Afflictions.immobilized()`) es el único dueño de «¿se puede mover?»: `slide`, `push` y `catapult` no mueven a un cuerpo petrificado ni congelado.
- **Carga:** `ActiveAbility` vuelve a comprobar `mana >= coste` en el tick de carga.

**Cierre (2026-10-17).** La review pidió cambios por B1: un blanco petrificado o congelado se deslizaba. Se corrigió en una ronda y se agregó el carril R (`reviews/REVIEW-RFC-030q.md`).
- **Rechazos** sin gasto de maná.
- **Carga:** 54 ticks, maná de 300 a 240, sin enfriamiento.
- **Web:** tirones en T+162, T+326 y T+490. Termina en la 3.ª ventana con distancia de caja 2,87.
- **Cage:** 4 tirones y termina en T+815.
- **Carril R:** con el Druid petrificado por un Basilisk, dos tirones lo dejan en x = 1488,000 (desvío 0).
- **Vuelo:** el vuelo libre entre ventanas (~11,7 m por ciclo) es fiel a sacengine.
- **Determinismo:** `f128` da `3a314b14` en fixed, stress y window. `quick` y `rules_suite` dan PASS.
- **Playtest:** el hilo de la Web se ve (contraste 3,66). El Druid se arrastra a ras del suelo con saltitos de menos de 1 m, fiel al impulso vertical de 0,8175. El blanco termina cerca y el hilo desaparece.

Deuda:
- La jaula del Seraph se ve como un cable azul; faltan las texturas `cord` y `ltng`. No se dibuja la red alrededor del blanco.
- El usuario no camina ni gira; tampoco hay clip de disparo.
- El hilo se suelta antes de tiempo si la latencia pasa de 30 ticks.
- El Druid queda clavado tras el aturdido que deja la caída, aunque la ventana siga activa. Está pendiente de revisar.

### F129 — Sticky bomb del Ikarus, PaceFactors y Clinging (RFC-030, corte 030r-a)

**Piezas:**
- **`PaceFactors`** (unidades y magos): único dueño de `speed_factor`, que es el producto de las fuentes ordenadas por nombre. Solo escribe si el valor cambia y corre solo en el servidor. Speedup pasa por acá; el doctor sigue escribiendo directo.
- **`Clinging`:** guarda lo que tiene pegado cada cuerpo, por tipo y con vencimiento en ticks. Le da `factor^n` a `PaceFactors` y replica `shown` para el look.
- **`LobAbility`:** el efecto común de las habilidades que lanzan proyectiles. Tiene `shots`, `spread` y `falling`, y usa el RNG `["lob", …]`.
- **`StickImpact`:** pega la bomba solo a criaturas enemigas que se pueden envenenar.
- **`ShotAim.origin()`:** compartido.
- **`AbilityEffect.windup()`:** 2 ticks por cuadro; si el clip no trae `lrba`, usa el último cuadro.
- **Banco:** acción `attack` con el knob `order`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030r-a.md`).
- **Lanzamiento:** preparación de 94 ticks; el maná baja de 300 a 240 y el enfriamiento queda en 360.
- **Bombas:** cada una de las 10 pega o cae al suelo según la réplica (±1). El aliado no recibe ninguna.
- **Velocidad:** queda en 0,75ⁿ (±2 %) y vuelve a 1,0 cuando se sueltan las bombas, en el tick +601.
- **Determinismo:** `f129` da `7c69f9b0` en fixed, stress y window. Lo volvió a correr el orquestador después de los ajustes visuales. `quick` (incluidos Speedup y Firewalk en `f126`) y `rules_suite` dan PASS.
- **Desvíos en el banco:**
  - La habilidad se usa a los 0,7 s.
  - El Druid pacifista recibe una orden `move`.
  - La ventana corre con `--autostart --seed=2`.

Deuda:
- La esfera ámbar es un placeholder. Las bombas en vuelo se ven chicas y el pasto tapa las pegadas.
- Una criatura a la que no se le puede pegar frena la bomba (en sacengine la atraviesa).
- El log `marcha` está dentro de `Clinging`.

### F130 — Call lightning y la carga de rayo del Storm Giant (RFC-030, corte 030s-a)

**Piezas:**
- **`Health.damage_typed(..., mods)`:** `LIGHTNING = 1<<5`, `IGNITE = 1<<6`; `_passive_factor(before, mods, from_slot)`.
- **`LightningStrike`:** coordinador que vive solo en el servidor. Aplica el retardo de 12 y el rebote, y hace el daño de hechizo directo con `LIGHTNING`. Se llama así porque `LightningBolt` ya existía en `scenes/fx`.
- **`CallLightning`:** cuesta −50 de maná y no tiene enfriamiento. El rayo `ntil` nace en `centro + 100·normalize(uD + (0,6,0))`, con el RNG `["call_lightning", …]`.
- **`LightningCharge`:** es el único dueño de la carga.
  - `absorb`: suma `int(f·daño)` (f = 4 para aliados, 2 para el resto) y deja el daño en ×0,25.
  - Descargas `gcil` de 250 a cuerpos o al suelo, cada una por −125.
  - `PaceFactors`: ×1,5.
  - Chispas con un RNG de presentación.
- **`DamagePassive` y `MeleeAttack`:** golpe y precisión ×1,5. El log del golpe está detrás de `log_melee`.

**Cierre (2026-10-17).** La review pidió cambios por B1 (la dirección del cielo no se normalizaba primero). Lo corrigió el orquestador (`reviews/REVIEW-RFC-030s-a.md`).
- **Uso:** maná de 200 a 150. En T+12 el gigante se hace 93,75 de daño y suma +1500 de carga.
- **Cargado:** paso 0,225 contra 0,150 y precisión 2250 contra 1500.
- **Descargas:** 4, cada una por −125. La carga termina en el tick 1016.
- **Determinismo:** `f130` da `84715e1b` en fixed, stress y window, también después de B1. `quick` y `rules_suite` dan PASS.
- **Playtest:** PASS. Se ven el rayo, las chispas y las descargas al suelo.

Deuda:
- El rayo se ve blanco sobre la nieve; se lee por el halo.
- `styx_spark` no se probó con varios rayos al mismo tiempo.
- La carga se calcula en float64.
- Aliado se decide por slot.
- Los edificios no frenan el rayo.
- Sin probar en red (R8).

### F155 — Viscous oil del Pyrodactyl y DamageMod.ignite ×2 (RFC-030, corte 030r-b)

**Piezas:**
- **`Oiled`** (afflicción, bit 7, `coexists`):
  - dura 900 ticks y borra las órdenes en cada tick; en las unidades tiene `holds` y en los magos no;
  - `ignite()` hace estallar el aceite al tick siguiente: 500 de salpicadura con `IGNITE` en un radio de 5, a nombre del que tiró el aceite, más fuego visual y la bola `oil_blast`.
- **`AfflictionType.coexists`:** `admit` lo saltea en las dos direcciones.
- **`Health.oil`:** un golpe con `IGNITE` sobre un cuerpo untado vale ×2, después del chequeo de bando.
- **Cadena de mods:** `ShotLook.ignites` → `RangedShot.mods` → `ShotImpact.mods_of` → `DirectImpact`/`SplashImpact` → `SplashDamage.deal`/`hurt`.
  - Encienden: `fkba`, `cfba`, Fireball y la nube de vapor.
  - No encienden: Tickferno y Phoenix.
- **`ShotLook.hits_every_side`:** la bola de aceite le pega a cualquier bando.
- **`Afflictions`:** `held_changed` también se emite cuando cambia `breaks_special_modes()`, así un cuerpo untado en Rockform que es petrificado cierra el Rockform.
- **Look untado:** negro brillante, con un `StoneLook` que ahora tiene los knobs `base`, `gain`, `roughness` y `metallic`.

**Cierre (2026-10-17).** La review pidió cambios por B1 (Rockform untado y petrificado) y el playtest falló en lo visual: el untado no se distinguía y la explosión era chica. Se corrigió todo en una ronda (`reviews/REVIEW-RFC-030r-b.md`).
- **Lanzamiento:** maná de 300 a 240. Quedan untados O1, O2, O3 y O5; O5 queda quieto (0,0000 m).
- **Encendido:** el primer `fkba` sobre O1 hace 288. O1 arde y explota al tick siguiente (450). O2 explota en cadena. O3, que es aliado, recibe 0 y no arde. El aceite se limpia en +901.
- **Carril R:** aparece `rockform cerrado Earthfling1` al petrificar a un Earthfling untado.
- **Look:** el untado oscurece la silueta entre 49 % y 59 % (antes 4 %). La explosión ocupa 12 veces más píxeles de fuego, con una bola de unos 500 px.
- **Determinismo:** `f155` da `5727036b` en fixed, stress y window. `quick` y `rules_suite` dan PASS. `f123`, que ahora enciende, no cambia.

Deuda:
- `holds` del aceite es más fuerte que en sacengine: bloquea habilidades y deja colgados a los que van en vuelo (declarado).
- Las explosiones en cadena siguen el orden del árbol.
- Sin manchas ni `igniteBuilding`.
- Rain of Fire, Lava ball y Dragonfire van a tener que llevar `IGNITE` cuando entren.
- El aliento del Spitfire (`fhba`) es un cono y queda para su propio corte.

### F156 — Bilemites del Blight (RFC-030, corte 030s-b)

**Piezas**
- `MiteHop` (`ShotInFlight` con `holds_height`) mueve cada ácaro:
  - g = 20; en cada toque de suelo salta hacia la criatura más cercana a ≤ 15 m y con ≤ 10 de altura, con prioridad para el blanco pedido (`spawn_data["intended"]`);
  - al 5.º toque se queda quieto y `spent()` libera el disparo a los +30;
  - el suelo lo da `Terrain`, sin techos;
  - RNG `["mites", nombre]`.
- `ShotInFlight.spent()` es nuevo y `RangedShot` libera el disparo cuando da true.
- `LobAbility` gana `intended` y `uniform_direction` estático, compartido con `MiteHop`.
- `ShotLook.hits_only_poisonable`: el ácaro solo choca con cuerpos que se pueden envenenar.
- Cada ácaro se pega con `StickImpact` (`mites`, ×0,8, +481) en `Clinging`.

**Cierre (2026-10-17).** La review pidió cambios por B1: `spent()` no tenía evidencia. Se agregó el carril N, se aplicó M1 (`hits_only_poisonable`) y M2 (filtro de altura del blanco pedido) (`reviews/REVIEW-RFC-030s-b.md`).
- **Maná:** 200 → 140 en T+94.
- **Carril M:** 30 saltos y todas las pegadas según la réplica (±1). El factor baja hasta 0,8¹⁰ = 0,107, cada ácaro se suelta a +481 y el factor vuelve a 1,0.
- **Carril N:** sin blancos, los 10 ácaros hacen 5 saltos, quedan `parado` y se liberan a +30 exactos.
- **Determinismo:** `f156` da `73dfff7f` en fixed, stress y window. `quick` (con `f129` y `f155` iguales) y `rules_suite` dan PASS.
- **Playtest:** los ácaros se ven saltando, y pegados se ven como esferas verdes sobre el Druid. El factor baja y se recupera según el log.

**Deuda**
- Un ácaro quieto sigue chocando durante sus 30 ticks.
- Nunca choca con el tirador. En sacengine sí puede después del cuadro 30.
- El look es de reserva (esfera verde).
- Sobre un hueco vuela hasta el fin del alcance.

### F131 — Devour de la Netherfiend y el Hellmouth (RFC-030, corte 030t-a)

**Piezas:**
- **`DevourAbility`** (`ifna`, `windup_from_clip`):
  - Necesita un alma azul en NORMAL o EMERGING, a una distancia 2D ≤ la diagonal de la caja.
  - Llama a `soul.begin_devour` y a `DevourGrowth.grow`.
  - Si la criatura no está llena, la cura con Rainbow: 600 en 150 ticks.
- **`DevourGrowth`:** es el único dueño de n, del incremento, de la regeneración extra (inc/60), de la resistencia ×0,9ⁿ y del bulto `2 − 0,75ⁿ`, que escala el mesh. Replica `shown`.
- **`Soul`:**
  - estado `DEVOURING`, al final del enum;
  - `begin_devour` encoge el alma 3/60 por tick hacia el origen del disparo;
  - `sever()` es el único que disuelve el cadáver;
  - `is_free_or_own` y `on_corpse` (que Breath también usa).
- **`Health`:** `growth`, `raise_maximum` y resistencia con el factor de crecimiento.
- **`MeleeAttack`:** la resistencia también usa el factor de crecimiento.
- **`ActiveAbility`:** el costo pasa a `float(mana_cost)`. Una habilidad de costo 0 no gasta y se puede usar con maná 0, como en sacengine.
- **Banco:** `BenchEvent.target_soul` y `BenchGroup.holds_still`.

**Cierre (2026-10-17).** La review pidió un cambio (B1: API solo para el harness). Lo resolvió el orquestador. Detalle en `reviews/REVIEW-RFC-030t-a.md`.
- **Rechazos:** «Blanco inválido» y «Fuera de alcance», sin gastar maná.
- **Netherfiend con un alma:** vida 900 → 1400, máximo 2300, regeneración +9,583/s, resistencia ×0,9. Maná 500 sin cambio, sin enfriamiento.
- **Netherfiend con dos almas:** máximo 2800, regeneración +18,854/s, resistencia ×0,81. El golpe de un Trogg sale con resistencia 0,6075.
- **Hellmouth:** 5900/5900, sin cura.
- **Cura:** +4 por tick durante 150 ticks.
- **Determinismo:** `f131` da `6973c160` en fixed, stress y window. `quick` no cambia, ni antes ni después del costo 0 (Play Dead y `f153` incluidos). `rules_suite` da PASS.
- **Playtest:** el alma se encoge hacia la Netherfiend y la Netherfiend crece ×1,39 en píxeles.

Deuda:
- El cadáver desaparece de golpe a los 2,5 s (`Corpse.dissolve` no tiene fundido). Vale para todo el juego.
- No se acerca ni gira hacia el alma.
- El bulto es una escala del mesh, no el inflado del original.
- Sin sonido.

### F157 — Rend Soul del Styx (RFC-030, corte 030t-b)

**Piezas**
- **`RendSoulAbility`** (`dner`): sale del primer clip de disparo (`windup_clip 0`, 100 ticks). La valida la misma regla `can_rend` del golpe.
- **`SoulStrike`** (`ShotStrike`, `land_tick 1`): vuelve a chequear, hace `Soul.burst()` (que llama a `sever()`) y dibuja el beam styx. La salpicadura de 2500 con caída a 40 m sale de `rend_blast_impact` (`SplashImpact` sin golpe directo).
- **`AbilityEffect.windup_clip`**: knob nuevo, con valor por defecto 1.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030t-b.md`).
- **Rechazos:** «Fuera de alcance» a 95 m y «Blanco inválido» con un alma roja, sin gastar maná.
- **Uso:** prepara 100 ticks; maná 500 → 400; enfriamiento 600.
- **Estallido:** el alma revienta y el cadáver se disuelve en el mismo tick. Los Jabberocky reciben 1728, 1306, 837 y 368; el quinto, fuera del radio, recibe 0. El aliado y el Styx reciben 0.
- **Determinismo:** `f131` (carriles D y R) da `8e93f3cb` en fixed, stress y window. `quick` y `rules_suite` dan PASS.

**Deuda**
- El estallido no se lee: faltan las 2 `StyxExplosion` y las chispas se pierden sobre la nieve. En el banco, además, un Devour simultáneo justo al lado lo tapa.
- `fire()` vuelve a chequear el alcance de 90 m al disparar.
- Sin sonido.

### F132 — Quake del Jabberocky (RFC-030, corte 030u-a)

**Piezas:**
- **`AbilityEffect.pays_upfront`:** `ActiveAbility` cobra el maná al empezar la preparación, igual que `act()` de sacengine. En el disparo hace `fire()` y pone el enfriamiento si estaba en 0. `_spend` se separó en `_pay`, `_start_cooldown` y `_log_spent`.
- **Preparación cortada:** ahora se detecta en el tick del corte, no en el del disparo.
- **`QuakeAbility`** (`kauq`, shoot0, 192 ticks): lanza `QuakeWave` en los pies del Jabberocky.
  - **`QuakeWave`** corre solo en el servidor. La onda avanza 1,667·f m en float32 (`SacFloat`). En los cuadros 1–5 aturde 480 ticks a todo cuerpo dentro de la banda, de cualquier bando. No hace daño.
  - **`QuakeRing`** es un anillo de tierra en MIX que sigue el reloj de partida.
- **`SacFloat`:** dueño único de la emulación float32. `Frozen` también lo usa.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030u-a.md`). El playtest encontró a J1 pisando una cabaña: se movió el carril y `--lanes` ahora mide la caja real.
- **Uso:** maná de 500 a 200 al empezar. La sacudida sale en T+192 con enfriamiento 600.
- **Aturdidos:** Q1, Q2 (aliado) y Q3 en T+195, T+196 y T+197. Q4, Q5 y J1 nunca quedan aturdidos. La onda se libera en T+223.
- **J2 cortado:** pierde el maná sin sacudida ni enfriamiento y después da «Sin maná». J1 da «Enfriando».
- **Determinismo:** `f132` da `b929107e` en fixed, stress y window. `quick` (19 líneas base) y `rules_suite` dan PASS.

**Deuda:**
- Los aturdidos no se distinguen visualmente, porque la inclinación es provisional.
- El Jabberocky no tiene pose de preparación.
- No hay deformación del terreno, temblor de pantalla ni sonido.
- El anillo avanza a saltos de tick.

### F158 — El Yeti congela al golpear (RFC-030, corte 030u-b)

**Piezas:**
- **`MeleeAttack`** ahora tiene `class_name` y emite `connected(target, was_frozen)` después de cada golpe, aunque haga 0.
- **`MeleeOnHit`** es un componente de `unit.tscn` con `types: Array[OnHitPassiveType]`. Por cada pasiva al golpear, llama a `Affliction.inflict(spell, slot)`. Una pasiva nueva es solo un `.tres` nuevo (`data/passives/yeti_freeze.tres`: `zerf`, `skip_if_was_frozen`).
- **`Affliction.inflict()`** es virtual. `Frozen.inflict` llama a `try_freeze_with_cooldown` con una sola tirada.
- **`Afflictions.cc_protected()`** protege con Life Shield (socket `life_shield`), fiel a `ccProtected`. También protege de la petrificación.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030u-b.md`).
- **Congelado:** el primer golpe del Yeti congela al Troll por 750 ticks.
- **Rotura:** un golpe sobre el Troll congelado rompe el hielo y, en el tick siguiente, sale `deshielo Troll1 150`, sin volver a congelar.
- **Intentos siguientes:** congela si y solo si c ≤ r (enfriamiento contra tirada).
- **Life Shield:** el Druid con escudo recibe 7 golpes y nunca se congela.
- **Determinismo:** `f132` (Q + Y) da `06b3d897` en fixed, stress y window. `quick` no cambia (`f149` y `f128` incluidos, R2). `rules_suite` PASS.
- **Playtest:** el Troll se ve azul hielo, el hielo se rompe y el Druid con escudo queda libre.

Deuda:
- Solo Life Shield cuenta como `shielded`. Faltan Skin of Stone, Ethereal Form, Fireform, Protective Swarm y Air Shield.
- No se evalúa `isApplicable` de la pasiva.
- El log no distingue «sin tirada» de «congela».

### F159 — El Dragon enreda al golpear (RFC-030, corte 030u-c)

**Piezas:**
- **`Vined`** (Affliction; `vined.tres`: bit 8, `coexists`, `cc_protects`, `pins`, `blocks_regeneration`):
  - cada golpe agrega su propio vencimiento;
  - la duración sale de `Affliction.cc_ticks`, la misma fórmula que `Frozen`, en float32;
  - `steer` deja la velocidad xz en cero;
  - las lianas son placeholder, en MIX.
- **`Afflictions.fixed()`** (`immobilized() or pins()`) es el único dueño de «no se mueve desde afuera». Lo usan `BodyNudge`, `unit_body` y `wizard_body`; empujes, tirones y catapulta lo respetan.
- **`Health.regenerate`** corta si `blocks_regeneration()`.
- **`dragon_vines.tres`** (`eniv`, `refuse_flying`) se suma a `MeleeOnHit.types`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030u-c.md`).
- **Enredo:** un solo golpe da `enredado Jabberocky3 durante 429 (n 1)`.
- **Mientras dura:** el Jabberocky queda quieto (desvío 0) y sin regenerar, aunque tenga una orden de moverse.
- **Al terminar:** camina 5 m en 60 ticks y regenera.
- **Determinismo:** `f132` (carriles Q, Y y V) da `18bfca66` en fixed, stress y window. `quick` no cambia (f121, f128, f149 y f155 incluidos). `rules_suite` da PASS.
- **Playtest:** PASS en los 4 puntos.

Deuda:
- Las lianas son de reserva, sin el modelo `vine`.
- No hay `healBlocked` ni `shieldBlocked`.
- La regeneración del port solo corre en reposo.

### F133 — Habilidades viejas al catálogo, primera tanda (RFC-030, corte 030v-a)

**Piezas:**
- **Life Shield (`hsba`), Run Away (`!nur`) y Divine Sight (`eesd`)** pasan a ser `AbilityEffect` en `scenes/world/units/abilities/` y se registran en `ability_catalog.tres`. Salen sus ramas del `match` de `active_ability.gd` (350 → 312 líneas).
- **R6:** `ActiveAbility.log_ability` (estático, apagado); solo `ai_match` lo enciende.
- **Caso `f133`** (`debug/f133_legacy_abilities.*`, `agent/tools/f133_expect.py`): las seis habilidades viejas sobre carriles, en la fila z-80 porque la cabaña `jhut` pisa z+15.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030v-a.md`). Sin playtest: es lógica pura.
- **Digest de `f133`:** se grabó antes de migrar (`bfca4703`) y da lo mismo después, en fixed, stress y window. Como el digest solo ve posiciones, también se comparó el log de habilidades, que es idéntico línea a línea.
- **Banco:** `quick` igual; `rules_suite` PASS; flows `f29_spit`, `f79_ability` y `pt120_play_dead` PASS.
- **Desvío:** las tres heredan el rechazo con `UsingAbility` encendido. Ninguna criatura que las tiene prepara habilidades, así que no cambia nada jugable.

Deuda:
- El flow `final_spit_melee` falla ya en HEAD (timeout en «golpe Earthfling a Druid»); no viene de este corte.
- Divine Sight desde la UI sigue dando «Blanco inválido» (F165).
- El comentario de `catalog` en `active_ability.gd:50` quedó viejo; se actualiza en 030v-b.

### F160 — Habilidades viejas al catálogo, segunda tanda (RFC-030, corte 030v-b)

**Piezas:**
- **Rockform (`dihk`)** pasa a `abilities/rockform.gd/.tscn`, con sus exports (salen de `ActiveAbility`).
- **Play Dead (`dedp`) y Stealth (`ivni`)** comparten `TimedStateAbility`: prende un flag de `UnitBody` (`body_setter`) y lo apaga en un tick de `MatchClock`. Cambian solo los valores del `.tscn`.
- **`ActiveAbility`** ya no tiene `match ability.tag` (312 → 212 líneas): un tag sin escena da «No implementado». Sale también `stealth_alpha`, que nadie leía.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-030v-b.md`). Sin playtest: es lógica pura.
- **`f133`** da `bfca4703` en fixed, stress y window, con el log de eventos idéntico al de antes de migrar. `f133_expect.py` PASS.
- **Banco:** `quick` igual (21 líneas); `rules_suite` PASS; flows `pt120_play_dead` y `f79_ability` PASS.
- Ninguna escena seteaba los exports borrados, así que no se pierde ningún valor.

Deuda:
- `body_setter` es un StringName con guarda `has_method`: un typo falla en silencio.

### F161 — El Brainiac y el Shrike aturden al blanco (RFC-030, corte 030w-b)

**Fuentes (sacengine, solo lectura):** `updateBrainiacProjectile` (state.d:22886-22936) y `updateShrikeProjectile` (22952-22989): la criatura o el mago golpeado recibe `stunWithCooldown(stunCooldownFrames)` y después, por el `goto case`, `dealRangedDamage` con `DamageMod.none`. Un edificio recibe solo el daño; el suelo, nada. **480 es el enfriamiento** del aturdimiento (`stunCooldownFrames = 8·updateFPS`, 8561-8568), no la duración: el Troll queda tumbado 72 ticks (el largo de su `Stunned`).

**Piezas:**
- **`StunImpact.target_only`** (`@export`, apagado por defecto): aturde solo al cuerpo golpeado si es criatura o mago. Apagado, queda la caminata de radio del Flummox (F120), sin cambios. La línea de enfriamiento del log ahora lleva `(cuadro N)`.
- **`impacts/stun_hit_impact.tscn`:** `StunImpact(target_only)` con un hijo `DirectImpact`. `ShotImpact.apply` corre primero el nodo y después los hijos: aturde y después daña, el orden de sacengine. Sin script nuevo.
- **`data/shots/bsba.tres` y `absh.tres`:** `ShotLook` (`hit_size` 0,45 y 0,6, `sweep`, `impact = stun_hit_impact.tscn`). Vuelan a 36 m/s según su SPEL (bsba 200 / alcance 90; absh 150 / alcance 35).
- **Caso `f161`** (`debug/f161_stun_shots.*`, `agent/tools/f161_expect.py`): Brainiac y Shrike quietos contra un Troll cada uno a 25 m, filas separadas 8 m, sin contacto.

**Comportamiento medido:** el primer impacto da `aturdido Troll durante 72` y en la línea siguiente el `directo` (180,0 el Brainiac, 135,0 el Shrike: monto · 0,9). Los impactos dentro de los 480 ticks dan `aturdir: … en enfriamiento (c)` con c = 480 − Δt; el primero después de 480 vuelve a aturdir.

**Desvíos del plan:**
- El plan dice Troll `ycrp`; ese tag es el Yeti. El Troll es `lort`.
- `trail_fx` provisorio (`heal`) para las dos estelas.

Deuda:
- El deslizamiento de 1,5 m del Brainiac pegado al suelo (revienta sin daño) y la estela original (`BrainiacEffect` 32 cuadros, `ShrikeEffect` 128).
- El disparo en el suelo (ni cuerpo ni edificio) no se mide en el caso.

### F176 — Exportador esqueletal y paridad (RFC-023, corte 023a)

**Piezas:**
- **`tools/export_skeletal.py`:** de los WAD del original a un `.glb` por modelo en `assets/original/models/` (versionado, LFS), con esqueleto, malla única y todos los clips SXSK; más `.events.json` e `index.json`.
- **Huesos auxiliares:** el original da a cada influencia su propio offset; glTF admite un solo bind. Se agregan hijos sin animar solo cuando las influencias discrepan más de 0,5 mm (eorc 282 huesos, jnwr 230).
- **`tools/export_skeletal_reference.py` y `tools/audit_skeletal.gd --ref=`:** paridad contra la exportación OBJ de sacengine.

**Cierre (2026-10-17).** Review CHANGES_REQUESTED (`reviews/REVIEW-RFC-023a.md`), corregida en una ronda. Sin playtest: es una herramienta.
- **Paridad:** 90 de 90 clips (eorc 51, jnwr 39) en los cuadros {0, mitad, último}. Error máximo 0,31 mm en eorc y 0,22 mm en jnwr.
- **Vértice sin normalizar:** jnwr tiene uno (pesos 1,006104), listado en `index.json` con su error previsto de 3,95 mm; medido 4,08 mm.

Deuda:
- 023g mide el costo de los huesos auxiliares con 150 cuerpos.
- 023b tiene que resetear el esqueleto al cambiar de clip: el import de glTF descarta pistas constantes iguales al reposo.

### F167 — Base del port sin caché (RFC-033, corte 033a)

**Piezas:**
- **LFS** para `.res` y `.exr` de `assets/original/`; `.gdignore` en `agent/out/` y `cache/look/anim_f37/`, así Godot deja de importar salidas de prueba y cuadros horneados.
- **`OriginalAssets`** (`scenes/data/original_assets.gd`): único dueño de las rutas de los assets originales; todavía sin consumidores.
- **Capturas base** con cámara fija: `bash agent/run_rfc033_shots.sh base|after`, en `agent/out/033/` (fuera de git).

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033a.md`). `quick` igual a la base. El `.gdignore` de `anim_f37` no rompe la animación: esos OBJ se leen con `FileAccess`, no con `ResourceLoader`.
- `.godot/imported` bajó de 10 GB a 5,8 GB; 4,2 GB quedaron movidos a `.godot/imported_orphans_033a/` hasta que el usuario decida borrarlos.

Deuda:
- Falta medir el ruido entre dos corridas iguales de las capturas 3D y de `fx_gallery` antes de usarlas como criterio numérico (lo hace 033b).
- Los 5,8 GB restantes de `.godot/imported` son huérfanos; se van solo con una purga total.

### F168 — Texturas originales como assets (RFC-033, corte 033b)

**Piezas:**
- **`tools/import_textures.py`** (+ `tools/sac_formats/textures.py`): 670 PNG únicos con el chroma aplicado en `assets/original/textures/` (73 MB, LFS) e `index.json` (modelo + etiqueta → PNG).
- **`OriginalMaterial`** (`scenes/world/original_material.gd`): único dueño de los materiales de modelos originales; `apply_to` sirve para los `.glb` de RFC-023.
- **Migrados a `assets/`:** `ObjMesh`, `ClipPosePlayer._baked_frame`, `wizard.gd`, `bake_clips`, `bake_bodies`, `audit_body_pose`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033b.md`).
- **Paridad de imagen:** 701 de 701 etiquetas idénticas a la tubería vieja (±1 de alfa en mips chicos de 3).
- **`quick`** igual a la base. **Capturas:** `body_gallery` 0 px; el resto tiene ruido de partículas sin semilla y quedó dentro del piso en las corridas 3 y 4.
- **Cambio de fidelidad:** el chroma ahora se aplica a todas las texturas SAXS, como en sacengine (`saxs.d:76-77`); antes faltaba en 19 etiquetas de 17 modelos con clips.

Deuda:
- Los `baked/bodies` de esos 17 modelos siguen sin chroma hasta re-hornear o RFC-023: el cuerpo quieto y el cuadro de clip se ven distintos.
- El importador lee de `cache/look`, no de los WAD; se arregla en 033h. No borrar `cache/` antes.
- Las capturas con partículas no tienen semilla: el criterio «HUD 0 px» no se puede cumplir así.

### F169 — Props y edificios como `.glb` (RFC-033, corte 033c)

**Piezas:**
- **`tools/import_props.py`:** 117 `.glb` en `assets/original/props/` (1,94 MB, LFS), un primitivo por etiqueta, sin texturas; los materiales salen de `OriginalMaterial`. Escritor glTF compartido en `tools/sac_formats/gltf_writer.py` (lo usa también `export_skeletal.py`).
- **`assets/original/models/sizes.json`:** medidas de 84 cuerpos y 117 props; el dedicado las lee sin mallas.
- **`BodyCatalog`:** una malla compartida por modelo de prop; ya no lee `cache/baked/props`.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033c.md`).
- **Paridad geométrica:** 117/117 a 0 mm (posición, uv y normal), con `force_disable_compression=true` en los `.import` (la compresión por defecto metía hasta 27,7 mm).
- **Banco:** `all` y `quick` iguales a la base en todos los modos (la marca CONTAMINATED es por otros Godot en paralelo; no toca el digest).
- **Capturas:** dentro del piso, salvo `body_gallery` con 0,18 % de píxeles distintos por malla indexada contra la vieja sin índices (mismos datos). Piso nuevo de `body_gallery`: ~1 700 px.

Deuda:
- `ensure_tangents=false` en los props; 022g reimporta con tangentes cuando haya normal maps.
- Para cerrar en 033i hace falta un `all` sin otros Godot en paralelo.
### F165 — Divine Sight fiel: el ojo (RFC-030, extra)

**Piezas:**
- **`abilities/divine_sight.gd`:** sin blanco ni preparación (SPEL `eesd` flags 0), así que funciona desde el botón. Lanza el ojo con `ShotSpawner.spawn_scene` (nuevo, replicable).
- **`divine_sight_eye.gd/.tscn`:** nace 2 m delante, sube 45 ticks a 4 m, vuela recto 500 ticks o fija al enemigo más cercano a 250 m y lo persigue (aceleración 3/tick); vive 45+1800 ticks. Maná 50, enfriamiento 25 s, `effectRange` 75 (sacengine `state.d` 13102-13109, 25159-25214). Solo lo simula el servidor.
- **`SideVision.update_vision()`:** único dueño de la grilla de visión (256×256 de 10 m). Como en sacengine con la niebla apagada, nadie la consume todavía.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-F165.md`).
- **Flow `f165_divine_sight`** desde la UI: 3/3 PASS, 36 asserts por corrida (maná, posición, persecución, visión, enfriamiento, fin).
- **`f133`** mismo digest (`bfca4703`); `quick` PASS.

Deuda:
- El ojo es un resplandor provisorio casi invisible; el sprite original `scri` (hoja 4×4, `Bloo.WAD`) se exporta en 033d.
- Busca blanco cada tick, no por la cola de IA; sin línea de vista.

### F166 — Rayo instantáneo de la Locust (RFC-030, corte 030w-d)

**Sacengine:** `locustShoot` (11527-11531) y `updateLocustShoot` (22992-23005): en el mismo cuadro del disparo, `collideRay` desde el origen hasta el alcance de `zbba` (50 m) con el filtro `id != atacante && isValidTarget` (primer cuerpo vivo de cualquier bando, o edificio); con blanco, `dealRangedDamage(DamageMod.none)`. Sin blanco, el extremo visual es 0,5 del alcance. `LocustProjectile` (23007-23022) es solo visual.

**Piezas:**
- **`data/shots/zbba.tres`:** `ShotLook` con `strike = locust_ray.tscn` y sin `impact`, así que el daño sale por `ShotImpact.land` (directo, 200 · resistencia directa del blanco).
- **`strikes/locust_ray.tscn`:** `RayStrike` de una ráfaga, `foes_only = false` (Health decide el fuego amigo), `beam = locust_ray`. Reusa el rayo del Gnome sin código nuevo.
- **`RayStrike.miss_fraction`** (`@export`, 1 por defecto; Locust 0,5): fracción del rayo que se dibuja cuando no encuentra nada. Solo visual; el Gnome y el Warmonger no cambian.
- **`data/fx/beams/locust_ray.tres`:** beam provisorio (atlas alfa `gmfl_a` en MIX, vida 0,267 s). Un rayo que frena en el suelo se dibuja completo; en sacengine el terreno cuenta como «none» y se dibuja a 0,5 (deuda del beam).
- **Banco:** `debug/f166_locust_ray.tscn`, `rules/f166_locust_ray.tres`, `agent/tools/f166_expect.py`, caso `f166` en `run_determinism.sh` (solo fixed en `quick`) y en `det_baseline.txt` (`5a402302`), `ai_match.camera_target_offset` (la cámara mira la fila, no el manantial) y `agent/run_f166.sh` + flow para las capturas.
- **Beam:** `locust_ray` usa el atlas alfa `gmfl_a` en `MIX` (nada aditivo sobre nieve); es provisorio.

**Caso:** Locust1 (50 % de vida) contra Troll1 con un Troll3 aliado en la línea: el rayo frena en el Troll3 y no le hace daño. Locust2 contra Troll2 en línea libre: 180 (200 · 0,9) en el tick del disparo. Un Troll y no un Druid porque la Locust vuela a 4 m del suelo y su rayo baja ~0,4 m por metro: a un Druid le pasa por arriba. La fila de Locust2 está corrida 15 m para librar la jhut (-15/-56).

Deuda:
- El flujo de partículas de sangre o escombro hacia la Locust (`LocustProjectile`) es un beam provisorio.
- El drenaje de 0,875 llegó con F164 (030w-e): Locust2 arranca al 50 % de vida para medirlo (`f166_expect.py`, `check_drain`).

### F170 — HUD, iconos, cursores y FX como assets (RFC-033, corte 033d)

**Piezas:**
- **`tools/import_ui.py`:** 270 PNG en `assets/original/ui/{icons,hud,cursors,xmenu}` y `assets/original/fx/` con `fx.json` (3,2 MB con los `.import`, LFS), lossless; mips solo en los atlas del catálogo y en `scri`.
- **Consumidores por `OriginalAssets`** (`UI_*_DIR`, `FX_CATALOG`): `HudIcons`, `FxAtlas`, `sprite_particles`, `teleport_rings`, `soul`.
- **Ojo de Divine Sight (F165):** el `glow` provisorio pasa al sprite original `scri` (hoja 4×4, 16 cuadros, 8 ticks por cuadro: `animationDelay` 4 × `updateAnimFactor` 2, sacengine `sacobject.d:3859-3861`).

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033d.md`).
- **Paridad:** 270 de 270 PNG idénticos byte a byte a `cache/look`; atlas iguales en todos los mips; las 701 texturas de 033b siguen iguales.
- **Capturas:** el panel del HUD da 0 px por regiones; el resto dentro del ruido conocido. Captura del ojo: `agent/out/f165/f165_rising.png`.
- **`quick`** igual a la base; flow `f165_divine_sight` PASS.

Deuda:
- El lector de TXTR está duplicado entre `export_particles.py` y `tools/sac_formats/` (033h).
- `import_ui.py` copia de `cache/look`, salvo `scri`, que sale del WAD (033h).

### F171 — Temas de dioses y cielo como assets (RFC-033, corte 033e)

**Piezas:**
- **`tools/import_themes.py`:** los 5 temas en `assets/original/themes/<god>/` (tileset, cielo, sol y `envi.tres` con `GodEnvi`), 2,5 MB.
- **`GodTheme.resolved()`** (antes `with_cache()`): el directorio se deriva del dios con `OriginalAssets.theme_dir`; ningún `.tres` escribe rutas.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033e.md`).
- **Paridad:** 35 imágenes idénticas a la caché por byte y mip; colores, niebla y sol iguales a `theme.json`. El cielo original no cambia.
- **Capturas:** 4 biomas dentro de ±5 % del piso; pyro +22–25 % por el cielo que rota con el tiempo de captura (dos `after` iguales difieren 74 k px).
- **`quick`** igual a la base.
- **Fuera de partida** (escenas `debug/*` y editor), el terreno por defecto usa el tema de James y ahora tiene el borde del vacío de ENVI, que antes faltaba; en partida manda `ThemeApplier`.

Deuda:
- `sky.gd` y `terrain.gd` concatenan `THEMES_DIR` en vez de pasar por `OriginalAssets` (033f).
- El arnés de capturas no congela el tiempo del cielo (033f).
- 4 campos de `GodEnvi` sin lector; se borran si 033f/033g no los usan.
- `import_themes.py` copia de la caché, no del WAD (033h).

### F172 — Terreno y mapa de High Noon como assets (RFC-033, corte 033f)

**Piezas:**
- **`tools/import_map.py` + `tools/import_terrain.gd`:** `assets/original/maps/high_noon/` con `terrain.res` (`MapTerrainData`, sin texturas; lo lee el dedicado), `tiles.png`, `light.png`, `ntts.json` y `widgets.json`.
- **`GrassHeight.from_terrain`:** la altura del pasto se calcula al cargar (no se guarda `height.exr`); el relleno de huecos es un BFS por anillos (166 s → 1,4 s). `bake_grass_height.gd` se borró.
- **`Sky.set_time()`:** el arnés de capturas congela el cielo (`rfc033_view.freeze_sky()`).
- **Deudas de 033e cerradas:** rutas del cielo y del terreno por `OriginalAssets`; 4 campos de `GodEnvi` sin lector borrados.

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033f.md`).
- **Paridad:** 0 fallos: 20 586 vértices, normales e índices iguales al `.bin`; texturas y datos del mapa iguales; altura del pasto con 0 texels distintos.
- **Banco:** `all` (s7 4915c884, f139 5ade9305, s1_trivial e076abe1, s7_npcs 7179b17d) y `quick` iguales a la base en todos los modos; `rules_suite` y `f131 --lanes` PASS.
- **Capturas:** con el cielo congelado, el piso de los biomas baja de 20–150 k a 4–22 k px; el suelo queda dentro del piso de la base salvo charnel (466 contra 409 px).

Deuda:
- `Terrain.data` cae en silencio a High Noon si no se asigna (`terrain.gd:102`); conviene limitarlo al editor y a las probes, con aviso, antes de un segundo mapa.
- `agent/tools/f1*_expect.py` todavía leen `cache/high_noon_terrain.bin` y `cache/data` (033h).
### Acercamiento cuerpo a cuerpo (causa de final_spit_melee)

**Síntoma.** `agent/flows/final_spit_melee.json` fallaba desde el primer commit: el Earthfling escupía a 2 m y moría sin golpear al Druid.

**Causa.** `UnitBody` frenaba al primer roce (`MeleeAttack.can_start`): el Druid quedaba a gap 0,93 m, y `RangedAttack.prefers` solo deja pegar a un tirador con el blanco a gap ≤ 0,5 (`rangedMeleeAttackDistance`, `state.d:8752`). Con el blanco ya dentro de su caja de melee, sacengine sigue acercando al atacante (`attack`, `state.d:12857-12862`): `moveWithinRange(movementPosition, 0.8·targetDistance)`, con `targetDistance` el desplazamiento del centro de su caja de melee (1,3·`reach`) y `movementPosition` el borde del blanco.

**Regla en el port.** `MeleeAttack.close_in(target, pace, delta)` (`close_in_factor` 0,8, `@export`): con el blanco en alcance camina hasta `foe_reach + 0,8·forward_factor·reach` del centro del blanco, sin pasarse en el último paso, y nunca por dentro de `BodySeparation.rest_distance(a, b)` (donde el segundo paso de `positionAfterCollision` deja dos cajas en reposo, a medio `blockSlack`: si no, el empuje lo devolvía cada tick). `UnitBody._attack` suma esa velocidad (pace 0 con `Afflictions.fixed()`; `holds()` ya corta antes). `MeleeAttack.box_half(factor)` es el dueño del ancho de la caja de melee (`WIDTH_SCALE` del Druid) para `in_reach`; la caja solo se ensancha: su desplazamiento hacia delante no (`sacobject.d:446-476`), por eso `close_in` no lo aplica.

**Digests regrabados** (`agent/det_baseline.txt`; mismo digest en fixed, stress y window; con el knob en 1000 la base de main se reproduce exacta). Primera línea distinta, siempre un golpe o una posición que depende del acercamiento:

| caso | primera línea distinta (antes -> ahora) |
|---|---|
| s7 | t209 `hp Druid1` 746.67 -> 746.65 (daño del golpe del Trogg por otro `facing`) |
| f139 | los golpes del Cog1 pasan del t37 al t36 |
| f121 | t251 `hp Druid2 385.17` -> t252 `hp Trogg1 793.33` (otro golpe antes) |
| f130 | t600 `pos StormGiant1` 1255.8,10.5,1284.4 -> 1257.5,10.6,1284.7 |
| f131 | t370 `hp Netherfiend1` 2573.36 -> 2573.35 |
| f132 | t108 `died Dragon1` 1325.0 -> 1326.3 |

`s7_npcs` (t672 `hp Farmer4` 449.15 -> 449.34) y `s1_trivial` (t2241 `struck Taurock3 -> Wizard2` 42.16 -> 44.60) también cambian pero no están en la base.

**Medición** (`MeleeAttack.log_gap`, apagado en el producto; lo enciende `ai_match` y `debug/ability_spit.gd`; línea `melee_gap A->B d= gap= vx= vz= tick=…`; `agent/tools/melee_gap_expect.py LOG…`):
- `final_spit_melee` (Druid contra Earthfling, 1 contra 1): gap de caja mínimo 0,100 m (el reposo de `BodySeparation`), 0 cambios de signo de la velocidad de acercamiento, se asienta en el piso de `BodySeparation` (el objetivo de sacengine, d = 1,05 m, queda por dentro). PASS.
- `s7` (3 contra 3): el gap de caja baja a -0,067 (Druid) y -0,072 (Trogg) y la velocidad de acercamiento cambia de signo cientos de veces por ventana (524 y 759 como máximo). No viene de `close_in`: con el knob en 1000 (sin acercamiento) da -0,061 / -0,108 y 409 / 682 cambios. Es el empuje de terceros cuerpos de `BodySeparation` (5 m/s, 0,08 m por tick) en la melé; el comando de `close_in` ahí es cero. Queda anotado, sin tocar `BodySeparation` (su regla es la de sacengine).

### F177 — Temblor en la melé de grupo (plan 030w, corte 030w-a): medición, sin cambio de juego

**Estado.** No se activó ni A ni B y **se quitaron del código** (la receta queda abajo). Ningún digest cambió. Queda `BodySeparation.log_push` (apagado; `ai_match --log-push`), igual que `MeleeAttack.log_gap`, el caso `f177` (`debug/f177_melee_group.tscn`: 3 Druid contra 3 Trogg y un cuarto Trogg que aprieta) y la réplica `agent/tools/melee_gap_expect.py` con el criterio **superposición nunca menor a -0,05 m y amplitud pico a pico de `d` de 0,03 m o menos por ventana de contacto** (medida desde el primer tick con la caja a la distancia de reposo).

**Medición del estado actual (no cumple).**
- `f177`: piso de caja 0,017 (Druid) y 0,100 (Trogg); amplitud máxima 0,166 m (Druid2) y 0,083 m (Trogg2). Superposición: cumple. Amplitud: no cumple.
- `s7`: piso de caja -0,067 (Druid) y -0,072 (Trogg); amplitud máxima 0,445 m y 0,412 m. Ninguno de los dos criterios cumple. La amplitud incluye la deriva lenta de pares empujados a lo largo de cientos de ticks, no solo el temblor de 2 ticks.
- Umbral sin ajustar.

**Receta de B (fiel parcial, dueño `MeleeAttack`).** `moving_pace_factor` (`@export`, 0,5) y `static var melee_moving`: `close_in` multiplica la marcha por 0,5 hasta el primer cuadro de ataque del golpe (`_next_tick == 0`; sacengine `meleeMoving`, `state.d:8725-8731`, `14668-14671`) y después da cero (`meleeAttacking`, `14411-14412`). Le falta para ser fiel: la **aceleración y la desaceleración** en el suelo también a la mitad (`14668-14671` escala velocidad y aceleración, el port fija la velocidad), el `facing` (el cuerpo gira mientras camina) y un estado de velocidad en `UnitBody` (sacengine frena por desaceleración, no corta en seco), que no se pudo agregar porque `unit_body.gd` está en el tope de 1040 líneas.

**Receta de A (desvío, dueño `BodySeparation`).** `static var share_push` y `share_of`: `_second_pass` multiplica el solapamiento de cada obstáculo que también se empuja fuera de este cuerpo (no está `Afflictions.fixed()` y no lo exime `_passes`) por `1 / (k + 1)`, con k los obstáculos que lo empujan en ese tick. Con k = 1 es 0,5 y el par se separa exacto en un tick. El 0,5 fijo del plan no amortigua una fila de cuerpos (valor propio -1 del modo alterno); `1 / (k + 1)` sí en teoría. El reposo (`rest_distance`) no cambia.

**Tabla (fixed, semilla 7; piso de caja en m / máximo de cambios de signo de la métrica vieja, Druid y Trogg):**

| caso | A off, B off | A off, B on | A on, B off | A on, B on |
|---|---|---|---|---|
| f177 | 0,017 / 414 y 0,100 / 16 | 0,017 / 386 y 0,100 / 104 | 0,060 / 21 y 0,058 / 30 | 0,060 / 21 y 0,057 / 30 |
| s7 | -0,067 / 524 y -0,072 / 759 | -0,277 / 479 y -0,095 / 755 | -0,002 / 675 y -0,006 / 705 | -0,091 / 677 y -0,033 / 705 |

**Atribución** (`--log-push` sobre s7): una fila de cuerpos **quietos** (`wanted = 0`: Trogg1, Trogg4, Druid1, Druid4) con solapamiento permanente de 0,02-0,04 m que otros cuerpos mantienen apretada; cada tick todos se llevan su empuje de la foto del principio del cuadro y oscilan en un ciclo de 2 ticks de 0,02 m. En `f177` el tercer cuerpo es el Trogg4, que empuja con marcha entera. B no ayuda y en s7 empeora el piso (-0,277).

**Deuda.**
- La aritmética de la separación es la misma que la de sacengine (`positionAfterCollision`, empuje entero por cuerpo sobre la foto del cuadro); no se midió que el original tiemble igual. Medir 3 contra 3 en el original con REA.
- (Hecho, ver «Medición con make_way apagado».) El original no se pudo medir (no corre en esta máquina); queda como deducción de sacengine.
- Si se reabre: A con `1 / (k + 1)` o un empuje con memoria; ambos cambian los digests de todo caso con dos cuerpos en contacto.

**Medición con `make_way` apagado (2026-10-17).** Interruptor de debug `ai_match --no-make-way` (`BodySeparation.make_way = false`; apagado por defecto, digests sin cambio: s7 `c5a5755a`). Mismas semillas y logs (`log_gap`), `melee_gap_expect.py` y cambios de sentido de `d` por ventana (umbral 2 mm):

| caso | make_way | caja mínima (m) | amplitud pico a pico máx. (m) | cambios de sentido por ventana (máx.) |
|---|---|---|---|---|
| f177 | on | 0,017 | 0,166 (Druid) / 0,083 (Trogg) | 411 |
| f177 | off | 0,017 | 0,166 / 0,105 | 568 |
| s7 | on | -0,072 | 0,445 / 0,412 | 767 |
| s7 | off | -0,067 | 0,157 / 0,245 | 750 |

**Decisión.** Sin `make_way` el temblor **no baja**: los cambios de sentido y el temblor local (desvío de `d` respecto de sus vecinos en 2 ticks, 0,16-0,21 m) quedan iguales, y el piso de caja también. Lo único que baja es la amplitud de s7 (0,445 a 0,245), que es deriva lenta de pares empujados, no temblor. La causa es la aritmética heredada de sacengine (empuje entero sobre la foto del cuadro), no el desvío del port. No se toca la separación. Criterio de `melee_gap_expect.py` aflojado a lo que admite el original: superposición de caja >= -0,1 m y amplitud <= 0,05 m. Con ese criterio: la superposición **cumple** en `s7` y `f177`; la amplitud **no cumple** (f177: 2 ventanas; s7: 16), porque incluye la deriva de pares empujados durante cientos de ticks. Ese incumplimiento queda como medición abierta del caso, sin arreglo propuesto: separar deriva de temblor necesitaría medir en el original.

### F173 — Datos de juego como assets (RFC-033, corte 033g)

**Piezas:**
- **`tools/export_stats.py --out assets/original/data`:** los 6 JSON (creatures, spells, abilities, wizards, books, buildings) versionados; con `--out` no toca la caché.
- **Lectores por `OriginalAssets.DATA_DIR`:** `GameData`, `MapBuilding` (`ai_perception`), `debug/body_gallery.gd`, `tools/audit_body_pose.gd` y las réplicas `agent/tools/f1*_expect.py` (f129, f155 y f156 leen medidas de `models/sizes.json`).

**Cierre (2026-10-17).** Review APPROVE (`reviews/REVIEW-RFC-033g.md`). **Hito: la simulación ya no lee `cache/`.**
- **Paridad:** los 6 JSON iguales byte a byte a `cache/data`.
- **Banco:** `all fixed fixed2 stress window` sin CONTAMINATED (s7 `c5a5755a`, s7_npcs `4386b384`, s1_trivial `60fbf6d5`, f139 `4750f4d1`) y `quick` 21/21; `rules_suite` PASS.
- **Con `cache/` renombrada:** `ai_match` headless da los mismos digests de s7 y s7_npcs, sin avisos.

Deuda:
- `anim_mesh_clips_f37.json` sigue en `cache/data`; sus lectores son solo del cliente y se van con RFC-023 (023h).

### F174 — Refs de prueba, importadores desde WAD y tools (RFC-033, corte 033h)

**Piezas:**
- **Importadores desde la instalación:** `import_textures`, `import_props`, `import_ui`, `import_themes` e `import_map` leen WAD y `.scp` con un lector único (`tools/sac_formats/`) y aceptan `--out`. `tools/check_original_assets.sh` regenera todo a una carpeta temporal y compara contra `assets/original/` (`ASSETS PARITY PASS`).
- **Refs de tick** en `agent/fixtures/sacengine/`; los checks de debug apuntan ahí.
- **`run_determinism.sh`:** `fixed` siempre se corre y el veredicto pide al menos 2 modos frescos; un modo solo da «sin comparación».
- **Iconos:** `OriginalAssets.icon_file(tag)` (mayúscula → `_` + minúscula). Life Shield, Protector, Halo of Earth y Spikey Death ya no comparten archivo.
- **`Terrain.data`** solo cae a High Noon en el editor, con aviso; en partida, sin `data`, da error.
- **Borrados:** `export_icons.py`, `export_high_noon_*.py`, `wizard.gd` (`wizard_preview` usa `BodyLibrary`) y la auditoría vieja.

**Cierre (2026-10-17).** Review CHANGES_REQUESTED (`reviews/REVIEW-RFC-033h.md`), corregida en una ronda.
- **Paridad:** regenerado desde WAD, idéntico a lo versionado; único nuevo, `ui/icons/tum@.png`.
- **Banco:** `all` (s7 `c5a5755a`, s7_npcs `4386b384`, s1_trivial `60fbf6d5`, f139 `4750f4d1`) y `quick` iguales a la base; `rules_suite` 98 PASS; 15/15 `--lanes`; `f165` PASS.
- **Lo único que sigue leyendo `cache/`:** cuerpos y clips del cliente (`body_catalog`, `structure_body`, `clip_pose_player`), que se van con RFC-023.

Deuda:
- `models/sizes.json` sale del horneado de cuerpos, no del WAD (RFC-023).
### F162 — Ondas del Spitfire y del Gargoyle (RFC-030, corte 030w-c)

**Piezas:**
- **`GrowingWave`** (antes `FrostWave`, `git mv`): dueño único del radio `radius_at`, de la caminata con `SplashDamage.bodies_within`, del «una vez por vuelo», del filtro de bando, de directo contra salpicadura (con `shot.mods`) y del log `onda …`. Knobs: `final_radius`, `building_groups`; `static var log_touches`.
- **`WaveTouch`** (base) y sus hijos en la escena de la onda: `before_hit`, `after_hit` y `settled` (con `direct` para el orden de sacengine).
  - **`FreezeTouch`:** lo de F149 (`zerf`, lista de congelar al final del cuadro).
  - **`IgniteTouch`:** `Burning.ignite(0, 30)`; el blanco, golpe y después fuego; los demás, fuego y después salpicadura. `@export` `fire_ticks`, `fire_damage`, `fire_fx`.
- **Escenas:** `frost_wave.tscn` (`GrowingWave` 7,5 + `FreezeTouch`), `spitfire_wave.tscn` (7,5 + `IgniteTouch`) y `gargoyle_wave.tscn` (6,0, sin hijos).
- **`ShotLook`:** `data/shots/fhba.tres` (`in_flight`, `collides = false`, `ignites = true`) y `ehba.tres`. Trail provisorio: `fire` (cada 2) y `rock_trail`.

**Fidelidad (sacengine `updateSpitfireProjectile` 23025-23069, `updateGargoyleProjectile` 23079-23113):**
- **Fuego del Spitfire:** 0 de daño en 31 actualizaciones. Lo que pesa es el `DamageMod.ignite` del golpe (el aceite ×2, F155).
- **Gargoyle:** sin fuego ni `ignite`.
- **Alcance:** la onda vuela su alcance entero (34 y 40 m) sin chocar, también más allá del blanco.

**Cierre (2026-10-17).**
- **Paso 0:** `f149` da `bf28b3fd` antes y después del refactor; `f149_expect.py` PASS.
- **Caso `f162_waves`:** `f162_expect.py` PASS (radio de cada `toca`, daño directo y de salpicadura, aliado 0, una vez por cuerpo, `fuego` en W1 y W2 durante 31 actualizaciones). Digest `f3e46a91` igual en fixed, stress y window.
- **Banco:** `quick` con las 22 líneas de la base OK; `rules_suite --fixed-fps 60` PASS.
- **Carriles:** la fila del Gargoyle del plan (z −66) deja una choza de la aldea al final del vuelo de 40 m y la onda la tocaba; se movió a z −36 (validado con `--lanes` a lo largo de todo el vuelo).
- **Capturas:** `agent/out/f162/` (`f162_spitfire.json`, `f162_gargoyle.json`, observador `agent/harness/f162_watch.gd`).

Deuda:
- ~~`Burning.ignite` descarta un edificio con daño 0~~: saldada (F162b, abajo).
- **Trail:** el puff no escala con el radio de la onda; los FX propios de `fhba` (`firy`) y `ehba` (`rock`) quedan para cuando haya tiempo de exportarlos.
- **Orden fuego/golpe:** no se ve en el log (el `fuego` se imprime al terminar); lo cubre el código, no la réplica.

### F164 — Drenaje de vida (RFC-030, corte 030w-e)

**Sacengine:** `dealDamage` (8933-8946, la línea 8940 llama) calcula el daño que el blanco toma de verdad (con el tope de la vida que le queda) y llama a `healFromDrain` (8834-8840): un atacante vivo que es criatura cura `daño · drain` al instante, con el tope del máximo (`heal`, 8815-8817). Sacengine drena todo el daño de la criatura, también el de un disparo a distancia. Solo contra cuerpos móviles; un edificio no alimenta el drenaje. Charnel 0,5 (Scythe, Fallen, Blight, Necryl, Hellmouth, Styx, Deadeye, Netherfiend, Abomination, Gangrel, Astaroth) y Locust 0,875.

**Piezas:**
- **`LifeDrain`** (`scenes/world/units/life_drain.gd`, `static func feed(attacker, target, taken)`): la regla única. Solo actúa con `taken > 0`, un `UnitBody` vivo con `type.drain > 0`, `attacker != target` y un blanco `unit` o `wizard` (nunca `structure`). El `drain` sale de `CreatureType.drain` (Resource, sin mutar). `static var log_drain` (banco, apagado en el producto): `drena A de B daño (escala) -> vida v ganada g (tick t)`, solo si ganó algo.
- **`Health.damage()`** devuelve el daño tomado (`float`, con el tope de la vida que queda), como `damage_typed`. Lo que emite `hit` no cambia.
- **Tres llamadores, sin lógica propia:** `MeleeAttack._land`, la rama directa de `ShotImpact.land` (Fallen `dkba`, Locust `zbba` por `RayStrike`) y `DirectImpact._affect`. El tirador sale de `shooter_path` del holder (`ShotImpact.shooter_of`).
- **Banco:** `debug/f164_drain.tscn`, `rules/f164_drain.tres`, `agent/tools/f164_expect.py`, caso `f164` en `run_determinism.sh` (solo fixed en `quick`) y en `det_baseline.txt` (`97cd4399`); `f166_expect.py` suma `check_drain` y Locust2 arranca al 50 % de vida.

**Caso:** Scythe1 al 50 % pega a Troll1: cada golpe con cantidad > 0 le sube 0,5 · cantidad, con el tope de 540 (los golpes con la vida ya en el tope no dejan línea). Scythe2 con la vida llena no cura. Fallen1 al 50 % cura 56,25 por disparo (0,5 · 112,5). En `f166`, Locust2 cura 157,5 (0,875 · 180) y después queda al tope de 450; Locust1, cuyo rayo frena en un aliado sin daño, no cura. Filas corridas al oeste (K2/T2 en -45/-42, F1/T3 en -60/-40) para librar la jhut y un jcc2 (validado con `--lanes`).

**Cierre (2026-10-17).**
- **Digests:** `f164` `97cd4399` igual en fixed, stress y window. La base no cambió: el audit mira la vida de los blancos y no la del atacante, y ningún caso de `quick` hace que la cura cambie un resultado. `f156`, `f133` y `f166` dan los mismos digests (no hubo nada que regrabar); `f166` con Locust2 al 50 % también.
- **Banco:** `quick` con las 24 líneas previas de la base OK; `rules_suite --fixed-fps 60` PASS. Los avisos CONTAMINATED de algunas corridas vienen de otros Godot de la máquina, no de diferencias de digest.
- **Sin capturas:** el drenaje no tiene efecto visual en este corte (la barra de vida del atacante sube; no hay FX).

Deuda (F164b): hecha salvo `Burning`; ver F164b.

### F164b — Drenaje de la salpicadura, del veneno y de los guardianes (RFC-030, corte 030w-e, deuda de F164)

**Sacengine:** la salpicadura y el veneno llegan al mismo `dealDamage` de criatura que el golpe directo (`dealDamage(objeto, daño, radio, atacante, …)` 9053-9057 -> 8895-8913 -> 8933-8947, que llama a `healFromDrain` en 8940): cada cuerpo que la ráfaga daña de verdad alimenta al lanzador con lo que tomó (`dealDamageAt`, 9075-9089). El veneno cura dos veces: al estallar, `healFromDrain(atacante, rangedAttack.amount)` con el monto entero del SPEL sin mirar lo que toma el blanco (23523, 24360, 24879), y en cada tick de la dosis, porque `updatePoison` llama a `dealPoisonDamage` con el atacante (23585, 9415-9419) y eso entra por 8933 con lo que el tick tomó; la infección pasa el atacante, así que el Necryl también se cura de los contagiados.

**Deflector (la deuda de F164):** el escudo no es del Protector sino la guardia de un edificio (`GuardPost`). En sacengine `dealDamage(edificio, …, atacante)` manda el golpe a `damageGuardians` (9193-9195, 9119-9141), que llama a la sobrecarga de criatura (8933) en cada guardián: el original **sí drena**, con el daño que tomaron los guardianes (suma), no con el del edificio. Sin guardián válido el edificio lo toma y no drena (9193-9207).

**Piezas:**
- `LifeDrain` sigue siendo el único dueño (`feed`). Un blanco `structure` alimenta solo si `Health.deflected_last` (nuevo: el último golpe lo tomaron los que desvían). `Health.damage` ahora devuelve el daño de los guardianes cuando desvía (antes 0).
- `SplashDamage.hurt`/`deal` reciben `attacker` y llaman a `LifeDrain.feed`; lo pasan `SplashImpact`, `SpikeImpact` (+ `SpikeWave.attacker_path`) y `GrowingWave`. Los hechizos de mago no lo pasan (sin drenaje).
- `PoisonImpact._drain` se borra: llama a `LifeDrain.feed(shooter, target, amount)` y también en la rama de edificio. `DamageOverTime.attacker_path` (ruta absoluta del lanzador, vacía = nadie) alimenta cada tick; `Poisoning.dose`/`dose_body` y la infección lo pasan.
- Grep: ninguna otra parte cura por drenaje (`Health.heal` solo lo llaman `LifeDrain`, regeneración, curas y el guardián).

**Banco:** `f164_drain` suma la fila z-100 (Abomination1 `ctug` al 50 % lanza `tugt` a Troll4 con Troll5 al lado): `f164_expect.py` rehace cada cuerpo de la ráfaga (425·(1-d/10)·0,9, d del log) y la cura 0,5·tomado, el edificio no cura. `f122_expect.py` suma `check_drain`: ráfaga con el monto entero, ticks de Deadeye/Hellmouth y la secuencia exacta del Necryl contra su simulación (hasta que muere). `rules_suite` suma `guard_drain` (guardianes drenan, edificio sin guardia no, `damage` informa).

**Cierre:** `rules_suite --fixed-fps 60` PASS (con `guard_drain`); `f164_expect`, `f122_expect`, `f166_expect` y `f156_expect` PASS. `quick`: todo igual a la base salvo dos, regrabados. `f139` (`4750f4d1` -> `e3ded3af`): la primera línea distinta del `.events` es `40 hp Necryl1 101.60` -> `101.85`, o sea el Necryl se cura con su veneno (lo que antes no hacía). `f164` (`97cd4399` -> `d2346dda`): filas nuevas de Abomination y Troll4/Troll5. Solo `fixed` en estos dos; sin capturas (lógica pura).

Deuda: ~~`Burning` (el fuego con atacante) todavía no drena~~: saldada (F164c, abajo).

### F162b / F164c — Fuego sobre edificios y drenaje del fuego (RFC-030, deudas de F162 y F164b)

**Sacengine:** `setAblaze` (27670-27672) solo agrega un `Fire` con el atacante; `updateFire` (15112-15130) lo corre una vez por cuadro: con daño por cuadro llama a `dealFireDamage` (9421-9427) y esa a `dealRangedDamage`/`dealSpellDamage` con el atacante, que entran por el mismo `dealDamage` que drena (8940); **sin daño y sobre un edificio hace `return false` ya en la primera actualización** (15117-15118), antes de daño, maná y partículas. O sea, el «prender» del edificio con 0 de daño (la onda del Spitfire 23042, el Bombard 24521-24527) no es visual ni daño por tick: el efecto existe una actualización y se va. Lo que prende de verdad (`igniteBuilding`, daño de fuego por cuadro, apagado a su tiempo) es solo `setAblazeWithManaDrain` (27673, el rayo del Tickferno), y eso el port ya lo hacía (Burning con daño sobre edificio).

**Piezas (sin dueño nuevo):**
- `Burning.ignite`: un `structure` ya no se descarta con daño 0; `Burning.step` lo termina en su primera actualización sin tocar `Health` (`updates = 1`). Parámetro nuevo `attacker: Node` (al final, nulo = nadie) que guarda `attacker_path` como el veneno de F164b; el tick lo alimenta `DamageOverTime.step` -> `LifeDrain.feed` (ya existía, el único dueño).
- Llamadores: `IgniteTouch` y `BurnImpact` pasan el tirador (`ShotImpact.shooter_of`). `Oiled` no (sin atacante en el original).
- Contenido: ningún lanzador de fuego drena hoy (Tickferno `craf`, Pyromaniac `plff`, Bombard `wlcf`, Spitfire `sohf`: drain 0), así que el drenaje del fuego no se ve en ningún caso de banco; lo cubre `rules_suite` `guard_fire` (Scythe al 50 % que prende a un Troll: cura 0,5 · lo que tomó el tick; sin atacante no cura; el fuego de un edificio sin daño termina en su primera actualización y no cura).

**Banco:** `debug/rules/f162_waves.tres` suma la fila z-56 (Spitfire2 -45 ataca a Trogg5 -24; su onda vuela hasta la `jhut` de la aldea en (-14,7; -56,2) y la toca). `f162_expect.py`: tres ondas, `fuego` de Trogg1/2/5, y el edificio con `fuego … total 0.0 en 1 actualizaciones`, tocado solo por la onda de P3 (`--lanes` valida la fila 5; el suelo se omite si faltan los caches). `f123_expect.py` suma el veredicto de drenaje (ningún `drena` de Tickferno/Pyromaniac/Bombard).

### F163 — Escudo de fuego del Phoenix (RFC-030, corte 030w-f)

**Piezas:**
- **`FireShield`** (`scenes/world/units/fire_shield.gd` + `fire_shield.tscn`, hijo de `unit.tscn` como `MeleeOnHit`): dueño único del escudo del Phoenix (`rifl`). Solo actúa si `CreatureType.passive_on_damage == passive_tag` y en el servidor; los demás cuerpos lo llevan y lo ignoran. `unit_body.gd` no cambió (1040 líneas).
  - Cada tick: caja propia (`BodySeparation.box_of`) ×1,5 desde el centro contra la caja de cada cuerpo vivo de los grupos `unit` y `wizard` (menos él). Al que no es aliado (`SideRelations.stance`) le da `Health.damage_typed(mrff.amount/60, DIRECT_SPELL, slot, false, pierce_shield = true)`: reusa la regla de daño, no la duplica.
  - Maná: el costo sale del SPEL `rifl` (0); si fuera > 0 se exige y se drena con `ManaPool.drain`.
  - `@export`: `passive_tag`, `spell`, `box_scale`, y de look `fire_fx`, `fire_every_ticks`, `fire_height_m`. `static var log_shield` (banco).

**Fidelidad (sacengine `runPhoenixPassive` 13899-13919, `runPassive` 13921-13931, `ignite` 17254-17261, `dealFireDamage` 9421-9427, `canShield` 218-225):**
- 250/60 por cuadro como hechizo directo, atravesando Life Shield/Rockform; aliado y edificios no.
- **R6 medido:** la caja del Phoenix mide ±5,67 m de ancho y 15,2 m de alto; ×1,5 baja 3,8 m bajo sus pies. Un Druid en el suelo a 8 m (Phoenix en el suelo del caso) se quema; con el vuelo a 4,5 m su cabeza (1,9 m) aún entra con 1,2 m de margen.
- **Divergencias declaradas:** el look es de reserva (`fire` sobre el quemado cada 5 cuadros, sin las partículas propias del escudo); un cuerpo no apuntable (sigilo, cautivo) ni es escudo ni blanco.

**Cierre (2026-10-17).**
- **Caso `f163_phoenix_shield`:** `f163_expect.py` PASS (quién quema a quién, caja ×1,5, 250/60·resistencia ±0,001, un quema por cuadro de contacto, aliados 0, P3 y P4 sin líneas, maná no baja, Druid1 quemado 193 cuadros hasta morir). Digest `83189d94` igual en fixed, stress y window.
- **Carriles (desvío del plan):** P3 en −36/−90,5 (no −33/−80: ahí quedaba dentro de la caja de P2, su enemigo, y se quemaba) y P4 en +10/−80 (la fila z −60 caía junto a una choza); se agregó D1 (Druid, slot 2, −22/−80) para medir R6. Validados con `--lanes`. Los cuerpos se empujan unos metros por `BodySeparation`; la réplica lee las posiciones de cada línea.
- **Banco:** `quick` con las 25 líneas de la base OK, incluida `f125` (no cambió: su Phoenix nunca toca un cuerpo; no se regraba nada); `rules_suite --fixed-fps 60` PASS. Los avisos CONTAMINATED de las corridas fixed/stress son de otros agentes con Godot en la máquina; los digests de los 3 modos coinciden.
- **Capturas:** `agent/out/f163/shield_a.png`, `shield_b.png`, `shield_c.png` (`agent/flows/f163_phoenix_shield.json`, observador `agent/harness/f163_watch.gd`, `agent/run_f163.sh`).

Deuda:
- Las partículas propias del escudo (`spawnPhoenixShieldParticles`, tasa 3) y las 3 de fuego por quemado no existen: el puff de `fire` es chico sobre la nieve.
- `canShield` se aproxima con `is_targetable()` y no estar muerto (no se distingue `REVIVING`/fantasma).

### RFC-023 023d–023f — Mago, doctor y cautivo, fantasma, cadáver y voladoras con esqueleto (cierre 2026-10-17)

- **023d:** 15 magos con `BodyRig` (paridad de 70 clips ≤ 0,37 mm), reposo `stance1`, `HandFx` y `cast_fx_shown` replicado (review APPROVE). El exportador escribe identidad para cuaterniones nulos (dcak, ecak, fcak, stmp, eber regenerados).
- **023e:** doctor y cautivo con rig (rise, held, thrash), doctor en `stance1`; trabajos con roles prestados.
- **023f:** cadáver con clip `death`/`fly_death` y desvanecido de 1 s (`Corpse.fade_s`, pedido del usuario; el original desaparece de golpe a los 2,5 s), fantasma por instancia (`SeeThroughLook`), roles `hover` y `fly_death`.
- **Verificación de main sin agentes:** import sin errores, `quick` 27/27, `rules_suite` PASS. Playtest (Haiku, `agent/out/pt023def/`): fantasma, cadáver y desvanecido, f165 PASS.

Deuda aceptada por el usuario:
- La partícula de casteo de `HandFx` no cae sobre las manos (un brillo corrido del puño, otro en el aire). «No es crítico, es solo un FX.»
- Sin captura del `thrash` del cautivo ni de las voladoras en hover; el doctor se ve completo pero la escena de captura no tiene suelo.
- El clip de muerte puede durar más que la caída de 0,91 s; el alma sale a los 0,91 s como antes.

### RFC-023 023g — Rendimiento del esqueleto (cierre 2026-10-17)

- **Huesos mínimos (decisión del usuario: «no me preocupa tener las animaciones al detalle»):** el exportador usa un solo bind por vértice y suma huesos auxiliares solo donde el error pasaría de 30 mm (`MAX_ERROR_MM`). Mediana: 19 huesos reales + 64 auxiliares (antes `eorc` 282). Paridad aceptada: ≤ 30 mm (`tools/audit_skeletal.gd`, 5 modelos, 99 cuadros: 4–8 mm medido).
- **Fusión de superficies por material:** hecha, pero casi no reduce (572 → 568 en 84 modelos).
- **Medición** (`look_bench --units=150 --quick --samples=60`, vista base, ms por cuadro): low 36, medium 52, high 96, nativa 76. Antes de los huesos mínimos: medium 158 y high 1 889 (cortado a los 600 s). Llamadas de dibujo sin cambio (17 973): el costo eran los huesos.
- **Verificación de main:** import sin errores, `quick` 27/27.

Deuda:
- La corrida horneada (`--baked-bodies`) salió un orden de magnitud más lenta y se cortó a los 600 s; no se investigó porque el horneado se retira en 023h.
- `proceso_ms` de 47–58 ms con 150 cuerpos (animación en CPU): si hace falta, `BodyAnimLod` del plan.
- Con todas las capas encendidas, high llega a 218 ms y 26 145 llamadas de dibujo.

### RFC-023 023h — Retiro del horneado (cierre 2026-10-17)

- **Fuera:** `ClipPosePlayer`, `cache/look/anim_f37` y `anim_mesh_clips_f37.json` como entrada del juego, el flag `--baked-bodies`, `BodyCatalog.BAKED_DIR`/`clip_frame_path`, `bake_clips.gd`, `bake_bodies.gd`, la exportación por cuadro de `export_stats.py`, los oráculos de cuadros horneados (`audit_skeletal.gd`, `audit_body_pose.gd`, `audit_unit_parity.py`, `export_skeletal_reference.py`) y los comparadores horneado/esqueleto de `debug/`.
- **Híbridos:** los 11 (faez, thes, the2, sara, hoom, bane, ban2, sirc, surt, gamm, baby) son `.glb` estáticos en `assets/original/props/` (geometría idéntica al OBJ horneado, 0,0 mm; fuente `import_props.py --bodies-from`). El selector de magos dibuja un `BodyRig`.
- **`sizes.json`:** dato versionado sin generador (calcularlo del `.glb` no da los mismos números y movería cápsulas y digests).
- **Pendiente (033i, con OK del usuario):** borrar `cache/`; `audit_original_props.gd`, `export_persephone.py`, `export_bodies.py` y la rama de caché de `export_buildings` se van con ella.

Deuda:
- `debug/body_gallery` y las escenas con `gallery_body.tscn` ya no muestran cuerpos con esqueleto (solo híbridos y props).
- Verificación con Godot a cargo del orquestador: import, `quick`, `rules_suite`, regresión de flows f19/f23/f32 y selector de magos.

### RFC-023 cerrado (2026-10-17)

- **023h:** se retiró el horneado de cuerpos animados (`ClipPosePlayer`, `anim_f37`, `--baked-bodies`, `bake_clips`, `bake_bodies`). Los 11 híbridos pasan a `.glb` estáticos en `assets/original/props/` (0 mm contra el OBJ). `sizes.json` queda como dato versionado. La auditoría de esqueletos y la referencia de sacengine se conservan, con `--ref` obligatorio.
- **Verificación de main, sin agentes en paralelo:** import sin errores; auditoría de esqueletos PASS (≤ 30 mm); `quick` 27/27; `rules_suite` PASS; paridad de assets PASS. Banco `all` en fixed, fixed2 y stress: s7 `c5a5755a`, s7_npcs `4386b384`, s1_trivial `60fbf6d5` y f139 `e3ded3af`, iguales en los tres modos y sin CONTAMINATED.
- **Playtest 023h** (`agent/out/pt023h/`): selector de magos con esqueleto; flows f19, f23 y f32 PASS; sin errores de script.

Deuda:
- La vista previa del selector muestra a algunos magos de espaldas (The Ragman).
- La cámara de la partida de IA es lejana: no hay captura cercana de criaturas ni de estructuras de 023h.

### F175 — Cierre: el port sin caché (RFC-033, corte 033i)

**Piezas:**
- Ningún archivo de `scenes`, `data`, `debug`, `addons`, `agent` ni `tools` depende de `cache/`; `cache/` sigue ignorada y en disco (se borra una semana después, con OK del usuario).
- Borrados: `tools/export_persephone.py`, `export_bodies.py` y `audit_original_props.gd`. `export_stats.py` escribe por defecto en `assets/original/data`.
- Verificación pendiente (con `cache` renombrada a `cache.off`): `--import` x2, `quick` igual a la base, `rules_suite`, `check_original_assets.sh` y un playtest desde `boot.tscn`.

### RFC-033 cerrado (2026-10-17)

- **Verificación con `cache/` renombrada a `cache.off`, sin agentes en paralelo:** paridad de assets desde los WAD PASS; import ×2 sin errores de script y sin referencias a `res://cache`; `quick` 27/27; `rules_suite` PASS. Playtest (`agent/out/pt033i/`): menú y selección de mago con ventana, flow AGENT_OK, sin «Failed to load» ni `res://cache` en los logs.
- La carpeta `cache/` volvió a su lugar. Se borra una semana después, con OK del usuario.

Deuda:
- La partida con ventana sin caché no tiene captura (el playtester abrió el juego sin una escena que cierre sola y se lo cortó); la simulación sin caché la cubren `quick` y `rules_suite`.

### F178 — Admisión por ticket en el núcleo de `mp_kit` (RFC-034, corte 034a)

**Piezas:**
- `MpKit.join(address, p_port := -1, ticket := "")`; `MpKit.admission` (Callable `(peer_id, ticket) -> slot`), `admission_timeout_s`, `rpc_present_ticket`, `rpc_admission_rejected`, señal `admission_rejected(reason)`.
- `MpIds.bind_client(peer, slot)`, `MpFlow.StartWhen.MANUAL`, `MpFlow.join_endpoint(host, port, ticket)`, `MpLan.is_valid_hostname`, `MpBoot.role()` conoce `room-server`.
- Sin `admission` el comportamiento es el de antes (slot por orden de conexión).
- Verificación pendiente (orquestador): import x2, `quick` igual a `det_baseline.txt`, `rules_suite`, `run_f63_net.sh` PASS.

### Cierre 034a (F178) y 034i (F186) — 2026-10-17
- **034a:** review CHANGES_REQUESTED (los broadcasts llegaban a peers sin admitir), corregido en 324fe1b: `_broadcast_peers()` manda solo a peers con slot cuando hay `admission`. Verificación en main: import sin errores, `quick` 27/27, `rules_suite` PASS, `run_f63_net.sh` (dedicado + 3 clientes) PASS.
- **034i:** la cola de Godot vive en `addons/agent_kit/determinism/harness/` (sin nada de sacproject; `GODOT_RUN_NS`); el juego usa shims. `selftest_queue.sh` 4/4 PASS sin Godot; `quick` 27/27 con la cola nueva.

Deuda:
- `run_f63_net.sh` falló una vez («click missed %Play» en los 3 clientes) y pasó al repetirlo: es inestable.

### F179 — Lanzador de partidas y agente del dedicado (RFC-034, corte 034b)

**Piezas (todas en `addons/mp_kit/lobby/`, sin nada de Sacrifice):**
- `MpLobbyConfig` (`.tres`; `data/net/lobby_config.tres` producción, `lobby_config_local.tres` pruebas con `max_matches=1`): todos los límites y tiempos. `with_cli_overrides()` deja pisar cada campo numérico con un flag (`max_matches` -> `--max-matches=N`, `rejoin_grace_s` -> `--rejoin-grace-s=N`). Tope por defecto 99.
- `MpMatchLauncher`: puerto libre del rango (se prueba con UDP), `launch(match_id, ticket)` (`ERR_BUSY` en el tope), `OS.create_process` vía `MpProcessRunner`, registro `user://mp_matches/registry.json`, sondeo de `state.json` / `result.json`, mata por latido viejo, `spawn_timeout_s`, `match_max_s`; `reap_orphans()` al arrancar (solo mata un pid si su `state.json` dice el mismo pid). Señales `match_listening`, `match_ended`, `match_failed`.
- `MpMatchAgent`: lee `--match-ticket-file` y `--room-pid`, pone `MpKit.admission` con el hash del token (un uso activo, rejoin dentro de `rejoin_grace_s`), latido en `state.json`, `report_result()` -> `result.json` + `broadcast_session_ended` + quit; sale con `reason` `empty`, `ticket_expired` o `room_gone`.
- `MpProcessRunner` (+ `MpProcessRunnerStub` para pruebas sin Godot), `MpMatchFiles` (rutas, JSON atómico 0600, sha256).
- Prueba: `agent/run_034b.sh` (escena `debug/net/match_launcher_probe.tscn` + dedicado `match_agent_probe.tscn`).

**Pendiente (orquestador):** `--import`, correr `agent/run_034b.sh` (espera `LAUNCHER PROBE PASS`), `quick` igual a la base. Sin verificar: `--log-file` en 4.7.2 (el flag es `log_file_flag` en el launcher; si no existe, vaciarlo).

### Cierre 034b (F179) — 2026-10-17
- Sonda `agent/run_034b.sh` (headless, tope interno y externo): LAUNCHER PROBE PASS 4 veces seguidas (huérfano matado con identidad verificada, tope de partidas por flag y `ERR_BUSY`, ticket sin token en disco, falso rechazado, real al slot del ticket, `session_ended`, `result.json`, sin procesos ni registro al final). `quick` 27/27 y `run_f63_net.sh` PASS.
- Review CHANGES_REQUESTED (identidad del pid en `reap_orphans`, flags del launcher), corregida en 755db1f.
- En el camino: el dedicado lanzado por la sonda cargaba el mundo del juego y reemplazaba su escena; ahora `MpFlow` respeta `--no-flow`.

Deuda:
- Detección de pids e identidad validadas en macOS/Linux; en Windows es de mejor esfuerzo.

### F180 — Estados de sala sin red (RFC-034, corte 034c)

**Pieza (`addons/mp_kit/lobby/mp_lobby_rooms.gd`, sin nada de Sacrifice):** `MpLobbyRooms` (RefCounted), dueño único del estado de cada sala.
- Estados `OPEN`, `COUNTDOWN`, `LAUNCHING`, `IN_MATCH`, `CLOSED`. Llena y todos listos y conectados → `COUNTDOWN`; dejar de estar listo, cambiar pick o slot, salir o caerse → `OPEN`; fin de cuenta → `LAUNCHING` (`MpMatchLauncher.launch`); `match_listening` → `IN_MATCH` (señal `match_assigned` por asiento con puerto y token); `match_ended` → `OPEN` con el resultado en la sala; spawn que falla, `spawn_timeout_s` o tope `max_matches` → `OPEN` + `room_error` (`spawn_failed`, `matches_cap`); latido viejo en partida → `OPEN` + `match_failed`; 0 asientos durante `empty_room_close_s` → `CLOSED`.
- Asientos por sesión (`session_id`): una sesión caída conserva el asiento `resume_grace_s` (durante `LAUNCHING`/`IN_MATCH` no corre; el plazo empieza en el resultado).
- El pick (`meta`) y las `options` son `Dictionary` opacos; los validan `meta_validator`, `options_validator` y arma el ticket `ticket_builder` (Callables del juego). Errores como códigos String estables. El tiempo solo avanza con `tick(delta)`.
- Parámetros: todos de `MpLobbyConfig` (`max_rooms`, `seats_per_room`, `countdown_s`, `resume_grace_s`, `empty_room_close_s`, `max_matches`...). `data/net/lobby_config_local.tres` suma `resume_grace_s=5` y `empty_room_close_s=3`.
- Prueba: `agent/run_034c.sh` (escena `debug/net/lobby_cases.tscn`, runner `data/net/runner_stub.tres`, sin red ni procesos).

**Pendiente (orquestador):** `--import` una vez (clases nuevas) y correr `agent/run_034c.sh` (espera `LOBBY CASES PASS`). Código escrito sin ejecutar Godot.

### Cierre 034c (F180) — 2026-10-18
- `agent/run_034c.sh` (headless, sin red ni procesos): LOBBY CASES PASS, 130 checks. El primer intento no compilaba: `MpLobbyRooms.set_meta` pisaba `Object.set_meta`; el orquestador lo renombró a `set_seat_meta`.
- `MpLobbyRooms` no lo usa todavía el juego; `quick` no se corrió en este corte (no toca la simulación).

Deuda:
- Las sondas de `debug/net/` no cortan ante un error de compilación: esperan el tope externo (120 s). Sumar el corte por error de script cuando el módulo de determinismo pase al kit (034j).

### F187 — Módulo de determinismo en el kit (RFC-034, corte 034j)

**Piezas (`addons/agent_kit/determinism/`, sin nada de Sacrifice):**
- `DetRecorder` (registro de líneas + sha256, `self_tick`, `advance`, `record`, `sample`, `digest`, `write_outputs`) y `DetCli` (`--out`, `--events`, args).
- `det_run.sh <casos> CASO|all|quick|table|bless [MODO...] [--no-window]` + `det_report.py`: modos fixed/fixed2/stress/window, base de digests del proyecto, quick que borra lo viejo y exige 2 modos frescos, watchdog de RSS/tiempo y corte inmediato por `Parse Error`/`Compile Error`/`Failed to load script` (`script_error_kill`), CONTAMINATED.
- Config del proyecto: `det.cfg` + `det_cases.txt` junto al archivo de casos. Ejemplo y autoprueba: `example/det_selftest.tscn`, `example/det_cases.txt`, `det_selftest.sh`.
- Desvío: las columnas de la tabla pasan a inglés sin tildes (`line`, `wall (s)`, `RSS max (MB)`, `warnings`) para que el módulo no tenga texto en español; 034k lo toma como cambio de formato, no de contenido.
- El juego no se toca en este corte (034k). `.gd.uid` de los scripts nuevos los genera el primer import.

**Pendiente (orquestador):** `--import` una vez; correr `det_selftest.sh` (espera `SELFTEST PASS`).

### Cierre 034j (F187) — 2026-10-18
- `det_selftest.sh` del módulo de AgentKit: SELFTEST PASS (mismo digest en fixed, fixed2 y stress; `bless` escribe la base; base falsa → QUICK FAIL; script roto → `script_error_kill` en 1 s). Import sin errores. Sin nada de Sacrifice en `addons/agent_kit/determinism/`.

### F188 — Sacrifice usa el módulo de determinismo (RFC-034, corte 034k)

- `AiAudit` delega reloj, líneas y sha256 en un `%Recorder` (`DetRecorder`, `self_tick = false`; `AiAudit._physics_process` llama `recorder.advance()` donde sumaba `tick`). `tick`, `running`, `lines`, `line_count` y `keep_lines` leen del recorder; sin `Recorder` en la escena (p. ej. `AiAudit.new()` de `pt73_probe`) crea uno propio. Formato de línea y hash sin cambios.
- `debug/ai_match.gd` lee args con `DetCli.args()` y escribe JSON (`--out`) y líneas (`--events`) con `recorder.write_outputs(_report)`; se borraron `_write`, `_absolute` y `_parse_args`. `debug/ai_match.tscn` y `agent/fixtures/pt024a/ai_match_cam.tscn` llevan el nodo `Audit/Recorder`.
- `agent/det.cfg`, `agent/det_cases.txt` (29 casos con sus args; `quick` = `s1_quick` en todos los modos + 26 en `fixed`; `all` = s7, s7_npcs, s1_trivial, f139). `agent/run_determinism.sh` queda como shim a `det_run.sh` con la misma interfaz. `agent/det_baseline.txt` no cambia.
- Cambio de formato aceptado: columnas de la tabla en inglés (034j). Digests y `.events` no pueden cambiar.

**Pendiente (orquestador):** `--import` una vez; verificar con `cmp` del `.events` antes/después y `quick`/`all` contra la base.

### Cierre 034k (F188) — 2026-10-18
- El juego usa el módulo de determinismo del kit (`%Recorder` en `ai_match`, `agent/det.cfg`, `agent/det_cases.txt`, `run_determinism.sh` como shim). Los `.events` de `s1_quick`, `s7`, `f139` y `f164` son **idénticos byte a byte** (`cmp`) a los del código anterior. Import sin errores; `quick --no-window` 27/27 y QUICK PASS.

### F181 — Protocolo del lobby sobre ENet (RFC-034, corte 034d)

**Piezas (`addons/mp_kit/lobby/`, sin nada de Sacrifice):**
- `MpLobby` (autoload, después de `MpKit`): contenedor con los hijos `Server` y `Client` y un `SceneMultiplayer` propio (`set_multiplayer` sobre su ruta). El lobby no toca el peer de `MpKit`: el cliente puede seguir conectado al lobby mientras `MpKit.join` entra al dedicado, y el resultado le llega por el lobby. El script se puede instanciar más de una vez con otro nombre (una pila de lobby cada uno; lo usa la prueba).
- `MpLobbyServer`: expone `MpLobbyRooms` por red (puerto `lobby_port`). Mensajes `hello`, `list_rooms`, `create_room`, `join_room`, `join_code`, `leave_room`, `set_slot`, `set_pick`, `set_ready`, `chat`, con validación del lado servidor: versión, nombre (1..`name_max_len`, sin control ni corchetes), tamaño de `options`/`meta` (`payload_max_bytes`), ritmo de chat (balde `chat_rate_per_s`/`chat_burst`) y `hello_timeout_s`. El cliente nunca elige slot, puerto ni semilla. Sesión retomable por `resume_token`. Cada miembro recibe la vista de su sala sin `session_id` ajenos; las privadas no se listan; `room_state` se agrupa por fotograma y la lista sale a `list_push_hz`. Validadores y `ticket_builder` los inyecta el pegamento.
- `MpLobbyClient`: espejo (`rooms`, `room`, `chat_log`), comandos (`create_room`, `join_room`, `join_code`, `leave_room`, `choose_seat`, `set_pick`, `set_ready`, `send_chat`, `refresh_rooms`, `resume`) y señales en pasado (`lobby_joined`, `room_updated`, `countdown_started`, `countdown_cancelled`, `match_ready(host, port, token)`, `match_finished(result)`, `error_received`...).
- `MpLobbyConfig` suma `hello_timeout_s`, `reject_flush_s`, `payload_max_bytes`, `public_host`; `with_cli_overrides()` acepta también campos String.
- Nombres evitados a propósito: nada de `set_meta`, `connect`, `get`, `call` en la API pública.

**Prueba:** `agent/run_034d.sh` (escena `debug/net/lobby_net_cases.tscn`): 1 proceso servidor de salas (runner stub; el propio servidor escribe `state.json`/`result.json` cuando el cliente se lo pide por archivo) y 1 proceso con 4 clientes (cada uno con su `MpLobby`). Escenario: sala A y sala B 1v1 en paralelo. Verifica: cada cliente ve solo a su rival; listo, picks, chat y cuenta regresiva de A no tocan a B (ni una actualización); A arranca y entra a su partida mientras B sigue abierta; cada sala recibe su `match_ready` con puerto y token distintos; el ticket de A no acepta el token de B y al revés (y no guarda tokens en claro); el resultado de A llega solo a A; si un cliente de A cae o sale, B no cambia; el resultado de B llega solo a B; validaciones (`not_in_room`, `bad_options`, `bad_meta`, `already_in_room`, `rate`). Sin dedicados reales (van en 034e).

**Pendiente (orquestador):** `--import` una vez (clases y autoload nuevos) y correr `agent/run_034d.sh` (espera `LOBBY NET PASS`). Código escrito sin ejecutar Godot.

### Cierre 034d (F181) — 2026-10-18
- `agent/run_034d.sh` (servidor de salas + 4 clientes headless, runner stub): LOBBY NET PASS, 88 checks, incluido el escenario de **dos salas 1v1 en paralelo** pedido por el usuario (cada uno ve solo a su rival, listo/picks/cuenta independientes, `match_ready` con puerto y ticket propios, el ticket de A no sirve en B, una salida en A no cambia B, el resultado de A llega solo a A). Import sin errores; `quick` 27/27.
- El lobby usa su propio `SceneMultiplayer` (no el peer de `MpKit`), así el cliente sigue en el lobby mientras entra al dedicado.

### F182 — Servidor de salas de Sacrifice y partida punta a punta (RFC-034, corte 034e)

**Pegamento del juego (`scenes/net/`, nada dentro de `addons/mp_kit/` salvo `MpLobbyEndpoint`):**
- `room_server.tscn/.gd`: la escena del VPS (`-- --room-server`). Instancia `MpMatchLauncher` y `SacrificeRoomRules`, instala los validadores, abre el lobby (`MpLobby.start_server`) e imprime una línea por evento: `salas listo puerto N`, `partida <id> sala "x" puerto P semilla S`, `sala "x" resultado {…}`. `--lobby-config=res://….tres` cambia la config; cualquier campo de `MpLobbyConfig` es un flag (`--max-matches=2`); `--match-args=a,b` suma args de usuario a cada dedicado (solo pruebas).
- `SacrificeRoomRules` (`Node`): `is_valid_pick` (el mismo `SacrificeFlow.sanitize_pick` del dedicado), `are_options_valid` / `clean_options` (solo `world` high_noon, `level` 1-9, `friendly_fire`, `drop_soul`, `starting_souls` 0-200; cualquier otra clave se rechaza) y `build_ticket` (slot = asiento + 1, pick saneado otra vez, semilla sorteada por el servidor; ningún cliente la elige).
- `MatchTicketGlue` (`Node`, solo en el dedicado con `--match-ticket-file`; lo instancia `SacrificeFlow`): arma el `MpMatchAgent` del kit y le da el sentido de Sacrifice. Del ticket saca los picks por slot, el `MatchSetup` (opciones + semilla) y `MatchState.result_changed` pasa a `report_result({winner_slot, defeated_slots, seed, ticks, reason:"result"})`. Abandono: un slot ausente más de `rejoin_grace_s` pierde (`reason:"abandon"`, gana el que queda); todos ausentes, `reason:"empty"` sin ganador. Un slot que nunca entró cuenta como ausente desde que vence el ticket. Gancho de prueba (no es regla): `--force-defeat-slot=N --force-defeat-after-ticks=T` derrota al slot N a los T ticks de admitido el primer jugador.
- `SacrificeFlow`: con `--room-server` queda en `StartWhen.MANUAL`; con ticket ignora el canal `pick` (solo republica los picks del ticket cuando el cliente recibe su slot) y no borra el pick de quien se va; `join_from_lobby(host, port, token)` para el cliente (034f). `MatchSetup.match_seed` (+ `--match-seed=N`) llega a `rules.match_seed`; el banco no lo pasa.
- `MpLobbyEndpoint` (genérico) + `data/net/lobby_endpoint.tres` (127.0.0.1:7700; `--lobby=host:puerto` lo pisa). `data/net/lobby_config.tres` con los valores de producción (4 partidas, puertos 7800-7831).

**Prueba:** `agent/run_034e.sh` (cliente `debug/net/room_e2e_client.tscn`): **7 procesos headless**, 1 servidor de salas (`--max-matches=2`) + 4 clientes de lobby + **2 dedicados reales** que lanza el servidor. Dos salas 1v1 a la vez: SalaA (Ana crea y entra al dedicado 2 s tarde, Aldo entra primero y queda en el slot 2; termina por derrota forzada del slot 2: gana el 1, `result`) y SalaB (Beto crea y se va 1 s después de entrar, Bruno se queda; gana el 2 por `abandon`). Además Aldo prueba su ticket en el dedicado de SalaB y Bruno el suyo en el de SalaA (rechazados), y cada uno un ticket inventado en el suyo. El script revisa los logs (un solo log: los dedicados heredan el stdout del servidor): cada dedicado leyó su ticket (semilla y nivel de su sala), cada slot tiene el pick del lobby, cada slot entró una vez, cada resultado lleva la semilla del ticket y llega a su sala y a sus clientes, nada de la otra sala; no queda proceso ni carpeta de partida y `registry.json` queda vacío. Mide RSS total (freno `E2E_RSS_LIMIT_MB`, 8192 por defecto) y mata por pid y descendientes a los 180 s. Imprime `E2E PASS` / `E2E FAIL`.
- Los clientes de prueba van con `--no-flow` y no cargan el mundo (la partida real la simula el dedicado); el mundo en el cliente sale en 034f con la UI.
- Determinismo: el resultado lleva `seed` y `ticks`; no hay digest contra el banco. El plan de 034e pide `quick` igual a `det_baseline.txt` (tocan `SacrificeFlow` y `MatchSetup`): lo corre el orquestador.

**Pendiente (orquestador):** `--import` una vez (clases y `.uid` nuevos); `quick --no-window` contra `det_baseline.txt`; correr `agent/run_034e.sh` (espera `E2E PASS`). Código escrito sin ejecutar Godot.

### Cierre 034e (F182) — 2026-10-18
- `agent/run_034e.sh`: **E2E PASS 3 veces seguidas**, 118 checks cada una. Escenario del usuario con dedicados reales: servidor de salas, 4 clientes y **dos salas 1v1 en paralelo**, cada una con su dedicado (SalaA termina por resultado, SalaB por abandono); tickets cruzados e inventados rechazados; cada resultado llega solo a su sala; al final 0 procesos Godot y sin archivos de partida. RSS total máximo 1,3 GB con 7 procesos, ~35 s por corrida. Import sin errores; `quick` 27/27.
- El primer FAIL («1 dedicated process left») era la prueba contándose a sí misma con `awk`; corregido en 87ec897.

### F183 — Pantallas de salas, cuenta regresiva y vuelta a la sala (RFC-034, corte 034f)

Pegamento del juego en `scenes/ui/lobby/` (nada nuevo dentro de `addons/mp_kit/`). Las vistas **solo leen** `MpLobby.client` (el espejo del kit) y llaman a sus comandos; textos en español, sin números mágicos (constantes o `@export`).
- Menú: botón **«Salas online»** (`boot.tscn`, `%Online`) → `lobby_screen.tscn`. El servidor sale de `data/net/lobby_endpoint.tres` (`--lobby=host:puerto` lo pisa). El campo `%Ip` y «Unirse» del menú quedan **solo en builds de debug** (decisión del usuario).
- `lobby_screen.tscn/.gd`: no guarda estado; elige una vista según el cliente (sin conexión → Conectar; en línea sin sala → Salas, o Crear; en sala → Sala), muestra un aviso con los errores (`LobbyText`) y, con `match_ready`, entra a la partida con `SacrificeFlow.join_from_lobby`.
- `lobby_connect` (nombre del jugador, «Conectar», «Volver al menú»; `%Ip` solo en debug), `room_list` (un botón por sala con «nombre · ocupados/asientos · estado», «Actualizar», «Crear sala», unirse con código), `room_create` (nombre, privada, nivel 1-9 o el de las reglas), `room_view` (jugadores, asientos con `seat_row`, «Elegir mago y dios» con el `character_select` del menú —su botón dice «Elegir» acá—, «Estoy listo», «Salir de la sala», cuenta regresiva «La partida empieza en N…», «Preparando la partida…», «Partida en curso», resultado de la última partida) y `chat_box` (log del cliente + envío). Quien no abre el selector manda el pick que dejó el menú (`SacrificeFlow.pick`) al sentarse.
- `lobby_text.gd` (`LobbyText`): códigos del servidor y del cliente a español, estados de sala, texto del pick y del resultado («Ganaste.» / «Perdiste.» / «Ganaste: tu rival abandonó.»).
- Partida → sala: `SacrificeFlow.from_lobby` (se pone con `join_from_lobby`, se limpia con cualquier otra forma de jugar) hace que `_go_boot()` —pausa «Salir al menú», fin de partida por servidor cerrado— vuelva a `lobby_screen` en vez del menú. `lobby_return.tscn` (en `Hud` de High Noon, `%LobbyReturn`) muestra «Volver a salas» cuando hay resultado (o el dedicado avisa el fin: un abandono no tiene banner) y una línea para abandono/cierre; solo en partidas de sala. El lobby sigue conectado (autoload) y la sala todavía existe con `last_result`.
- Textos de estado de `MpFlow` en español dentro de `SacrificeFlow` (antes los defaults en inglés). `data/net/lobby_config.tres` (producción): `result_quit_delay_s = 10` para que el banner se lea (antes 3 s).
- Cada vista con F6 sola dice «Sin conexión» y no conecta por su cuenta.

- Arranque justo: el dedicado de una sala ya no simula hasta que **todos los asientos del ticket** mandaron `world_ready` (`MatchTicketGlue` pausa el árbol; `MatchClock` y la simulación esperan; el pegamento y el agente siguen con `process_mode = ALWAYS`). Un asiento que no cargó `load_timeout_s` (nuevo en `MpLobbyConfig`, 60 s, flag `--load-timeout-s`, desde la primera admisión) cuenta como abandono. `--no-load-hold` apaga la espera (solo `run_034e.sh`, cuyos clientes no cargan el mundo). Las derrotas forzadas de prueba cuentan ticks desde que todos cargaron.

**Prueba (playtester, 1 ventana):** `agent/run_pt034f.sh`: servidor de salas headless + jugador 2 headless (`agent/fixtures/pt034f_peer`, mismo cliente que usan los botones; la pantalla real de salas lo lleva a la partida y de vuelta) + jugador 1 con ventana por el flow `agent/flows/pt034f_host.json` (menú, Salas online, conectar, lista vacía, crear «Duelo», sala sola, el otro se sienta, chat, selector, listo, cuenta regresiva, High Noon, banner + «Volver a salas», de vuelta con «Ganaste»). La partida termina por derrota forzada del slot 2. 11 capturas en `agent/out/pt034f/`. Topes: 150 s internos del par, 240 s externos (mata por pid y descendientes), RSS; imprime `PT034F PASS` / `PT034F FAIL`.

**Pendiente (orquestador):** `--import` una vez (clases `LobbyText` y `LobbyReturn`, `.uid` nuevos); `quick` igual a `det_baseline.txt` (toca `SacrificeFlow` y `high_noon.tscn`); correr el playtest. Código y escenas escritos sin ejecutar Godot.

### F190 — Transporte WebSocket opcional en mp_kit (RFC-034, corte 034n)

El usuario quiere el port a web (el navegador no abre UDP), asi que el kit elige transporte: **ENet (UDP) por defecto, WebSocket (TCP) opcional**. Todo generico dentro de `addons/mp_kit/`; el juego no cambia (mismos RPC y replicacion).
- `MpTransport` (`mp_transport.gd`): `create_server`, `create_client` (`ws://host:port`, o una URL completa) y `port_is_free` (probe TCP o UDP). Acepta `TLSOptions` para `wss://`.
- `MpKit.transport` (flag `--transport=ws|enet`, `host()`, `host_dedicated()` y `join()`), `MpLobbyClient.transport` (mismo flag), `MpLobbyConfig.transport` (campo `.tres` y flag; lobby y busqueda de puertos de partida) y el lanzador pasa `--transport=` al dedicado hijo (`agent_fields`).
- Sin nombres que pisen `Object`/`Node`. README del kit: seccion «Transporte» y `wss://` con proxy inverso o `TLSOptions` para el VPS (documentado, no implementado).
- **Prueba**: `agent/run_034d.sh` y `agent/run_034e.sh` aceptan `TRANSPORT=ws` (sin variable, ENet, igual que antes).

**Pendiente (orquestador):** `--import` una vez (clase `MpTransport` nueva); correr 034d y 034e con ENet y con WS. Codigo escrito sin ejecutar Godot.

### Cierre 034n (F190) — 2026-10-18
- `MpTransport`: ENet por defecto, WebSocket con `--transport=ws` (kit, lobby, launcher y dedicados). Verificación en main: import sin errores; `run_034d.sh` LOBBY NET PASS (88) y `run_034e.sh` E2E PASS (118, dos salas con dedicados reales) **con ENet y con WebSocket**; `quick` 27/27.

### Cierre 034f (F183) — 2026-10-18
- Playtest con ventana `agent/run_pt034f.sh` (Haiku, `agent/out/pt034f/`): **PT034F PASS** en la quinta corrida. Menú con «Salas online», conectar, lista, crear sala, sala con dos jugadores, mago y dios, chat, listo, cuenta regresiva, el mundo de High Noon al entrar, banner «Victoria» con «Volver a salas» y vuelta a la sala con «Ganaste.». Sin `SCRIPT ERROR`.
- En el camino:
  - El arnés del segundo jugador estaba en `agent/harness/` con `.call()` y rompía todos los flows; se movió a `agent/fixtures/`.
  - El Enter de los campos ya disparaba la acción.
  - El intento de conexión al lobby tiene un plazo (8 s).
  - **Bug real:** el dedicado arrancaba la simulación sin esperar a que cargaran todos. Ahora espera hasta `load_timeout_s` (60 s, parametrizable) y el que no carga cuenta como abandono.
  - `run_034e.sh` sigue en E2E PASS con ENet y con WebSocket.

### F191 — Servidor local (RFC-034, corte 034m)

Opción **aparte** de «Salas online»: una partida 1v1 en la PC del jugador, con el mismo dedicado que el VPS y sin servidor de salas (no aparece en su lista, sin UPnP, sin respaldo al VPS). Nada nuevo en `addons/mp_kit/`.
- Menú: botón **«Servidor local»** (`boot.tscn`, `%LocalServer`) → `scenes/ui/local_server/local_server_screen.tscn` con «Crear servidor local», «Unirse a servidor local» y «Volver al menú». Visible también fuera de debug.
- Host (`local_host_view`): usa el mago y el dios del menú; elige el **dios del rival** (o aleatorio) y el transporte (UDP/ENet o TCP/WebSocket). «Crear» lanza el dedicado y la pantalla muestra **dirección local, puerto, transporte y código del rival** + una línea de ayuda + «Copiar» + «Entrar a la partida» (`SacrificeFlow.join_local_server`; al salir vuelve al menú, no a las salas).
- Rival (`local_join_view`): campo `dirección:puerto` (`LocalServerEndpoint.parse`, puerto por defecto 7710), campo de código y selector de transporte; avisos en español si el servidor lo rechaza (`LocalServerText`).
- `scenes/net/local_server_host.tscn` (`LocalServerHost`, hijos `Launcher` = `MpMatchLauncher` y `Rules` = `SacrificeRoomRules`, config `data/net/lobby_config_local_server.tres`: puerto fijo 7710, ticket 15 min, `matches_root` propio, sin reap): arma un ticket de **dos asientos** con `build_ticket`, lanza el dedicado y emite `server_ready(address, port, code)`. Vive bajo `root` y se libera cuando termina la partida, falla, o el host sale de la partida / cierra el juego (mata al dedicado).
- **Credencial del rival (decisión):** el código es el token del asiento 2 del ticket (8 bytes al azar en hex, 16 caracteres); el host tiene otro para el asiento 1. El dedicado guarda solo los sha256 (`MpMatchAgent`): sin código, con un código inventado o con el del asiento ya ocupado, la admisión devuelve 0 y el cliente recibe el rechazo. Se eligió esto antes que «admisión sin ticket con el slot 2 libre» porque no deja una puerta sin credencial en un puerto que el jugador puede estar exponiendo a Internet.
- **El rival elige su mago y su dios** (decisión del usuario): en «Unirse» usa el selector del menú antes de conectar. El ticket deja el asiento 2 sin pick (`open_picks: [2]`); al admitirlo, el cliente manda su pick por el canal `pick` y el dedicado lo valida con `sanitize_pick` (`SacrificeFlow._accept_open_pick`). Mientras falte, `start_when` queda en MANUAL: el mundo no se crea hasta tener todos los picks (después rige la espera de carga). Pick inválido: `MpKit.reject_peer(id, "bad_pick")` (método público nuevo y genérico del kit), el rival elige de nuevo y vuelve con el mismo código. Sin pick en `load_timeout_s` cuenta como abandono. `result.json` ahora trae `picks` (lo que jugó cada asiento): las pruebas lo leen en vez del log del dedicado, que no se captura.
- Guía corta en `docs/servidor_local.md`: exponerlo a Internet es cosa del jugador; ENet es UDP, ngrok no sirve (reenvío de puertos, Tailscale/ZeroTier, playit.gg); con `--transport=ws` (o «TCP (WebSocket)» en la pantalla) sí sirve un túnel TCP como ngrok.

**Prueba:** `bash agent/run_034m.sh` (headless; `TRANSPORT=ws` por TCP): host (`LocalServerHost` real + cliente) + rival + intruso con `debug/net/local_server_e2e.tscn` (`--no-flow`). Verifica que el host lanza el dedicado local, que el rival entra con `address:port` y el código al slot 2, que un tercero (sin credencial, con código inventado, con el código del asiento ocupado) es rechazado, que la partida termina con resultado (derrota forzada del slot 2: gana el 1), que el servidor local se cierra solo y que no quedan procesos ni carpetas. Topes: 150 s internos, 170 s externos (mata por pid y descendientes), RSS. Imprime `E2E LOCAL PASS` / `E2E LOCAL FAIL`.
**Playtest (1 ventana):** `bash agent/run_pt034m.sh`: el host con ventana por `agent/flows/pt034m_host.json` (menú, «Servidor local», crear, pantalla con dirección/puerto/código, entrar, High Noon, «Victoria») y el rival headless que toma el puerto y el código del log del host. Capturas en `agent/out/pt034m/`. Imprime `PT034M PASS` / `PT034M FAIL`.

**Pendiente (orquestador):** `--import` una vez (clases `LocalServerHost`, `LocalServerEndpoint`, `LocalServerText`; `.uid` nuevos); `run_034m.sh` con ENet y con `TRANSPORT=ws`; `quick` igual a `det_baseline.txt` (toca `SacrificeFlow` y `boot.tscn`); correr el playtest. Código y escenas escritos sin ejecutar Godot.

### Cierre 034m (F191) — 2026-10-18
- «Servidor local»: el host lanza un dedicado en su PC (ticket de 2 asientos, código de 16 hex para el rival, solo su sha256 en disco); el **rival elige su mago y su dios** (decisión del usuario), el dedicado valida el pick (`bad_pick` si no existe) y no crea el mundo hasta tener todos.
- `agent/run_034m.sh`: E2E LOCAL PASS, 44 checks, 2/2 con ENet y 1/1 con WebSocket: el asiento 2 juega con el pick del rival, un pick inválido se rechaza, un tercero sin credencial / con código inventado / con el código del rival no consigue asiento mientras la partida sigue viva, el servidor local cierra con el resultado y no quedan procesos. `quick` 27/27; `run_034e.sh` PASS.
- Con ENet el dedicado acepta tantas conexiones como asientos: un tercero ni llega a la admisión (sin respuesta y sin asiento); con WebSocket recibe `admission_rejected`. El orquestador ajustó la prueba para aceptar las dos formas.

### F192 — Terreno visible en el editor (RFC-035, corte 035a) — cerrado 2026-10-18

- **Causa:** `terrain.gd` es `@tool`, pero `MapTerrainData` no lo era, así que en el editor era un placeholder y `data.is_valid()` fallaba. Sin malla no había nada que ver. La sonda previa lo mostró en el log.
- **Arreglo:**
  - `@tool` en `MapTerrainData` y en `ParticleType`.
  - La malla visual queda horneada en `assets/original/maps/high_noon/terrain_mesh.res`, la arma `tools/bake_terrain_mesh.gd` y la escena la referencia.
  - `CommandCue` apaga `_process` en el editor.
  - `detect_3d/compress_to=0` en las 971 texturas sin pérdida, para que el editor no las pase a VRAM.
- **Verificación:**
  - `debug/terrain_bake_cases.gd`: `TERRAIN_BAKE PASS`.
  - El horneado es idempotente.
  - `quick` PASS sin mover digests.
  - El usuario confirmó que ve el mapa en el editor.

### F194 — Material del suelo editable (RFC-035, corte 035b) — cerrado 2026-10-18

- **Qué cambió:**
  - Hay un `ground_classic.tres` por dios (5) y `GodTheme.ground_material` apunta a cada uno.
  - `atlas`, `edge` y `light` son texturas sin pérdida y sin mipmaps.
  - `Terrain` guarda el material de James en la escena. En partida, `ThemeApplier` pone el del dios de la semilla y trabaja sobre una copia.
  - `terrain.gd` ya no arma el material por código, y `light_base`/`light_gain` viven en el `.tres`.
  - `tools/import_themes.py` e `import_map.py` usan el tipo «lossless».
- **Verificación:**
  - Capturas `biome_close` antes y después, por dios: la diferencia media va de 0,04 a 0,29 sobre 255. Solo cambian las partículas animadas.
  - `quick` PASS sin mover digests.
  - El usuario confirmó en el editor que el material se ve y se edita.
- **Nota:** la sonda `editor_capture.sh` no funciona (el editor queda quieto y se corta a los 120 s). La verificación del editor la hace el usuario.

### F195 — Terreno como `terrain.glb` (RFC-035, corte 035c) — cerrado 2026-10-18

- **Qué cambió:**
  - `assets/original/maps/high_noon/terrain.glb` es la verdad del suelo, editable en Blender (solo la Y; mover en X/Z o cambiar la topología falla el import).
  - `tools/terrain_import.gd` (post-import) lee los buffers del glb sin `ImporterMesh`, valida la grilla de 10 m nombrando la celda, deriva `terrain.res` y agrega `Collision` (trimesh en el orden de los índices).
  - `high_noon.tscn` instancia el glb en `Terrain`. Se quitan `terrain_mesh.res` y `tools/bake_terrain_mesh.gd`.
  - `tools/terrain_glb_export.gd` escribe el glb una sola vez desde `terrain.res`; no pisa sin `--force`.
- **Pendiente de verificar (el orquestador corre Godot):** exportar, importar, `debug/terrain_bake_cases.gd`, `quick` sin mover digests.

**Cierre de F195 (orquestador):**
- **Datos:** `terrain.res` sale del `.glb` sin cambios. La importación no lo reescribe.
- **Pruebas sin ventana:** `TERRAIN_BAKE PASS`.
  - La colisión es igual.
  - Un vértice movido en X falla nombrando la celda.
  - Subir 5 m en Y cambia `ground_height` 5 m.
- **Malla visual:** el post-import la arma desde los datos con el mismo código del juego. El importador de glTF alteraba COLOR_0 (tile y uv) y el suelo salía lavado.
- **Capturas `biome_close`:** se comparó 035b contra 035c, ambas con el pasto apagado. La diferencia media va de 0,008 a 0,06 sobre 255.
- **`quick`:** PASS.
- **Pasto:** desde 035b el terreno guarda su material en la escena, y por eso el pasto se dibujaba en el editor y en las galerías sin preset. Ahora `GrassField` dibuja solo si hay un preset con `grass_enabled`.
- **Gotcha:** si cambia `tools/terrain_import.gd` y el `.glb` no, Godot no reimporta. Hay que borrar `.godot/imported/terrain.glb-*`.
- **Falta en el editor (usuario):** abrir `high_noon.tscn` y ver que `Terrain` es una instancia del `.glb` y se ve con tiles.

### F196 — Contenido del mapa como nodos (RFC-035, corte 035d) — cerrado 2026-10-18

- **Qué cambió:** `scenes/world/map/high_noon_layout.tscn` tiene los 69 `MapBuilding`, las 717 plantas y los 32 `NpcSpawn` (26 farmers en el slot 3 y 6 taurocks en el slot 4). Los bandos están en `sides.tres` (`MapSides`).
- **Generador:** lo arma una vez `tools/bake_map_layout.gd`, que no pisa archivos sin `--force`. Con `--check` vuelve a cargar lo guardado y lo compara contra los JSON.
- **En partida:** ya no se lee `ntts.json` ni `widgets.json` (el `grep` en `scenes/` da vacío). `MapPopulation` cuenta los edificios de la escena y hace aparecer los `NpcSpawn` en el orden del árbol.
- **Verificación:**
  - `--check` da CHECK PASS.
  - El log es idéntico: `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`.
  - `pt73_probe load`: 69 edificios, 0 NPC adentro de un edificio y error máximo de 0,008 m.
  - `quick` PASS sin mover digests.
  - Capturas `biome_close` contra 035c: diferencia media menor a 0,12 sobre 255.
- **Desvíos:**
  - Starts y Founts siguen en `high_noon.tscn`, bajo `MapProps`. Ya eran nodos y hay unas 12 escenas de debug que dependen de esa ruta.
  - La y de los `NpcSpawn` viene horneada. Si se mueve un spawn en el editor, hay que ajustar la y con el gizmo.
  - Los edificios no tienen vista previa en el editor: el modelo se arma en `_ready`.
- **Pendientes:**
  - El generador corre como script suelto y avisa `Identifier not found: GameData`, porque no hay autoload. No afecta.
  - `tools/check_original_assets.sh` no excluye `terrain.glb` (desde 035c).
- **Para el usuario en el editor:** mover un edificio o una planta en `high_noon_layout.tscn` y ver que en partida aparece en el lugar nuevo.

### F197 — Limpieza sin cambio de comportamiento (RFC-036, corte 036b) — cerrado 2026-10-18

- **`DebugLog`** (`scenes/world/components/debug_log.gd`) reemplaza los 30 `static var log_*` del código de juego. Se activa con `--log=a,b` o `--log=all`. `ai_match` llama a `DebugLog.enable_bench()`, con las mismas categorías que antes.
- **Nodos de chequeo:** los nodos de chequeo de ticks y órdenes pasaron de `scenes/world/` a `debug/`. `walk_step` se queda donde está: lo usa `wizard_body.tscn`.
- **Ticks:** `MatchClock.TICKS_PER_SECOND` sale de `Engine.physics_ticks_per_second`.
- **Verificación:**
  - Los dos `grep` (`static var log_` y las referencias viejas) dan vacío.
  - `quick` PASS sin mover digests.
  - Las 5 escenas movidas cargan sin errores.
- **Pendiente:** los estáticos de comportamiento de `body_separation.gd` se van en 036f.

### F198 — Catálogo del juego en `.tres` (RFC-036, corte 036c) — cerrado 2026-10-18

- **Qué cambió:** `tools/bake_catalog.gd` hornea los JSON en `data/catalog/`, un `.tres` por tipo: 71 criaturas, 53 hechizos, 15 magos, 63 habilidades, 196 edificios y 201 tamaños. `game_catalog.tres` los reúne.
- **En partida:** `GameData` lee el catálogo, y `MapBuilding` y `BodyCatalog` leen `BuildingType` y `BodySize`. Ningún JSON del catálogo se lee desde `scenes/`. Daño, maná y demás valores se editan en el inspector.
- **Verificación:**
  - `debug/catalog_cases.gd`: CATALOG PASS, todos los valores iguales al JSON. El `.tres` de texto ordena las claves de los diccionarios y el chequeo compara el conjunto de claves.
  - `quick` PASS sin mover digests.
  - `rules_suite` PASS.
- **Riesgos:**
  - Las claves de los diccionarios quedan en orden alfabético. Si alguna lógica recorre esos diccionarios dependiendo del orden, cambiaría; `quick` y `rules_suite` no lo muestran.
  - Los tipos ahora son instancias compartidas: nada debe mutarlos en runtime.
  - Los tags que solo difieren en mayúsculas llevan el sufijo `_2` en el nombre de archivo.

### F199 — Cierre del mapa editable sin navegación (RFC-035, corte 035e) — cerrado 2026-10-18

- **`run_determinism.sh all`:** DETERMINISM PASS en fixed, stress y window, contra la base de hoy.
- **Playtest con ventana** (`agent/flows/pt035e.json`, Haiku): boot → Solo contra la IA → High Noon, unos 2 min de partida. AGENT_OK, sin `SCRIPT ERROR` ni `Failed to load`; solo los avisos de fugas al salir, que ya estaban.
- **Capturas** (`agent/out/pt035e/`): el orquestador las miró y se ven el suelo con su tema, las casas, las plantas, el altar y el mago caminando. A los farmers no se los distingue de lejos, pero el log de carga los cuenta (26).
- **Para el usuario en el editor:**
  - abrir `high_noon.tscn` y ver el terreno instanciado del `.glb` con sus tiles;
  - en `high_noon_layout.tscn`, mover un edificio o una planta y ver que en partida aparece en el lugar nuevo;
  - abrir un `.tres` de `data/catalog/creatures/` y ver que se edita.

### F200 — Navmesh horneado y versionado, todavía sin uso (RFC-035, corte 035f) — cerrado 2026-10-18

- **Qué cambió:** se agregó `NavRegion` (`MapNavRegion`, `NavigationRegion3D` `@tool`) en `high_noon.tscn`, con `data/nav/high_noon_nav.res` y `data/nav/nav_bake.tres`. Lo hornea `tools/bake_nav.tscn`, que corre como escena para que existan los autoloads y las colisiones. Las fuentes son el grupo `nav_source`: el terreno, los edificios del layout y las fuentes de maná.
- **Hash de la fuente:** queda guardado en el navmesh. Si cambia el mapa, el nodo muestra un aviso en el editor.
- **Configuración del proyecto:** `default_cell_size` 1,0, iteraciones síncronas y evasión apagada.
- **Verificación:**
  - El horneado tarda unos 2 s y usa 174 MB: 8526 polígonos.
  - `--check` dos veces seguidas da CHECK PASS con el mismo hash.
  - El dedicado imprime `nav: navmesh 8526 polígonos`.
  - `quick` PASS: NavService sigue usando NavGrid.
- **Desvíos:**
  - `cell_size` es 1,0 y no 0,5. Hornear es barato, así que si en 035g el paso del tipi queda grueso se baja a 0,5 (cambiando también `default_cell_size`).
  - Los altares aparecen en partida y no están en el horneado (035g).
  - El botón «Bake» del editor no sirve, porque `MapBuilding` no es `@tool`. Hay que usar `tools/bake_nav.tscn`.

### F201 — NavService con navmesh de Godot detrás de `backend` (RFC-035, corte 035g) — cerrado 2026-10-18

- **Qué cambió:** `NavService.backend` puede ser `grid` (por defecto) o `navmesh`, y `--nav-backend=` lo cambia.
  - Con navmesh, los caminos salen de `NavigationServer3D.query_path` sobre la región `NavRegion`, con `path_search_max_polygons = 0`.
  - Las consultas de tierra, punto más cercano y línea libre salen del índice de polígonos de `NavRegions` (`closest_land`). El `map_get_closest_point` del servidor recorre los 10.000 polígonos y tarda unos 500 µs.
  - Las islas de menos de 100 polígonos no cuentan como tierra.
  - Las estructuras que aparecen en partida (altares, Manalith, edificios destruidos) disparan un rehorneado completo en un hilo, que se cambia en un tick fijo (`nav_rebake.gd`).
- **Horneado:** `cell_size` 0,5, `agent_max_climb` 3,0, `agent_radius` 1,0. Da 10.667 polígonos, la región principal tiene 10.571 y no hay errores de unión de bordes.
- **Configuración del proyecto:** `world/region_use_async_iterations=false`; sin eso, Godot 4.7 sincroniza las regiones varios frames tarde y las consultas devolvían vacío.
- **Arreglos que también tocan la grilla:**
  - Los voladores puros (`running_speed` 0, sin hijo `Flight`) van en línea recta y no planifican, también con `grid`.
  - `nav_flyer` antes fallaba en los dos backends.
- **Verificación con navmesh:**
  - `rules_suite`: RULES SUITE PASS, con todos los `nav_*`.
  - `crowd_rock`: PASS, 0 trabadas, p95 262 µs.
  - `nav_flyer`: PASS.
  - `s7_navmesh` fixed = fixed2: digest `5dfaa544…`.
  - `quick` (grid): PASS.
- **Abierto:** `crowd_tipi` con navmesh deja 2 criaturas trabadas unos 3,7 s cerca del destino. Las encierran las que ya llegaron a su lugar de la formación: es un problema de multitud (`MakeWay`), no de caminos. Con la grilla da 0. El reemplazo de `MakeWay` y `BodySeparation` por la evasión de Godot es 036f.
- **Deuda:** `line_clear` muestrea cada 1 m, así que las líneas largas cuestan milisegundos. El p95 de `crowd_tipi` (277 µs) está cerca del tope de 300.

### F202 — El navmesh pasa a ser la navegación por defecto (RFC-035, corte 035h) — cerrado 2026-10-18

- **Qué cambió:** `NavService.backend` = `NAVMESH` por defecto.
- **Base regrabada una vez** (`det_baseline.txt`, 8 casos), sin ceremonia, según RULES §Fidelidad y pruebas. Cambiaron `s7`, `s1_quick`, `f125`, `f129`, `f130`, `f132` y `f155`; la causa es el pathfinder nuevo.
- **Verificación:**
  - Antes de regrabar, cada caso dio el mismo digest en todos sus modos. `s1_quick` dio igual en fixed, stress y window, y `s7` coincide con `s7_navmesh` (fixed = fixed2).
  - Después de regrabar, `quick` PASS.
  - `rules_suite` con el valor por defecto: PASS.
- **Abierto:** `crowd_tipi` (2 trabadas unos 3,7 s, ver F201). Se resuelve con la evasión de Godot en 036f.

### F203 — Fuera la grilla de navegación (RFC-035, corte 035i) — cerrado 2026-10-18

- **Qué se borró:** `nav_grid.gd` y el selector `backend` / `--nav-backend`. Desde ahora `NavService` tiene un solo dueño, el navmesh (`NavMeshBackend`, `NavRegions`, `NavBoxBlockers`, `NavRebake`).
- **Pruebas que se cambiaron:** los chequeos que solo tenían sentido con la grilla pasan a probar `NavBoxBlockers` (`nav_box_corner`, `nav_box_blockers`). `nav_grid_build` pasa a llamarse `nav_build`.
- **Verificación:**
  - El `grep` de `NavGrid`, `AStarGrid2D` y `nav-backend` en `scenes`, `debug` y `tools` da vacío.
  - `quick` PASS sin regrabar.
  - `rules_suite` PASS.
  - `crowd_rock` PASS, 0 trabadas.
  - `nav_flyer` PASS.
- **Abierto:** `crowd_tipi` sigue igual (2 trabadas unos 3,7 s, 036f).

### F204 — Cierre de RFC-035 (corte 035j) — cerrado 2026-10-18

- **Documentación:**
  - RULES §Datos: el mapa y la navegación son de Godot, y ya no hay grilla propia.
  - `assets/original/README.md`: cómo editar el terreno, el material, el contenido, la navegación y el catálogo.
  - Notas de reemplazo en F72 y F88.
- **Banco:** `run_determinism.sh all`, DETERMINISM PASS.
- **Playtest con ventana** (`agent/flows/pt035j.json` en `debug/village.tscn`, orquestador; AGENT_OK, sin errores):
  - **Orden 1** a (1300, 1260): el Hunter llega a (1299,9; 1259,9).
  - **Orden 2** a (1420, 1340): el destino está del otro lado de un barranco. El Hunter lo rodea por la cresta y a los 10 s sigue caminando, sin trabarse.
  - **Orden 3** hacia el tipi: avanza hasta (1480, 1334).
  - El rehorneado en partida tarda 511 ms en un hilo.
  - Capturas en `agent/out/pt035j/`.
- **Abierto:**
  - `crowd_tipi` (2 trabadas unos 3,7 s) queda para 036f.
  - Falta confirmar en el editor lo de F199.

### F205 — Tope de criaturas por jugador (RFC-036, corte 036d) — cerrado 2026-10-18

- **Qué cambió:** `MatchRules.max_creatures_per_player` (0 = sin tope, valor por defecto) se edita en el inspector.
- **Rechazo:** `Caster.summon_status` devuelve «Límite de criaturas» antes que cualquier otro rechazo, y lo hace antes de `begin`, así que no cobra maná ni almas. La IA lo respeta porque pasa por `request_summon`.
- **Qué cuenta:** las unidades vivas del slot del jugador, incluida la que se está convocando. No cuentan el mago, los NPC ni los muertos.
- **El tope de selección** sigue siendo `Selection.max_size`, por escena.
- **Verificación:**
  - `debug/creature_cap.tscn` (tope 3): CREATURE_CAP PASS. La 4.ª convocatoria se rechaza sin gastar nada, y después de morir una criatura se puede convocar otra vez.
  - `rules_suite` PASS.
  - `quick` PASS sin regrabar.

### F206 — Fuera SacFloat (RFC-036, corte 036e) — cerrado 2026-10-18

- **Qué se borró:** `sac_float.gd`. `Affliction.cc_ticks` y `QuakeWave` usan los floats de GDScript.
- **Verificación:**
  - El `grep` de `SacFloat` da vacío.
  - `rules_suite` PASS, sin adaptar casos.
  - `quick` PASS. Cambió el digest de `f149` (congelamiento) por float64: `bf28b3fd` → `8a2bcf47`. Antes de regrabar dio el mismo digest en fixed y fixed2.

### F207 — Evasión de Godot en lugar del empuje propio (RFC-036, corte 036f) — cerrado 2026-10-18

- **Qué se borró:** `BodySeparation`, `BodyGrid` y `MakeWay`, unas 850 líneas copiadas de `positionAfterCollision`.
- **Qué lo reemplaza:**
  - Cada criatura, mago y doctor tiene un hijo `Avoidance` (`body_avoidance.tscn`, NavigationAgent3D). El radio y la altura salen de la caja de antes (`BodyBox`).
  - Prioridad: el mago vale 0,9 cuando se mueve y 0,75 quieto. Una criatura vale 0,5 caminando y 0,25 quieta. Congelados y petrificados valen 1,0. Esto reemplaza `wizard_passes_own`.
  - `velocity_computed` pasa a `move_and_slide` en el mismo paso de física.
- **Configuración del proyecto:** la evasión corre en el hilo principal (`avoidance_use_multiple_threads=false`), para ser determinista.
- **Verificación:**
  - `rules_suite` PASS.
  - `crowd_tipi` PASS: 0 trabadas en 19,05 s (antes, 2 trabadas en 20,85 s).
  - `crowd_rock` PASS: 11,5 s.
  - `crowd_150`: +1,6 % de tiempo.
  - `escort_jam`: 6 de 6 tramos, y el mago no retrocede.
  - `retreat_spacing` (Ctrl+Espacio con 4 Trogg): 1,39 m entre ellos.
  - `run_034e` (partida con dedicado): E2E PASS.
  - Flow `final_separation` con ventana: AGENT_OK.
  - `quick`: PASS después de regrabar 15 casos por la evasión, cada uno igual en fixed y fixed2 antes de regrabar.
- **Cambios de comportamiento:**
  - Las criaturas que se corren para dejar pasar no vuelven a su lugar: quedan desplazadas hasta unos 1,1 m. Los `crowd_return*` ahora miden `stay_near` (3,5 m).
  - La distancia de reposo pasa a ser `r_a + r_b`, sin los 0,1 m de holgura de antes.
- **Gotchas de Godot 4.7.2:**
  - `NavigationAgent3D.velocity` no entrega nada; hay que usar `NavigationServer3D.agent_set_velocity`.
  - En modo `--script` no se emite `velocity_computed`.
  - El ajuste es caótico: `neighbor_distance` 3,0 y `time_horizon_agents` 1,0.
- **Sin review separada:** la reemplazan las pruebas de arriba, incluida la de red.
- **Deuda:** la columna «separation» de `run_perf027.sh` quedó vacía.

### F208 — Animación editable en el editor (RFC-036, corte 036g) — cerrado 2026-10-18

- **Qué hay ahora:** `scenes/world/body/models/<tag>.tscn`, una por modelo (73), generada una vez por `tools/bake_body_scenes.gd`. La raíz es un `BodyModel` (`body_model.gd`, `@tool`) con:
  - `Model`: el `.glb` instanciado (z espejada).
  - `Tree`: un `AnimationTree` guardado. Su `AnimationNodeStateMachine` tiene un estado **por rol** (idle, run, attack, death...) y cada estado reproduce el clip del `.glb` que ese rol usa. Ese es el mapeo rol → animación: se cambia en el editor.
  - `Events`: un `AnimationPlayer` con una animación por clip que tiene eventos de SKEL. Una pista de método llama `ClipEvents.fire(kind)` en el cuadro de cada evento. La clave `attack` es el momento visual del impacto.
  - En el inspector: `preview_role` (se ve el rol en el editor), `aabb_margin`, y lo horneado (`bind_aabb`, `surface_parts`, `clips` con cuadros, fps y manos).
- **Los 11 híbridos** (`baby ban2 bane faez gamm hoom sara sirc surt the2 thes`) no tienen escena: no tienen idle de más de un cuadro y siguen siendo mallas estáticas, como antes.
- **BodyRig y BodyVisual:** `BodyRig` instancia la escena del modelo bajo `%ModelSlot` y le pide al árbol `travel` a un rol. Ya no arma el modelo ni la librería `role/*` en tiempo de ejecución con `owner = null`. `BodyCatalog.has_skeletal` pregunta por la escena.
- **Se borró:** `ClipClock`, `UnitClipRoles`, `BodyClips` (+ `data/bodies/clips/*.tres`) y `OriginalAssets.models_index`. La regla de qué clip usa cada rol (CreatureType, WizardType y las tres obras del Sac Doctor) se aplicó una vez en `bake_body_scenes.gd` y quedó guardada en las escenas.
- **`index.json`:** ya no lo lee ningún script de `scenes/` ni de `debug/`. Solo `bake_body_scenes.gd` y las auditorías de `tools/` (que comparan con la exportación). Lo sigue escribiendo `tools/export_skeletal.py`.
- **La sim no leía la animación:** `grep` de `impact_frame`, `active_frame`, `clip_looped`, `has_role` en `units/`, `spells/` y reglas: solo presentación (variante de gesto, de cower, secuencia del cautivo, tween del cadáver, `Stunned`). El dedicado no carga mallas: ahora no reproduce clips ni emite `clip_looped`, y `has_role` responde false. Los tiempos del cadáver y de `Stunned` salen de los ticks, no del clip, así que no cambian.
- **`clip_looped`** lo emite `BodyAnimator` en el tick de física en que la posición del clip del rig retrocede (solo cliente).
- **Cambio visual conocido:** en los clips que repiten, el último cuadro se sostiene 1/fps en lugar de mezclarse con el primero (es el cuadro a cuadro del original; el resto de la pose es igual).
- **Verificación:**
  - Import limpio.
  - `agent/f208/f208_poses.tscn` (ventana): pose del esqueleto de cada (modelo, rol) a 0, 0,37 y 0,9 s, antes y después: 2010 de 2175 iguales, y las 165 distintas son todas posiciones al final o pasado el largo del clip (6 dentro del último cuadro), donde `pose_at` antes repetía y ahora sostiene.
  - `rules_suite` PASS.
  - `run_determinism.sh quick` PASS, los 27 digests de la base sin regrabar (la primera corrida falló solo por CONTAMINATED: había una `rules_suite` en paralelo).
  - `f208_anim_wizard_trogg.json` (idle, run, attack): diferencia media de píxeles contra antes 0,21 / 0,06 / 0,05 de 255; `impact 15` en el ataque del Trogg viene de la pista de método. `f17_gallery.json`: 0,000 (solo muestra mallas estáticas).
- **Sin review separada** (solo la pide el RFC para 036f, 036g y 036j; queda para el orquestador).

**Cierre F208 (orquestador, 2026-10-18):**
- `run_034e` (partida con dedicado): E2E PASS.
- Partida real con ventana (`pt035e.json` → `agent/out/pt036g/`): AGENT_OK, sin errores, con el mago animado.
- Sin review separada; la reemplazan las pruebas.
- **Para el usuario en el editor:** abrir `scenes/world/body/models/eorc.tscn` (el Trogg), elegir `Tree` y previsualizar los roles.

### F209 — Fuera GroundGuard (RFC-036, corte 036h) — cerrado 2026-10-18

- **Qué se borró:** `GroundGuard`, la copia de `moveOnGround` con 8 deslizamientos y restauración de posición.
- **Qué lo reemplaza:** `EdgeClamp.clamp_velocity` corre antes de `move_and_slide`. Primero consulta el terreno, una búsqueda O(1). Solo si el paso siguiente cae en un hueco, lo recorta al punto de tierra del navmesh más cercano.
- **Tumbling:** los cuerpos lanzados no se recortan, así que siguen cayendo y muriendo.
- **`FallCheck`** conserva `has_fallen`, `terrain_of` y `altar_return_spot`.
- **Verificación:**
  - El `grep` de `GroundGuard` da vacío.
  - `rules_suite` PASS.
  - `edge_pushed_stays` y `edge_thrown_falls` PASS (en `nav_cases`, con un caso de control sin recorte que sí cae).
  - `crowd_tipi` y `crowd_rock` PASS.
  - `quick` PASS sin mover digests.

### F210 — Partículas con textura en el `.tres` y piezas de UI como escenas (RFC-036, corte 036i) — cerrado 2026-10-18

- **Partículas:** `ParticleType.atlas` es un `Texture2D`, en lugar de una clave de `fx.json`. `tools/migrate_particle_atlas.py` migró 45 `.tres`. En partida ya no se lee `fx.json`.
- **UI:** `SelectionRoster` y `SpellBook` instancian `frame_piece.tscn` y `roster_plate.tscn`, con el StyleBox guardado en la escena, en lugar de armarlos por código.
- **Verificación:**
  - `rules_suite` PASS.
  - `quick` PASS sin regrabar.
  - El HUD (`f210_roster`) recortado al panel da 0,0003 y 0,0016.
  - `f23_fx_gallery` antes/después da 0,5, 2,9 y 4,3. Entre dos corridas iguales da 0,7 a 1,0, por la aleatoriedad de las partículas. Al ojo, las capturas lado a lado son iguales.
- **Deuda:**
  - El flow `f24_cast` se trabó después de la segunda captura. No se investigó: puede ser que el flow esté desactualizado o un problema real.
  - `f79_roster` falla también sin cambios, porque espera `ImageTexture`.

### F211 — Cierre de RFC-036 (corte 036k) — cerrado 2026-10-18

- **RULES §Fidelidad:** evasión, animación por escena, catálogo y partículas en `.tres`.
- **Banco:** `all` DETERMINISM PASS.
- **Playtest con ventana:** partida Solo contra la IA en High Noon (`agent/out/pt036k/`), AGENT_OK y sin errores.
- **Diferidos:**
  - 036a: el mago IA trabado en el Manalith; hay que revisarlo jugando.
  - 036j: la FSM; necesita el OK del usuario.

### F212 — Terreno del minimapa horneado (RFC-037, corte 037a) — cerrado 2026-10-18
### F213 — Minimapa visible (RFC-037, corte 037b) — cerrado 2026-10-18

- **Horneado del terreno:** `MinimapTerrainBake` es un SubViewport con mundo propio y cámara ortográfica. Usa luz ambiente 0,7 en lugar de UNSHADED, que no existe en un export de release. Se dibuja una sola vez, con 1024 px.
- **`Minimap`** (`scenes/ui/minimap/`, en `Hud/Minimap`):
  - círculo abajo a la derecha con el marco `fram`, escalado con `HudScale`;
  - gira con la cámara, y hay un knob para dejar el norte arriba;
  - cuña de visión, iconos del atlas `mmic` (exportado con `tools/import_ui.py`) con el color de cada lado, y flechas en el borde para lo propio que queda fuera del círculo;
  - el estilo y la vista son `.tres` en `data/ui/minimap/`.
- **Verificación:**
  - Flow `f037_minimap` con ventana: AGENT_OK. El icono del mago queda a 0 px de lo esperado, y el giro de la cámara se refleja en los iconos.
  - `rules_suite` PASS.
  - `quick` PASS.
  - `run_034e` (dedicado): E2E PASS.
  - Capturas en `agent/out/f037b/`.
- **Pendientes:**
  - La entrada (clic y zoom) es 037c.
  - El sigilo no se replica al cliente (R2), así que el minimapa del rival mostraría a un enemigo invisible. Se resuelve en 037c o aparte.
  - Falta comparar el tinte gris del original en 037d.

### F214 — Entrada del minimapa y sigilo replicado (RFC-037, corte 037c) — cerrado 2026-10-18

- **Entrada:**
  - La rueda sobre el círculo hace zoom en el minimapa y no en el mundo (`WorldCamera.wheel_blockers`).
  - `M` (`minimap_toggle`) muestra y oculta el minimapa.
  - El clic derecho da la orden de mover ahí, por `Orders.request` y `submit_order`.
  - El clic izquierdo con algo armado apunta ahí o al cuerpo más cercano. Sin nada armado no hace nada.
  - El clic no mueve la cámara (P1, como el original).
- **Sigilo:** `_stealth` se replica (`unit.tscn`, ON_CHANGE). El setter aplica el desvanecido en cada peer, y en el cliente el enemigo con sigilo deja de ser apuntable y desaparece del minimapa.
- **Verificación:**
  - `MINIMAP_INPUT PASS`. El grupo ordenado desde el minimapa queda a 0,09 m del punto.
  - `run_034e` E2E PASS.
  - Prueba de sigilo en red (`agent/f037c/stealth_net.tscn`): AGENT_OK. No se probó contra el código viejo.
  - `rules_suite` PASS.
  - `quick` PASS.
- **Abierto:** desde el minimapa todavía no se apuntan hechizos sobre almas ni edificios propios («Sin blanco»).

### F215 — Cierre de RFC-037 (corte 037d) — cerrado 2026-10-18

- **Partida con ventana** (`pt035e` → `agent/out/pt037d/`): AGENT_OK, sin errores. El minimapa aparece abajo a la derecha, con el terreno, la cuña de visión, el mago, el altar y el manantial.
- **Banco:** `all` DETERMINISM PASS.
- **Para el usuario:**
  - comparar el tinte gris con el original;
  - decidir si el clic en el minimapa debería mover la cámara (hoy no la mueve, como en el original).

### F216 — Formaciones como Resources (RFC-038, corte 038a) — cerrado 2026-10-18
### F217 — Formación guardada en el servidor (RFC-038, corte 038b) — cerrado 2026-10-18

- **Formaciones:** los scripts `RowFormation`, `ArcFormation` y `WedgeFormation`, más 8 `.tres` en `data/orders/`: line, flank_left, flank_right, phalanx, semicircle, circle, wedge y skirmish. Todas están en `formations.tres` (`FormationCatalog`). `line.tres` reproduce exactamente el `_formation` de antes.
- **Servidor:**
  - El comando `"formation"` valida el id contra el catálogo y lo guarda en el `UnitOrders` de cada criatura. No mueve a nadie.
  - La orden siguiente usa la formación que tiene la mayoría del grupo; si hay empate, gana la que va primero en el catálogo.
  - `submit_order` suma el argumento `formation_id`.
  - La IA sigue en línea.
- **Verificación:**
  - `formation_slots` PASS: line es idéntica, y las otras 7 se comparan contra las fórmulas de `getFormationOffsets`.
  - `formation_server` PASS: con cuña, cada unidad queda a 1 m o menos de su lugar, y gana la mayoría.
  - `run_034e` E2E PASS.
  - `rules_suite` PASS.
  - `quick` PASS.

**Verificación del usuario en el editor (2026-10-18):** OK en los cuatro puntos: el terreno `.glb` en `high_noon.tscn`, un edificio movido en `high_noon_layout.tscn` que aparece en partida, las animaciones de `models/eorc.tscn` y la edición de `data/catalog/`. Cierra lo pendiente de F195, F196, F199 y F208.

### F218 — Menú radial (RFC-038, corte 038c) — cerrado 2026-10-18
### F219 — Menú radial integrado al botón derecho (RFC-038, corte 038d) — cerrado 2026-10-18

- **`RadialMenu`** (`scenes/ui/radial/`, `data/ui/radial/`):
  - tiene dos anillos con los iconos del original: las órdenes adentro y las 8 formaciones afuera;
  - abre con escala y fundido (0,12 s) y cierra con fundido;
  - la opción bajo el cursor crece 1,3× y brilla, se rellena su sector y una línea apunta desde el centro;
  - en el centro aparece el nombre en español, y para las formaciones un dibujo de 8 puntos;
  - los parámetros se ajustan con `@export` y en `RadialLayout`.
- **`OrderRadial`** es el único dueño del botón derecho:
  - un toque corto da la orden como antes;
  - mantenerlo 0,25 s abre el menú en ese punto, y al soltar sobre una formación las unidades van ahí con esa formación, en un solo `submit_order`;
  - mantener `Tab` hace lo mismo en el puntero;
  - soltar en el centro cancela;
  - `Alt+1` a `Alt+8` solo cambian la formación.
- **Arreglo de F80:** se borró el ciclo de `Tab` que no hacía nada.
- **Verificación:**
  - `radial_layout` PASS (ángulo a opción).
  - `RADIAL_PROBE` PASS con entrada real en `debug/orders_radial.tscn`: 8 Trogg en cuña en el punto, a 0,58 m de su lugar como máximo.
  - `run_034e` E2E PASS.
  - `rules_suite` PASS.
  - `quick` PASS.
- **Deuda:**
  - `f80_cues_orders` y `f80_hud_text` fallan igual con el código anterior: las aserciones son viejas.
  - `rfc033_shots` no terminó en 10 min.
  - El menú dibuja texto con `draw_string`, a pedido del usuario.

### F220 — Marcador de orden del original (cerrado 2026-10-18)

- **Qué cambió:** se fue el cilindro naranja de depuración. `OrderMarker` (`scenes/fx/order_marker.{tscn,gd,gdshader}`) reproduce el «command cone» del original: un cono aditivo con la textura `aura`, más 8 capas blancas que giran.
- **Cómo se ve:** dura 0,5 s. Al desaparecer se ensancha de 1 a 3 en horizontal y de 1 a 1,25 en vertical. Es blanco por defecto, rojo para atacar o avanzar y azul para guardia.
- **Fuentes en sacengine:** `state.d:29261`, `sacobject.d:4483`, `renderer.d:3690`.
- **Detalles:**
  - No es humo ni partículas: en el original es una malla.
  - Se agregó `aura` a `tools/import_ui.py`.
  - El nodo se sigue llamando `%Ping`, porque lo usan varios flows.
- **Verificación:**
  - Flow `f220_order_marker` con ventana: AGENT_OK. El cono rojo aparece y a los 3 s ya no está.
  - `rules_suite` PASS.
  - `quick` PASS.

**Decisiones del usuario (2026-10-18):**
- 036j va: `UnitBody` pasa a FsmKit, y se puede modificar el addon FsmKit si hace falta (el repo es del usuario).
- 036a queda cerrado sin corte.
- El clic en el minimapa sigue sin mover la cámara.
- El tinte del minimapa queda cerrado; las mejoras visuales vienen después.

### F221 — `UnitBody` con FsmKit (RFC-036, corte 036j) — cerrado 2026-10-18

- **Estados:** los modos son nodos `UnitState` (FsmKit) bajo `unit.tscn/States`, uno por script en `scenes/world/units/states/`: Idle, Move, Chase, Attack, Shoot, Cower, RockForm, Summoning, Dead, Held y Reviving. Las transiciones son por nombre de nodo.
- **Modo replicado:** `UnitBody.mode` sigue siendo la propiedad replicada y el único escritor, y su setter mueve la máquina. `physics_update` corre solo en el peer que simula, en el mismo punto del paso de física, así que no cambia el orden.
- **Piezas separadas:** `UnitAir` (vuelo), `UnitClips` (animación) y `TargetRules` (`is_valid_foe_of`).
- **Tamaño:** `unit_body.gd` pasa de 1068 a 720 líneas. Lo que queda es la API pública y el paso de física.
- **Verificación:**
  - `rules_suite` PASS.
  - `quick` PASS sin regrabar.
  - `crowd_tipi` y `crowd_rock` PASS.
  - `run_034e` E2E PASS.
  - Flow `final_separation` con ventana: AGENT_OK, idéntico al código anterior (`agent/out/pt036j*`).

### F222 — Flows de prueba al día (deuda, cerrado 2026-10-18)

Todos fallaban por aserciones viejas; ninguno por un bug del juego.

- **`f80_cues_orders` y `f24_cast`:** el Druid quedaba detrás del mago, en el centro de la pantalla. Ahora giran la cámara y apuntan con `aim_body`. En `f24`, el `click %View` (centro de la vista) pasó a `press select`, que usa el puntero forzado.
- **`f80_hud_text`:** se partió en 5 flows, uno por escena. Además, `pt121_watch.gd` ya no lee cuerpos que salieron del árbol. El flow único sigue fallando en el paso 36, en otro cambio de escena.
- **`f79_roster`:** espera `CompressedTexture2D`.
- **`f36_anim_wizard_trogg`:** en reposo, las etiquetas son `jwst` y `HUst`.
- **`rfc033_shots`:** AGENT_OK, y el cuelgue no se reprodujo.
- **`check_original_assets.sh`:** excluye `terrain.glb`.
- **Resultado:** todos los flows de arriba dan AGENT_OK.

### F184 — Reconexión, límites y VPS (RFC-034, corte 034g) — cerrado 2026-10-18

- **Lobby:** `MpLobbyClient.auto_resume` vuelve solo dentro de `resume_window_s` (120 s), con el mismo asiento y la misma sala.
- **Dedicado:** el jugador que se va vuelve con su ticket dentro de `rejoin_grace_s` al mismo slot. Mientras tanto, su mago queda quieto (`stand_still`) y sus criaturas y su altar siguen en el mundo. Pasado ese tiempo, la partida termina por abandono.
- **Token:** un tercer cliente con el ticket de alguien conectado queda rechazado.
- **UI:** botón «Volver a la partida».
- **Despliegue (escrito, sin desplegar):** `tools/deploy/room_server.service` (systemd), `tools/deploy/README.md` (export, puertos, firewall y checklist del VPS) y el preset `dedicated_server` de Linux. Es un export normal, porque el mismo binario es el servidor de salas y cada partida.
- **Verificación:**
  - `run_034g.sh` con ENet y con WS: E2E REJOIN PASS.
  - `run_034e` (ENet y WS) y `run_034m`: PASS.
  - `rules_suite` PASS.
  - `quick` PASS.
  - **Export (orquestador):** `--export-pack dedicated_server` genera un `.pck` de 247 MB. Con `--main-pack ... -- --room-server`, fuera del proyecto, arranca, imprime «salas listo puerto 7700» y escucha por UDP en el 7700, sin errores.
- **Para el usuario en el VPS:**
  - el binario de Linux en sí;
  - ver al mago y las criaturas después de volver, en un cliente con ventana;
  - una conexión medio abierta puede ocupar el slot hasta el timeout de ENet.

### F189 — Skill `godot-determinism` en español e inglés (RFC-034, corte 034l) — cerrado 2026-10-18

- **Dónde está:** en clones locales nuevos del kit, sin subir. `godot-studio-skills/rc-v0.10.0` en la rama `rc/v0.10.0` (commit `9a4030d`) y `rc-v0.10.0-spanish` en la rama `rc/v0.10.0-spanish` (commit `69acb77`).
- **Qué agrega:** `skills/godot-determinism/SKILL.md`, con 13 secciones iguales en los dos idiomas, y `reference.md`, con 11.
- **Política:** enseña la versión liviana de RULES §Fidelidad: `quick` en cada corte, `bless` cuando el cambio es intencional y fixed = fixed2 en cada caso movido.
- **README:** la sección «Determinismo» va en `example/addons/agent_kit/README.md`; en inglés el README se creó nuevo.
- **Chequeo:** el `grep` de nombres de Sacrifice da vacío.
- **Pendiente para 034h:** copiar el módulo `determinism/` y `mp_kit` al kit, y corregir `install.sh`.

### F185 — Estabilidad y port de mp_kit 0.7.0 al kit como RC (RFC-034, corte 034h, parte del servidor de salas) — cerrado 2026-10-18

- **Soak:** `agent/run_034_soak.sh [N] ["enet ws"]` corre `run_034e.sh` (dos salas 1v1 en paralelo, dos dedicados reales) y `run_034g.sh` (reconexión) con ENet y WS, de a uno, con puerto de lobby rotativo, tope externo de 300 s por corrida (kill por pid) y chequeo de procesos Godot nuevos y carpetas temporales que sobren.
- **Fuga al kit:** se sacó la mención de Sacrifice en `lobby/mp_lobby_config.gd` y se pasaron a inglés dos `print` de `mp_lobby_client.gd`. `rg` de nombres del juego en `addons/mp_kit` queda vacío (solo `Godot`, `godot-studio` en `plugin.cfg`).
- **Docs:** `addons/mp_kit/README.md` suma «Servidor de salas» (admisión y tickets, salas, `MpMatchLauncher`, ENet/WS, reconexión, despliegue) y se borra «un proceso Godot por partida» de «Qué no hacer». `plugin.cfg` 0.7.0; RULES §Stack al día.
- **Kit (local, sin subir):** `godot-studio-skills/rc-v0.10.0` (`ecb66dd`) y `rc-v0.10.0-spanish` (`0fa7a1d`): `mp_kit` en `addons/` y `example/addons/`, `determinism/` en `example/addons/agent_kit/`, README ES/EN, skill `godot-mp-kit` e `install.sh`.
- **Pendiente:** playtest de 034f sobre el `main` final, `quick` x3 y `det_selftest` (los pide §15.6, no este corte); escena mínima de salas en el `example/` del kit; subir AgentKit 0.2.0 a `godot-studio-playtest`; los push los hace el usuario.


**Cierre de F185 y RFC-034 (orquestador, 2026-10-18):** criterio de estabilidad de §15.6 completo.
- `run_034_soak.sh 3`: 12 de 12 corridas en PASS (034e y 034g, con ENet y con WS), sin huérfanos.
- `quick` 3 de 3 en PASS.
- `det_selftest`: SELFTEST PASS.
- `run_pt034f` (playtest de red con ventana): PT034F PASS.
- **RC del kit:** queda en commits locales, `rc/v0.10.0` (`ecb66dd`) y `rc/v0.10.0-spanish` (`0fa7a1d`). El push y el merge los decide el usuario. Antes hay que subir AgentKit con el módulo de determinismo a `godot-studio-playtest` `rc/v0.10.0`.

**RC publicado (2026-10-18, con OK del usuario):**
- `godot-studio-playtest`, rama `rc/v0.10.0` (`7aadf9e`): AgentKit con el módulo de determinismo.
- `godot-studio-skills`, ramas `rc/v0.10.0` (`ecb66dd`) y `rc/v0.10.0-spanish` (`0fa7a1d`).
- Para instalar el RC con su AgentKit: `GODOT_STUDIO_PLAYTEST_REF=rc/v0.10.0 ./install.sh`.
- El merge a `main` y a `release/spanish` lo decide el usuario.

### F223 — Minimapa más cerca del original (cerrado 2026-10-18)

Referencias de sacengine: `renderer.d:4459-4760` y `minimap.d`.

- **Terreno:** lleva el tinte gris 0,5 del original (`ground_tint` 0,714 sobre la luz ambiente 0,7 del horneado) y filtro lineal, así que la costa ya no se ve escalonada.
- **Criaturas y almas:** tamaño 2,0, antes 2,5.
- **Cuña de visión:** se dibuja antes que los iconos, así que el mago la tapa.
- **Brújula:** apareció la gema del marco (`fram.png`), que marca el norte y gira con el mapa.
- **Verificación:**
  - Flow `f037_minimap` AGENT_OK: el mago queda a 0 px de lo esperado.
  - `quick` PASS.
  - Capturas de antes y después en `agent/out/f223/`.
- **Fuera:** el parpadeo de alerta, los resaltados y la niebla.

### F224 — El catálogo se lee de los `.tres` sueltos (RFC-040, corte 040a) — cerrado
### F225 — Validador de contenido (RFC-040, corte 040b) — cerrado

- **Una sola fuente de verdad:** `GameCatalog` recorre `data/catalog/{creatures,spells,wizards,abilities,buildings,body_sizes}/*.tres` y los ordena por tag. Se borró `game_catalog.tres` (346 KB, tenía los 599 tipos embebidos y por eso editar un archivo suelto no tenía efecto).
- **Agregar contenido:** basta con soltar un `.tres` en la carpeta; no hay que registrarlo.
- **Libros:** están en `data/catalog/books.tres` (`GodBooks`).
- **`bake_catalog.gd`:** escribe solo los archivos sueltos y, sin `--force`, no pisa las ediciones.
- **Prueba de aceptación** (`debug/catalog_edit_cases.tscn`): la vida de EHTH pasa de 2080 a 14425 en su `.tres`, el juego lee el valor nuevo y después se restaura.
- **Validador** (`debug/catalog_cases.gd`):
  - revisa referencias, tags duplicados, rangos, nombres de archivo y `BodySize`;
  - un cambio de balance da PASS;
  - un archivo roto da FAIL nombrando archivo y campo.
- **Verificación:**
  - `quick` PASS sin regrabar.
  - `rules_suite` PASS.
- **Conocido:** `tsg@`, una referencia colgante que ya estaba en los datos originales, queda en la lista permitida.
### F230 — Hechizos y proyectiles como escenas (RFC-041, cerrado 2026-10-19)

Agregar o cambiar un hechizo de combate ya no toca `caster.gd`.

- **041a:** `class_name` en `Caster`, `Spellbook` y `Summoner`; sockets y llamadas tipadas (`match_command`, `hand_fx`, `ai_command_port`, `wizard_body`, `wizard_brain`) en lugar de `call()`.
- **041b..h:** los 7 hechizos de combate son `SpellAction` bajo `Caster/Actions`, una escena cada uno en `scenes/world/spells/actions/`: `pups_action` (Speedup), `heal_action`, `rock_action`, `wrath_action`, `fireball_action`, `swarm_action` y `lightning_action`. Wrath, Fireball y Swarm comparten `thrown_action.gd`. La base `AimedAction` tiene los chequeos comunes (enfriamiento y maná, blanco válido, alcance) y `SpellAction` ganó el gancho `started()`, que corre justo después de arrancar el cast. Se borraron `IMPLEMENTED`, las constantes de tag y todas las ramas `spell.tag ==` de `Caster`.
- **`SpellType.action`:** `@export var action: PackedScene` nuevo (default vacío). Si el mago no tiene un hijo para el tag, `Caster.action_for` instancia esa escena. Un hechizo nuevo es un `.tres` más una escena. Todavía no se cargó en ningún `.tres` del catálogo, para no chocar con el cambio de carga del catálogo.
- **041i:** proyectiles y efectos como `.tscn` (`rock_projectile`, `wrath_strike`, `fireball_projectile`, `swarm_projectile`, `heal_effect`, `speedup_effect`). `SpellSpawner` (`class_name`) los toma de `projectiles`, un `Dictionary[String, PackedScene]` exportado, con `spawn_projectile(kind, data)`; ya no hay `script.new()`. Base `SpellProjectile` con `setup()`.
- **Verificación:** import limpio; `rules_suite` PASS; `quick` sin regrabar.
