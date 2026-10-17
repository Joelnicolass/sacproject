# REVIEW-RFC-030t-b (F157): Rend Soul

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

## Revisión
- **Fidelidad:** PASS.
  - `canRend`: alma en NORMAL o EMERGING, libre o propia, y no soltada (`!dropped`).
  - El maná y el enfriamiento se cobran aunque el alma ya no esté.
  - Alcance 3D de 90.
  - En T+1 vuelve a chequear, el alma revienta (con `sever`), sale el beam styx y la salpicadura de 2500·(1 − d/40) por caja, sin golpe directo.
  - Los edificios neutrales del radio reciben la caída entera (fiel a 9075-9089).
- **Un dueño:** PASS. La regla única `can_rend` la usan la habilidad y el golpe, y `burst()` llama a `sever()`.
- **`windup_clip`:** su valor por defecto es 1, así que las habilidades que ya existían no cambian.
- **Determinismo, red y reglas:** PASS. El orquestador corrió `quick` completo y dio QUICK PASS con las 19 líneas base.

## Menores
- **m1:** `fire()` vuelve a chequear el alcance de 90 m al disparar; el motor solo vuelve a chequear `canRend`. Es un caso raro y queda declarado.
- **m2:** sin las 2 `StyxExplosion` ni el sonido (declarado).
- **m3 y m4:** sin acción.

## Playtest (Sonnet, una corrida)
- **PASS:**
  - el beam styx se ve, azul sobre la nieve;
  - la vida de los Jabberocky baja en escalera: 1728, 1306, 837, 368 y 0;
  - el aliado queda en 800;
  - nadie queda dentro de estructuras.
- **PARCIAL:** el alma y el estallido no se leen en pantalla. En el banco, un Devour simultáneo justo al lado pone una nube blanca encima, y además faltan las `StyxExplosion`. El estado está verificado en el log: `alma Trogg6 reventada` y `cadáver disuelto` en el tick 357.
