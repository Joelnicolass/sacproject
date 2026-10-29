# 055d-buildings: checklist de los 82 BuildingType usados por los mapas

Fuente: los 82 `tag` distintos de `structures` en `assets/original/maps/*/ntts.json` (Peaks, High Noon, Peasantville, Roads, Winter Wonder), cruzados con `data/catalog/buildings/<tag>.tres` y `055R-original-reference.md` §2. Los otros 114 BLDG importados no se usan en ningun mapa (P5 del plan: se renombran como `<dios>_<tag>` en d1).
Los nombres propuestos estan en `tools/migrate/d1_building_names.csv` (`<dios>_<rol>[_n]`; el dios sale del `tileset`: JA_A james, PY_A pyro, ST_A stratos, char charnel; en estos 82 no aparecen persephone ni ether). La ultima columna del CSV marca con `?` los nombres dudosos: se eligieron mirando la silueta y la textura del modelo (`debug/map/building_gallery.tscn`), el tamano y las banderas del BLDG; el original no nombra estos modelos.
Los 4 altares (`ca_a`, `jaal`, `pyal`, `stal`) figuran en `ntts.json` pero no estan en los `layout.tscn` de hoy: no son `MapBuilding` colocados (decision para d2).

Columnas: tipo (tag del BLDG) | rol | modelo (componentes, `KIND:tag` cuando hay varios) | comportamiento hoy | estado.
`pcmf` (Pyro) comparte el modelo `jcmp`; los modelos sin textura propia usan la de otro (`textures/index.json`, `owner`), por ejemplo `jcc2` usa la de `jcc1`.

| tipo | rol | modelo | comportamiento | estado |
|---|---|---|---|---|
| ca_a | altar | BASE:caab + PIL1:caap + PIL2:caap + PIL3:caap + PIL4:caap + TOP!:caar | altar: respawn del mago, destino de Convert/Desecrate, refugio de aldeanos (scenes/sacrifice, spells/guardian); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| cafn | fountain | cafn | manantial: destino de Manalith/Shrine (scenes/map/props/manafount); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| grv1 | grave | grv1 | indestructible; cuerpo caja | modelo y textura ok |
| grv2 | grave | grv2 | indestructible; cuerpo caja | modelo y textura ok |
| grv3 | grave | grv3 | indestructible; cuerpo caja | modelo y textura ok |
| crs1 | grave | crs1 | indestructible; cuerpo caja | modelo y textura ok |
| cat3 | plant | cat3 | destructible, vida 1000, modelo caido ctx1; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| cat5 | plant | cat5 | destructible, vida 1000, modelo caido ctx2; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| cat7 | plant | cat7 | destructible, vida 1000, modelo caido ctx2; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| cash | plant | cash | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| car1 | spire | car1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| casb | tent | casb | indestructible; cuerpo caja | modelo y textura ok; el modelo mide 1140 m de ancho (revisar la caja); nombre dudoso |
| jaal | altar | BASE:jpit + PIL1:jpil + PIL2:jpil + PIL3:jpil + PIL4:jpil + TOP!:jrng | altar: respawn del mago, destino de Convert/Desecrate, refugio de aldeanos (scenes/sacrifice, spells/guardian); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| bon1 | bone | bon1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| bon2 | bone | bon2 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| bon4 | bone | bon4 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| bon5 | bone | bon5 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| bon6 | bone | bon6 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| jcmp | camp | jcmp | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| jcrt | cart | jcrt | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jct1 | crate | jct1 | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jct2 | crate | jct2 | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jct3 | crate | jct3 | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jfn1 | fence | jfn1 | indestructible; cuerpo caja | modelo y textura ok |
| jfn2 | fence | jfn2 | indestructible; cuerpo caja | modelo y textura ok |
| jfn3 | fence | jfn3 | indestructible; cuerpo caja | modelo y textura ok |
| jfnt | fountain | jfnt | manantial: destino de Manalith/Shrine (scenes/map/props/manafount); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| jcc1 | plant | jcc1 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| jcc2 | plant | jcc2 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| jcc3 | plant | jcc3 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| jcc4 | plant | jcc4 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| jeg1 | plant | jeg1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| jeg2 | plant | jeg2 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| jeg3 | plant | jeg3 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| bld1 | rock | bld1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| bld2 | rock | bld2 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| bld3 | rock | bld3 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| jhut | shelter | jhut | refugio de aldeanos; destructible, vida 5000, modelo caido jhbr; cuerpo caja | modelo y textura ok |
| jwg1 | shelter | jwg1 | refugio de aldeanos; destructible, vida 5000, modelo caido jwbr; cuerpo caja | modelo y textura ok |
| jmrq | shelter | jmrq | refugio de aldeanos; destructible, vida 5000, modelo caido jmbr; cuerpo caja | modelo y textura ok; nombre dudoso |
| jst1 | spire | jst1 | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jfor | tree | jfor | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| jwel | well | jwel | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| pyal | altar | BASE:pypt + PIL1:pypl + PIL2:pypl + PIL3:pypl + PIL4:pypl + TOP!:pyrg | altar: respawn del mago, destino de Convert/Desecrate, refugio de aldeanos (scenes/sacrifice, spells/guardian); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| pcmf | camp | jcmp | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; reusa el modelo jcmp |
| pyft | fort | pyft | destructible, vida 10000, sin modelo caido; cuerpo caja | modelo y textura ok; nombre dudoso |
| pfon | fountain | pfon | manantial: destino de Manalith/Shrine (scenes/map/props/manafount); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| pmv1 | mound | pmv1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| pmv2 | mound | pmv2 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| vbl1 | rock | vbl1 | indestructible; cuerpo caja | modelo y textura ok |
| vbl2 | rock | vbl2 | indestructible; cuerpo caja | modelo y textura ok |
| vbl3 | rock | vbl3 | indestructible; cuerpo caja | modelo y textura ok |
| vbl4 | rock | vbl4 | indestructible; cuerpo caja | modelo y textura ok |
| vbl5 | rock | vbl5 | indestructible; cuerpo caja | modelo y textura ok |
| vbl6 | rock | vbl6 | indestructible; cuerpo caja | modelo y textura ok |
| vbl7 | rock | vbl7 | indestructible; cuerpo caja | modelo y textura ok |
| vbl8 | rock | vbl8 | indestructible; cuerpo caja | modelo y textura ok |
| pht1 | shelter | pht1 | refugio de aldeanos; destructible, vida 5000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pht2 | shelter | pht2 | refugio de aldeanos; destructible, vida 5000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pwhr | shelter | pwhr | refugio de aldeanos; destructible, vida 5000, sin modelo caido; cuerpo caja | modelo y textura ok; nombre dudoso |
| prc1 | spire | prc1 | indestructible; cuerpo caja | modelo y textura ok |
| prc2 | spire | prc2 | indestructible; cuerpo caja | modelo y textura ok |
| pyst | spire | pyst | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |
| plm1 | tree | plm1 | destructible, vida 1000, sin modelo caido; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| plm2 | tree | plm2 | destructible, vida 1000, sin modelo caido; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| plm3 | tree | plm3 | destructible, vida 1000, sin modelo caido; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| pyt1 | tree | pyt1 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pyt2 | tree | pyt2 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pyt3 | tree | pyt3 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pyt4 | tree | pyt4 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pyt5 | tree | pyt5 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| pyt6 | tree | pyt6 | destructible, vida 1000, sin modelo caido; cuerpo caja | modelo y textura ok |
| stal | altar | BASE:crpt + PIL1:sapl + PIL2:sapl + PIL3:sapl + PIL4:sapl + TOP!:sarg | altar: respawn del mago, destino de Convert/Desecrate, refugio de aldeanos (scenes/sacrifice, spells/guardian); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| stmf | fountain | stmf | manantial: destino de Manalith/Shrine (scenes/map/props/manafount); suelo cambiado, sin cuerpo propio | modelo y textura ok |
| sic1 | ice | sic1 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| sic2 | ice | sic2 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| sic3 | ice | sic3 | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok |
| sig1 | shelter | sig1 | refugio de aldeanos; destructible, vida 5000, sin modelo caido; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| stdw | spire | stdw | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| stdx | spire | stdx | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| stdy | spire | stdy | indestructible; suelo cambiado, sin cuerpo propio | modelo y textura ok; nombre dudoso |
| slp1 | spire | slp1 | indestructible; cuerpo caja | modelo y textura ok; nombre dudoso |


## Resumen

- Por rol: plant 11, rock 11, tree 10, spire 9, shelter 7, bone 5, altar 4, fountain 4, grave 4, crate 3, fence 3, ice 3, camp 2, mound 2, tent 1, cart 1, well 1, fort 1.
- Por dios: james 31, pyro 29, charnel 12, stratos 10.
- Nombres dudosos (29): cat3, cat5, cat7, cash, car1, casb, jcrt, jct1, jct2, jct3, jeg1, jeg2, jeg3, bld1, bld2, bld3, jmrq, jst1, jfor, pyft, pmv1, pmv2, pwhr, pyst, sig1, stdw, stdx, stdy, slp1.
- Los 82 tienen modelo y textura (propia o prestada); ninguno falta. Shrine (`pcas`) no aparece en los mapas: se crea al lanzar el hechizo (055e / RFC-056).
