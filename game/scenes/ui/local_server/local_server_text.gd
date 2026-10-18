class_name LocalServerText
extends RefCounted

## RFC-034 034m: every text of the «Servidor local» screens that is not a label of a scene. Pure functions: no node.

const TITLE := "Servidor local"
const RANDOM_GOD := "Dios del rival: Aleatorio"
const GOD_PREFIX := "Dios del rival: %s"
const STARTING := "Preparando el servidor…"
const INFO_ADDRESS := "Dirección local: %s"
const INFO_NO_ADDRESS := "Dirección local: no encontré una (usá la de tu túnel o VPN)"
const INFO_PORT := "Puerto: %d"
const INFO_TRANSPORT := "Transporte: %s"
const INFO_CODE := "Código del rival: %s"
const COPIED := "Copiado al portapapeles."
const HELP_HOST := "Pasale a tu rival la dirección, el puerto, el transporte y el código. En la misma red alcanza con eso; desde Internet tenés que abrir el puerto o usar un túnel (guía: docs/servidor_local.md). Si cerrás el juego, se termina la partida."
const HELP_JOIN := "Pedile al host su dirección, el puerto y el código. El host elige tu mago y tu dios. Elegí el mismo transporte que él."
const CONNECTING := "Conectando con %s…"
const WAITING_HOST := "Estás adentro. Esperando a que el host entre a la partida…"
const BAD_ENDPOINT := "Escribí la dirección así: 192.168.1.5:7710"
const BAD_CODE := "Falta el código que te dio el host."
const FAILED_START := "No se pudo crear el servidor local. ¿Otro servidor usa ese puerto?"

const TRANSPORT_NAMES := {
	"enet": "UDP (ENet)",
	"ws": "TCP (WebSocket)",
}

const REJECTIONS := {
	"rejected": "El código no es válido, o ya lo usa otro jugador.",
	"slot_taken": "Ese asiento ya está ocupado.",
	"timeout": "El servidor no respondió a tiempo.",
	"dropped": "No se pudo entrar. Revisá la dirección, el puerto y el transporte.",
}
const REJECTION_FALLBACK := "El servidor no te dejó entrar."

const START_ERRORS := {
	"spawn_timeout": "El servidor local no arrancó a tiempo.",
	"exited": "El servidor local se cerró solo.",
	"heartbeat_stale": "El servidor local dejó de responder.",
	"match_max": "La partida duró más de lo permitido.",
}
const START_ERROR_FALLBACK := "El servidor local falló."


static func transport_name(kind: String) -> String:
	return TRANSPORT_NAMES.get(MpTransport.normalize(kind), "")


static func rejection_text(reason: String) -> String:
	return REJECTIONS.get(reason, REJECTION_FALLBACK)


static func start_error_text(reason: String) -> String:
	return START_ERRORS.get(reason, START_ERROR_FALLBACK)


static func address_text(address: String) -> String:
	return INFO_ADDRESS % address if not address.is_empty() else INFO_NO_ADDRESS


## «UDP (ENet)» / «TCP (WebSocket)» in `picker`, each item with its kind as metadata; the one of MpKit selected.
static func fill_transports(picker: OptionButton) -> void:
	picker.clear()
	for kind: String in [MpTransport.ENET, MpTransport.WS]:
		picker.add_item(TRANSPORT_NAMES[kind])
		picker.set_item_metadata(picker.item_count - 1, kind)
		if kind == MpKit.transport:
			picker.select(picker.item_count - 1)
