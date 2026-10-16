# Cómo se gana y se pierde en Sacrifice (original)

Fecha: 2026-10-13. Lectura estática, nada probado en ejecución. No se corrió Ghidra de nuevo (se usaron los ~2500 `.c` ya descompilados en `scratchpad/research_doctors/all/`). El `MANUAL.PDF` de la instalación es un escaneo (sin capa de texto, no hay `pdftotext`/`pypdf`): **no se leyó**.

Fuentes: **[SE]** sacengine `sacengine/source/state.d` (archivo:línea) · **[EXE]** `Sacrifice.exe` descompilado (`FUN_xxxxxxxx`) · **[TXT]** textos del juego en la instalación `/Users/joelsartori/Downloads/sacgame/Sacrifice/` (`ReadMe.txt`, `Patch3_English.txt`, `data/local/lang_english.wad`, `data/local/langp3_english.wad`) · **[WEB]** secundarias.

## Respuesta corta

- Tu recuerdo es correcto en lo esencial: la victoria se consigue **profanando el altar rival** (hechizo Desecrate).
- Pero el altar **no cae por tiempo**: el ritual drena vida, maná y XP del mago enemigo ronda tras ronda y **sigue hasta que el mago muere**. Recién entonces el altar se destruye y el jugador queda «banished» (su partida termina).
- Dicho de otro modo, matar al mago **sin ritual no gana nada** (se vuelve fantasma y revive); matar al mago **bajo ritual** es lo que decide la partida.
- Defensa: matar a **uno** de los 4 sac-doctors cancela el ritual (solo con ataques a distancia: los cuerpo a cuerpo no pasan la barrera).
- Excepción: un mago que muere **sin ningún altar en pie** tampoco pasa a fantasma; desaparece y su bando pierde (**solo sacengine**; el exe es consistente pero no lo prueba).
- Fin de partida: gana quien queda sin enemigos con altar. Hay además rendirse y los modos Slaughter / Soul Harvest / Domination (multijugador).

---

## 1. Condición exacta de victoria / derrota

- **Derrota = «banished» / altar «desecrated»**, no «muerte del mago». ReadMe 7.7: «If He Should Die From These Repeated Attacks, His Altar Is Destroyed And His Game Is Over» [TXT `ReadMe.txt:432-433`]. Consejo del juego: «When a wizard is banished (his altar Desecrated)…» [TXT `lang_english.wad`, cadena de tips]. Mensaje de sistema: «%s's altar has been desecrated by %s.» [TXT `lang_english.wad`]; el juego usa «Banishments» en el resumen y «is victorious!», «has been defeated.», «has surrendered.» [TXT `langp3_english.wad`].
- **Secuencia en sacengine** (ambas cosas, en orden): (1) el mago muere con el ritual activo → no pasa a fantasma, `disappear` 4 s [SE `state.d:14008-14010`]; (2) `updateRitual` ve `targetDead` y llama `destroyAltar` + `state.desecrate(side)` (estado `SideState.desecrated`, mensaje «altar has been desecrated») [SE `state.d:15901-15903`, `29833-29843`, `30465-30467`]; (3) animación del altar 4+4+3 s y al terminar `state.defeat(side)` (`SideState.defeated`) [SE `state.d:5289-5291`, `26062`, `29805-29818`]; (4) al desvanecerse el mago, `lose(side)` = `destroyAltars` + `killAll` [SE `state.d:25998`, `13404-13407`]. `isDefeated` cuenta tanto `desecrated` como `defeated` [SE `state.d:30494-30497`].
- **Victoria (skirmish estándar)**: `getNewVictories`: gana el bando con altar al que no le queda ningún enemigo con altar sin derrotar [SE `state.d:30483-30492`; el modo `skirmish` «fully handled in state.defeat», `30607`].
- Texto original: «When You Desecrate All Enemy Altars And Kill Off All Enemy Wizards, You Shall Be Victorious!» [TXT `ReadMe.txt:444-445`]. (Ver discrepancia 8.2 sobre «y matar a todos los magos».)
- Exe: la señal «ritual de Desecrate terminó» destruye el altar: `FUN_00447f50` (estado 0xf0 del FSM del ritual `FUN_004484e0`) llama `FUN_00465f40(altar,1)` → `FUN_00465300(altar,2)`, que pone el estado del altar en 2 (destruido) [EXE]. **No se encontró en el volcado** el código que declara la derrota del bando ni muestra la pantalla; el volcado no cubre esa zona. Confianza en «altar destruido ⇒ derrota»: texto del juego + sacengine + web; no probada en el exe.

## 2. ¿Puede destruirse el altar sin que el mago muera?

- **Por el ritual, no.** Termina solo cuando el mago muere: [TXT `ReadMe.txt:429-434`] «As Long As The Desecration Ritual Stays In Motion, The Wizard… Will Take Damage»; mientras el mago viva «he can attempt to interrupt».
- [SE `state.d:16036-16041`]: al cerrar cada ronda, `if(targetDead)` gibea la criatura, destruye el altar y para el ritual; si el mago sigue vivo no hace nada y el ritual sigue. No hay tope de rondas para Desecrate (el contador `vidaMáx/550` es de Convert, `16027`).
- [EXE `FUN_004484e0`, estado 0x61]: al terminar una ronda va a otra (0x32) si `altar+0x464 > 0`; si no, a 0xf0 (fin). `FUN_00448190`, rama `'ucas'` (0x73616375): pone `altar+0x464 = 0` **solo si el puntero al mago del altar es nulo** (mago eliminado) y nunca lo decrementa; el decremento solo existe para Convert (`FUN_004480a0`, rama `'sacc'`). Conclusión: el ritual de Desecrate dura hasta que el mago deja de existir. **Sin verificar**: el valor inicial de `altar+0x464` (sale de un `ftol()` no visible en `FUN_00465530`).
- Si el mago vive (se cura, huye): el ritual sigue; ver §3 y §6 para cómo se corta.
- **Por otras vías sí se destruye sin ritual**: rendirse (`surrender` → `lose` → `destroyAltars`) [SE `state.d:13409-13414`] y victoria por modo Slaughter/Soul Harvest/Domination (`lose(i)` a los perdedores) [SE `state.d:30633-30640`].

## 3. Qué le hace el ritual al mago enemigo

- **Drena vida, maná y XP**: [TXT `ReadMe.txt:428-431`] «Takes Away A Wizard's Health, Mana And Experience Points»; «The More Souls A Creature Has, The More Damage…» [TXT `ReadMe.txt:576-577`].
- Cifras en sacengine: por ronda `200·(1+almas)` de vida, `40·(1+almas)` de maná, `3000·(1+almas)` de XP (este último con `// TODO: correct?`), repartido en la ventana de disparo [SE `state.d:16004-16013`]. Se aplica solo si el mago no está muerto.
- Cifras en el exe: `FUN_00465530` guarda en el altar `(almas+1)·100` (vida), `(almas+1)·800/60` (maná), `(almas+1)·0xA0000/60` (XP en 16.16) y `FUN_00448190` los multiplica por `param_3` cada paso (un contador de 60) [EXE]. **Las unidades no se pudieron reconciliar con sacengine** (proporción vida:maná 100:13,3 en el exe vs 200:40 en sacengine). Sin verificar; el RESEARCH-doctors ya daba las cifras de sacengine como del original.
- **No lo inmoviliza, no lo arrastra, no le impide lanzar hechizos**: no hay nada así en `updateRitual` [SE]. Lo único que empuja el ritual es a todo lo que esté a < 20 m del altar, hacia afuera (`pushAll`, [SE `state.d:16047-16051`]); el ReadMe dice que los cuerpo a cuerpo no entran por una «barrier of magical energy» [TXT `ReadMe.txt:440-442`]. Distancia del mago al altar: no importa para el drenaje (se aplica a `targetWizard` esté donde esté) [SE]; el rayo parte de un vórtice que se mantiene a 12,5 m del mago [SE `state.d:2641-2642`, `15934-15943`].
- **Impide volverse fantasma**: sí. Con ritual activo, si el mago muere no pasa a `deadToGhost` sino a `disappear` [SE `state.d:14008-14010`]. El original lo dice: «If Your Altar Should Ever Become Desecrated, The Death You Will Suffer Will Become Permanent!» [TXT `ReadMe.txt:245-246`].
- **Mago ya fantasma al empezar el ritual**: sacengine lo hace revivir con `max(1, vida)` en cuanto `numDesecrations>0` [SE `state.d:13959-13962`], para poder volver a matarlo. Exe: `FUN_00482030` (actualización del mago fantasma) usa la misma salida `FUN_00454d90(mago,0x20,1)` tanto para el reviv normal (≥25 % de maná) como cuando el ritual del altar es `'ucas'`; y `FUN_004824f0` solo permite «revivir en el altar» si su ritual **no** es `'ucas'` [EXE]. Consistente con sacengine, pero el significado del comando 0x20 es una inferencia: confianza media.
- Mago ya muerto (cuerpo, no fantasma) al empezar: sin verificar.

## 4. Muerte del mago sin ritual

- **Fantasma y revive**: [TXT `ReadMe.txt:237-247`] «Change Into Spectral Form… As A Specter You Will Only Be Able To Give Orders… NOT… Cast Spells Or Collect Souls»; vuelve a un manalith, fuente o altar y al reponer el 25 % de maná la vida se llena y reviven. Tip del juego: «Death is not the end… you may yet come back» [TXT `lang_english.wad`]. sacengine: `dying → deadToGhost` si hay altar y no hay profanación [SE `state.d:14008-14015`]; sale de fantasma con vida máxima o por profanación [SE `13959`]. Exe: el mismo 25 % (`FUN_00482030`: `altar+0xb20 >= 0xb24>>2` → reviv) [EXE]. Alta confianza.
- **Sin altar, sí pierde**: [SE `state.d:14008-14010`] `noAltar=!hasAltar(side)` → `disappear(1 s)` y al terminar `lose(side)` [SE `25998`]. El exe aborta con «Live wizard has no altar» si un mago fantasma no tiene altar (`FUN_00482030`) y «Cannot find altar to make wizard» (`FUN_004567d0`) [EXE]: los magos vivos siempre tienen altar, coherente con que la regla del fantasma dependa del altar. El texto del juego lo refuerza («If it's gone, your God will not be able to save you», [TXT `ReadMe.txt:246-247`]). Confianza media (sacengine + indicios).

## 5. Después de la profanación

- **Eliminado**: «His Game Is Over» [TXT]. En multijugador el parche 3 permite quedarse de observador tras ser banished: «stay in a game as an observer after you have been desecrated» [TXT `Patch3_English.txt:104-105`] (opción «No Observer… when they have been banished»).
- **Criaturas**: sacengine `lose` → `killAll(side)` [SE `state.d:8298-8304`, `13404-13407`] (excepto `convertReviving`). Textos: no dicen que las criaturas mueran. Sin verificar en el exe.
- **Edificios**: sacengine solo destruye los altares (`destroyAltars`); manaliths/estructuras no se tocan [SE `13388-13402`]. Sin verificar en el original.
- **Almas del banished** (discrepancia): ReadMe: «He Leaves His Souls Free To Be Converted By Any Wizard» [TXT `ReadMe.txt:572-573`]; el tip dentro del juego, que es posterior: «all the souls he carries are gone forever» [TXT `lang_english.wad`]. Se contradicen; no se eligió. Se refiere a las almas que lleva el mago (contador), no a las criaturas.
- **Más de dos jugadores**: la partida sigue hasta que quede un bando (o equipo) sin enemigos con altar: `getNewVictories` [SE `30483-30492`]; en equipos usa `enemies & altarSides & ~defeatedSides`. No se comprobó en el exe. Observadores no salen al terminar: hay que pulsar «Finish» [TXT `Patch3_English.txt:111-114`].

## 6. Cómo se cancela o defiende

- **Matar a uno de los 4 doctores**: [TXT `ReadMe.txt:437-440`] «Only One Of The Doctors Needs To Be Killed For The Desecration To Stop»; consejo: «Your first level damage spell is the best way to interrupt a desecration» [TXT `lang_english.wad`]. [SE `state.d:15921-15925`]: si algún doctor entra en `dying` → `stopRitual`, que libera la criatura, mata a los otros doctores, desocupa el altar y quita la marca al mago [SE `15817-15833`]. [WEB wiki] y [WEB Wikipedia] coinciden.
- **Los cuerpo a cuerpo no pueden** (barrera de energía) [TXT `ReadMe.txt:440-442`] ↔ sacengine `pushAll` a 20 m [SE `16047-16051`].
- **Teleport al altar** para defenderlo [TXT `ReadMe.txt:548-551`; tip del juego «Use the 'teleport' spell to return to your Altar when it is being Desecrated»].
- **Vencer al lanzador/criatura antes del ritual**: el portador muerto suelta la criatura [RESEARCH-doctors].
- **Altar ocupado**: no se puede abrir un segundo ritual en el mismo altar (`freeForRitual`, bandera `occupied`) [SE `15800-15815`, `15866`].
- **Guardian en el altar**: no hay evidencia en ninguna fuente de que ayude contra el ritual; el ReadMe solo dice «Be Sure To Guard Your Altar» [TXT `ReadMe.txt:554`] (sentido general). No verificado.
- **Curarse / huir**: no cancela (ver §2); solo retrasa la muerte.

## 7. Otras formas de ganar o perder

- **Rendirse**: comando `surrender`, «Surrender to the enemy» y «has surrendered.» [TXT `lang_english.wad`, `langp3_english.wad`]; en sacengine ejecuta `lose` y marca `desecrated` [SE `13409-13414`, `29822-29832`].
- **Modos de partida**: Single Player, Skirmish, **Slaughter**, **Soul Harvest**, **Domination** [TXT `lang_english.wad`: «Skirmish / Slaughter / Soul Harvest»; «Domination»]. En sacengine: Slaughter = N kills, Domination = N manaliths, Soul Harvest = N almas por equipo; los perdedores reciben `lose` + `defeat` [SE `30595-30645`]. Wikipedia: Domination = «controlling a set number of manaliths» [WEB https://en.wikipedia.org/wiki/Sacrifice_(video_game)]. Detalle de umbrales en el original: sin verificar.
- Límites de tiempo: sin evidencia. Objetivos de campaña: sin investigar.
- Abandono/desconexión: «has been dropped from the game.» [TXT `langp3_english.wad`].

## 8. Discrepancias

1. **RESEARCH-doctors vs. esta investigación**: coincide en que el ritual no tiene duración fija y termina con la muerte del mago. Corrección de precisión: en el exe el fin está ligado a que el **puntero al mago sea nulo** (el mago ya desapareció), no a «mago muerto»; el efecto práctico es el mismo salvo por los 4 s de `disappear`. Matiz nuevo: el original no dice «derrotado ~11 s después» en ningún texto; eso es solo sacengine (4+4+3 s del altar).
2. **«Y matar a todos los magos»**: el ReadMe pide desecrar todos los altares **y** matar a todos los magos; sacengine solo exige que no queden enemigos con altar sin derrotar. Dado que el ritual mata al mago, en 1v1 son lo mismo; en partidas con varios altares por jugador o magos sin altar podría diferir. Sin resolver.
3. **Almas del banished**: ReadMe «free to be converted» vs. tip del juego «gone forever» (§5).
4. **Cifras del drenaje**: exe (`(almas+1)·100/·800/60/·0xA0000/60` por paso) vs. sacengine (`200/40/3000` por ronda); unidades sin reconciliar (§3). XP del drenaje con `TODO` en sacengine.
5. **sacengine mueve el ritual por decisiones propias**: p. ej. `unghost` forzado en profanación (consistente con el exe, §3) y `// TODO: check if reviving/firewalking creatures die when owner surrenders` [SE `state.d:157`].
6. **Wikipedia dice «banishing»**, no distingue que primero hay que matar al mago; el wiki antiguo sí lo dice («if you kill the enemy wizard during the ritual, the desecration completes»). Sin conflicto.

---

## Tabla de afirmaciones

| Afirmación | Fuentes que la respaldan | Confianza |
|---|---|---|
| Se pierde cuando el altar es profanado/destruido por Desecrate («banished») | TXT ReadMe 7.7 y tips; SE `15901`, `26062`; EXE `FUN_00447f50→00465f40` (altar a estado 2); WEB Wikipedia/wiki | Alta |
| El altar solo cae por el ritual cuando el mago muere; sin tiempo ni tope de rondas | TXT ReadMe 7.7; SE `16036-16041`; EXE `FUN_00448190/004484e0` (inferencia, valor inicial de `+0x464` sin ver) | Alta (comportamiento) / media (mecanismo exe) |
| Mago que muere bajo ritual no pasa a fantasma («permanent») | TXT ReadMe 4.4; SE `14008-14010`; EXE `FUN_00482030/004824f0` (indirecto) | Alta |
| El ritual drena vida, maná y XP, más cuantas más almas tenga la criatura | TXT ReadMe 7.7 y 9.5; SE `16004-16013`; EXE `FUN_00465530/00448190` | Alta (qué) / baja (cuánto: unidades) |
| Mago muerto sin ritual: fantasma y revive al 25 % de maná en altar/manalith/manantial | TXT ReadMe 4.4; SE `14008-14015`, `13959`; EXE `FUN_00482030` (25 %) | Alta |
| Mago que muere sin altar en pie pierde (desaparece, `lose`) | SE `14008-14010`, `25998`; EXE: error «Live wizard has no altar» (indicio) | Media |
| Un fantasma bajo ritual revive para poder ser drenado y muerto | SE `13959-13962`; EXE `FUN_00482030/004824f0` (inferencia) | Media |
| Matar a uno de los 4 doctores cancela el ritual | TXT ReadMe y tip; SE `15921-15925`, `15817`; WEB wiki, Wikipedia | Alta |
| Cuerpo a cuerpo no puede interrumpir (barrera) | TXT ReadMe; SE `pushAll` 20 m | Alta |
| Banished sale de la partida (observador permitido en parche 3) | TXT Patch3 1.2, 1.6; SE `defeat/lose` | Alta |
| Al caer un bando mueren sus criaturas | SE `killAll` solamente | Baja |
| Almas del banished: libres o perdidas | TXT ReadMe vs. tip del juego (contradicción) | No decidido |
| Partida multi-bando sigue hasta que queda uno sin enemigos con altar | SE `30483-30492` | Media (solo sacengine) |
| Rendirse = perder; modos Slaughter / Soul Harvest / Domination existen | TXT lang_english/langp3; SE `13409`, `30595-30645`; WEB Wikipedia | Alta (existen) / baja (umbrales) |
| Guardian en el altar bloquea la profanación | Ninguna | Sin evidencia |

---

## Qué implica para el port

Regla exacta a implementar:

```
Desecrate(carrier, enemy_altar): ritual con 4 doctores (5 s prep, rondas de 13,5 s)
cada ronda (mientras el mago objetivo exista y no esté muerto):
    mago.vida  -= 200 * (1 + almas_criatura)
    mago.mana  -= 40  * (1 + almas_criatura)
    mago.xp    -= (según TODO)
mago.numDesecrations += 1 durante todo el ritual  # impide ghost y fuerza unghost
al morir el mago con numDesecrations > 0 (o sin altar): no hay ghost; disappear 4 s (1 s sin altar)
al ver mago muerto en updateRitual: altar -> COLLAPSING (11 s); state.desecrate(side)
fin de la animación: DEFEATED(side); lose(side): destroyAltars + killAll
victoria: bando sin enemigos con altar sin derrotar
cancelar: muerte de cualquiera de los 4 doctores -> stopRitual (altar en pie, criatura libre)
```

Cambios en RFC-020 (leído solo §0 y los criterios de 020a/020d):
- **020d** ya recoge lo central (muerte bajo ritual → desaparece → altar → derrota a los 11 s; cancelar con un doctor). Falta explicitar: **sin tope de rondas**, el ritual no termina por tiempo; que el ritual solo se corta si el mago está vivo y mueren doctores. Añadir criterio: «mago con mucha vida o que se cura: el ritual continúa».
- **020a**: «Un mago que muere sin altar en pie pasa a GONE y su bando queda derrotado» está respaldado solo por sacengine; marcarlo como **regla de sacengine, no verificada en el original**. Además, el criterio «Al quedar derrotado un bando, sus criaturas mueren» solo viene de sacengine (confianza baja).
- Añadir a 020a/020d la opción de **rendirse** (`surrender` → `lose`) si se quiere paridad, y definir la victoria multi-bando como «sin enemigos con altar sin derrotar», no como «un solo vencedor».
- Opcional (criterio 020d): el aviso/sonido de «altar desecrated» al destruirse (`"%s's altar has been desecrated by %s."`).

## No verificado

- Código del exe que declara la derrota y muestra «Defeat»; qué hace con criaturas y edificios; fue imposible ubicarlo en el volcado (no se corrió Ghidra extra).
- Valor inicial de `altar+0x464` para `'ucas'` y las unidades del drenaje en el exe; XP drenada.
- El significado exacto del comando `0x20` en `FUN_00454d90` (supuesto: «revivir»).
- Si el mago está **muerto en cuerpo** (no fantasma) al empezar el ritual.
- Efecto de Guardian en el altar; límites de tiempo en escaramuza; objetivos de campaña; umbrales por defecto de los modos.
- `MANUAL.PDF` (escaneado), no leído.
- Si las almas del banished quedan libres o se pierden (textos contradictorios).
