**English** | [Español](servidor_local.md)

# Local server

A 1 vs 1 match that runs on your own PC, without going through «Salas online» (Online rooms) or the VPS. You are the host: the game launches a dedicated server on your machine (the same code the VPS uses) and you join as one more player. Your rival joins with an address, a port and a code.

The in-game interface is in Spanish: labels are quoted as they appear, with an English gloss.

## How to use it

**Host**
1. In the menu, pick your wizard and your god and go to the main menu.
2. «Servidor local» (Local server) → «Crear servidor local» (Create local server).
3. Pick the transport (UDP by default). Your rival picks their own wizard and god when joining.
4. «Crear» (Create). The screen shows **the local address, the port, the transport and the rival's code**. «Copiar dirección y código» (Copy address and code) puts them on the clipboard.
5. Give that data to your rival and press «Entrar a la partida» (Join the match). The match starts when the rival has joined, sent their character and both have loaded the world.

**Rival**
1. Menu → «Servidor local» (Local server) → «Unirse a servidor local» (Join local server).
2. Pick your wizard and your god («Elegir mago y dios», Pick wizard and god; if you touch nothing, you play with the menu's). Type `address:port` (for example `192.168.1.5:7710`), the code and the same transport as the host. «Unirse» (Join).

The default port is **7710**. If the host closes the game or leaves the match, the server shuts down. A local server does not show up in the room list, does not open ports by itself (no UPnP) and has no backup on the VPS.

## Security

- The code is the credential of the rival's seat (64 random bits, one per server). The server stores only its hash and accepts one player per seat: a third party without a code, with a made-up code or with the code of a seat already taken is refused. An invalid wizard or god is also refused ("bad_pick"): the rival picks again and joins again with the same code.
- Share the code only with your rival. Whoever has it can sit in their place until the rival joins.
- Each local server has its own codes; they are not reused between matches.

## On the same network (home, LAN)

The address the screen shows is enough. If the rival is on another network, the server is not visible from outside: **exposing it to the Internet is up to you**.

## Over the Internet

Pick one of these options and give your rival the public address and port it gives you.

- **UDP (the default transport, ENet).** ngrok **does not work**: it only tunnels TCP and HTTP.
  - **Port forwarding** on your router: UDP 7710 to your PC's local IP.
  - **Tailscale or ZeroTier**: both join the same private network and use the private address the tool gives you.
  - **playit.gg**: a UDP tunnel; point the tunnel at UDP 7710 on your PC.
- **TCP (WebSocket).** Pick «TCP (WebSocket)» on both sides. Any TCP tunnel works, such as **ngrok** (`ngrok tcp 7710`; the rival types the address and port ngrok shows), or port forwarding over TCP.

If you use a tunnel, the address the screen shows is the local one: replace it with the tunnel's when you pass it on.

## What's behind it (for developers)

- `scenes/net/local_server_host.tscn` (`LocalServerHost`): launches the dedicated server with `MpMatchLauncher` (`data/net/lobby_config_local_server.tres`, one seat for each seat of the chosen mode, human or AI; one code per human seat), generates the credentials and signals when it is listening.
- The dedicated server is the same as the rooms' (`MatchTicketGlue` + `MpMatchAgent`); it admits only the ticket's hashes.
