# Servidor local

Una partida 1 contra 1 que corre en tu propia PC, sin pasar por las «Salas online» ni por el VPS. Vos sos el host: el juego lanza un servidor dedicado en tu máquina (el mismo código que usa el VPS) y entrás como un jugador más. Tu rival se une con una dirección, un puerto y un código.

## Cómo se usa

**Host**
1. Menú, elegí tu mago y tu dios y entrá al menú principal.
2. «Servidor local» → «Crear servidor local».
3. Elegí el transporte (UDP por defecto). Tu rival elige su propio mago y su dios al unirse.
4. «Crear». La pantalla muestra **la dirección local, el puerto, el transporte y el código del rival**. «Copiar dirección y código» los deja en el portapapeles.
5. Pasale esos datos a tu rival y tocá «Entrar a la partida». La partida arranca cuando el rival entró, mandó su personaje y los dos cargaron el mundo.

**Rival**
1. Menú → «Servidor local» → «Unirse a servidor local».
2. Elegí tu mago y tu dios («Elegir mago y dios»; si no tocás nada, juegas con el del menú). Escribí `dirección:puerto` (por ejemplo `192.168.1.5:7710`), el código y el mismo transporte que el host. «Unirse».

El puerto por defecto es el **7710**. Si el host cierra el juego o sale de la partida, el servidor se apaga. Un servidor local no aparece en la lista de salas, no abre puertos solo (sin UPnP) y no tiene respaldo en el VPS.

## Seguridad

- El código es la credencial del asiento del rival (64 bits al azar, uno por servidor). El servidor guarda solo su hash y acepta un jugador por asiento: un tercero sin código, con un código inventado o con el código de un asiento ya ocupado es rechazado. Un mago o un dios inválido también se rechaza ("bad_pick"): el rival elige de nuevo y vuelve a unirse con el mismo código.
- Compartí el código solo con tu rival. Quien lo tenga puede sentarse en su lugar hasta que el rival entre.
- Cada servidor local tiene sus propios códigos; no se reutilizan entre partidas.

## En la misma red (casa, LAN)

Alcanza con la dirección que muestra la pantalla. Si el rival está en otra red, el servidor no es visible desde afuera: **exponerlo a Internet es cosa tuya**.

## Por Internet

Elegí una de estas opciones y pasale a tu rival la dirección pública y el puerto que te dé.

- **UDP (el transporte por defecto, ENet).** ngrok **no sirve**: solo tuneliza TCP y HTTP.
  - **Reenvío de puertos** en tu router: UDP 7710 hacia la IP local de tu PC.
  - **Tailscale o ZeroTier**: los dos entran a la misma red privada y usan la dirección privada que te da la herramienta.
  - **playit.gg**: túnel UDP, apuntá el túnel a UDP 7710 en tu PC.
- **TCP (WebSocket).** Elegí «TCP (WebSocket)» en los dos lados. Sirve cualquier túnel TCP, como **ngrok** (`ngrok tcp 7710`; el rival escribe la dirección y el puerto que muestra ngrok), o el reenvío de puertos en TCP.

Si usás un túnel, la dirección que muestra la pantalla es la local: reemplazala por la del túnel al pasarla.

## Qué hay detrás (para desarrollar)

- `scenes/net/local_server_host.tscn` (`LocalServerHost`): lanza el dedicado con `MpMatchLauncher` (`data/net/lobby_config_local_server.tres`, un asiento por jugador, ticket de dos asientos), genera las credenciales y avisa cuando escucha.
- El dedicado es el mismo de las salas (`MatchTicketGlue` + `MpMatchAgent`); admite solo los hashes del ticket.
- Prueba: `bash agent/run_034m.sh` (headless, host + rival + intruso). Con `TRANSPORT=ws`, por TCP.
