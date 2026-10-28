# ui/online

«Salas online»: rooms that players host through the issuer and relay of MpKit. Create one (shows its code), join by code
or from the public list. The issuer URL (`[online] issuer_url_b64`, base64url) and the game id are in `config.cfg`; `--issuer-url=` / `--issuer-game=` override them.
Only players with the same game version (Project Settings › Application › Config › Version) meet.
Check: run two instances (Debug › Customize Run Instances), create a room in one and join it from the other.
