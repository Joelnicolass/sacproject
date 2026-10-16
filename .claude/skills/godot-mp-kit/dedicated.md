# Dedicated server (online / VPS)

Godot 4: **el mismo proyecto** es servidor y cliente. El servidor dedicado no es otro repo. Docs: [Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

## Modelo

```
[VPS / editor headless]   MpKit.host_dedicated()   peer 1, local_slot() == 0, sin pawn
[Cliente]                 MpKit.join(ip)           slot 1..N, submit_* hacia peer 1
[1P]                      no host()                OfflineMultiplayerPeer
[LAN]                     MpKit.host()             listen-server, el host sí es jugador
```

ENet UDP alcanza en internet si el servidor tiene **IP pública** (o puerto reenviado) y el firewall abre el puerto. Eso es “online” en este kit. Un `host()` listen detrás de NAT **no** es online.

Varias salas concurrentes en **un** proceso dedicated (`MpRoomDirectory` / `MpMatchmaker`) **sí son el kit**. Steam, WebRTC y process-per-match (un proceso Godot por partida) siguen fuera.

## Cómo se desarrolla (igual que producción)

No programes listen-server y “después lo pasamos a VPS”. Si eligieron **online**, el camino feliz es dedicated + clientes desde el día uno.

Local:

```bash
# Servidor (sin ventana). --dedicated es user arg (después de --).
godot --headless --path . -- --dedicated

# Clientes: otra instancia, Join 127.0.0.1
```

En el editor: Debug → Customize Run Instances / Ejecutar Instancias. `MpBoot.is_dedicated_process()` es true con:

- etiqueta de característica **`dedicated_server`** (o `dedicated`) en **esa** instancia
- `--dedicated` en args de línea (user args `-- --dedicated` **o** el flag suelto; el kit lee `get_cmdline_args` y `get_cmdline_user_args`)
- export **Dedicated Server** → `OS.has_feature("dedicated_server")`

Si «Anular Argumentos Principales» está **desmarcado**, Godot **puede ignorar** los Argumentos de Inicio de esa fila. Marcá anular en la instancia hub, o usá la etiqueta `dedicated_server` (las etiquetas se combinan aunque no anules).

**No** uses solo `--headless` como señal: GUT/CI también van headless, y un cliente headless no abre el puerto.

Puerto opcional en glue: `int(MpBoot.user_value("mp-port", "7777"))`.

## Glue al arrancar

```gdscript
func _ready() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, 4, 1)
	# signals…

	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)
			return
		# sin menús; el mundo se carga cuando la política de ronda lo diga
		return

	# cliente / 1P: lobby, Join, o jugar solo
```

HUD: si `MpKit.local_slot() == 0`, no hay jugador local (proceso dedicated). No leas `get_unique_id() == 1` como “soy el player 1”.

Spawn: `for slot in MpKit.occupied_slots()`. Dedicated no incluye peer 1. Listen: el host slot sí está ocupado.

`rpc_load_world` es `call_remote`: el servidor **no** lo recibe. Dedicated también entra al mundo por glue (`goto_world()`), igual que el listen host.

## Export y VPS

1. Preset Linux (típico en VPS). Resources → **Export Mode: Export as dedicated server**. Eso fuerza headless y el feature `dedicated_server`. Podés strippear texturas/audio.
2. Exportá el binario. En la VPS: UDP `port` abierto (firewall / security group). Bind es `0.0.0.0`.
3. Corré el binario (el preset dedicated ya va headless). Clientes: `join(IP_PUBLICA)`.
4. systemd o Docker: un proceso, un puerto. Varias hub rooms en ese proceso (`MpKit.rooms`). Un proceso por match o Steam: fuera del kit.

Misma escena, mismos `submit_*`, misma autoridad. El servidor simula; los clientes pintan.

## Anti-patrones

- Dedicated que spawnea un pawn para sí (`local_slot() == 0`).
- Desarrollar solo con `host()` listen y esperar que eso corra en la VPS sin jugador.
- Tratar `--headless` de tests como dedicated.
- Steam o un proceso Godot por partida metidos en `mp_kit.gd` (las salas in-process ya están en `MpKit.rooms`).
- Segundo proyecto “solo server”.
