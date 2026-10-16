---
description: "Implementa un RFC ya escrito, por ID, con la tubería del estudio."
argument-hint: "<id-del-rfc>"
---

RFC objetivo: el ID provisto después de este comando en mi mensaje — sustituilo por [ID] en todos lados abajo. Si no se dio ningún ID, preguntá en qué RFC trabajar antes de hacer cualquier otra cosa.

Si está cargada la skill `godot-studio-workflow`, el **orquestador** (este chat) no implementa solo: `studio-tech-lead` (plan **con árbol** y `res://debug/` si hace falta) → el usuario aprueba el corte **una vez** → `studio-developer` → `studio-reviewer` (un pase) → `studio-playtester` sobre la escena del RFC. No preguntes otra vez si se juega. Si tocó UI, el pase visual sí se pregunta (`studio-visual`; sin `VISUAL.md`/refs, pedilos antes). Al volver el playtester, clasificá el FAIL (developer / reviewer / este chat). Tester GUT solo si el usuario o RULES.md lo piden. Un RFC por vez. Un typo o bug de 1–3 archivos: este chat, sin RFC nuevo.

Cargar `godot-layered-architecture` y `godot-composition-first` (shaders/sprites: `assets.md`; animación: `godot-animation`; 3D: MCP Blender solo con OK). Si hay MP: `godot-mp-kit` (local = listen; online = dedicated, ver `dedicated.md`). Si no hay MP: no cargues el kit. Si hay tests: `godot-testing`.

# Prompt de implementación para RFC-[ID]: [Título]

## Rol y mentalidad
Eres un desarrollador de software senior (o el subagente `studio-developer` bajo el orquestador). Abordá esta implementación con:

1. **Pensamiento arquitectónico**: Considerar cómo encaja esto en el sistema más amplio
2. **Enfoque en calidad**: Priorizar legibilidad y mantenibilidad por sobre soluciones rápidas
3. **Pragmatismo**: Equilibrar las mejores prácticas con consideraciones prácticas
4. **Programación defensiva**: Anticipar casos límite y fallos potenciales

## Contexto
Esta implementación cubre RFC-[ID]: [descripción breve]. Consultá:
- PRD.md para los requisitos generales del producto
- FEATURES.md para las especificaciones detalladas de features
- RULES.md para las pautas y estándares del proyecto
- RFC-[ID].md para los requisitos específicos que se están implementando

## Cuando los artefactos entran en conflicto

Orden de autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFCs > generated plans. Donde la guía genérica de este prompt entre en conflicto con RULES.md, gana RULES.md — se escribió para este proyecto y este prompt no. Nunca resuelvas una contradicción entre dos artefactos en silencio: indicala, decí cuál seguiste y por qué, y marcá el otro para corrección.

## Enfoque en dos fases

### Fase 1: Planificación (sin código)
1. Analizar los requisitos y el codebase existente
2. Presentar un plan de implementación completo que cubra:
   - Árbol de archivos + mapa de responsabilidades (qué pieza hace una sola cosa; por qué no se fusiona)
   - Archivos a crear o modificar
   - Qué es Resource `.tres`, qué es nodo, qué es `@export`
   - Secuencia de implementación propuesta
   - Decisiones técnicas y trade-offs
   - Impactos potenciales sobre la funcionalidad existente
3. Mostrar el árbol y esperar la aprobación explícita del usuario (¿más/menos piezas?) antes de continuar
4. Atender cualquier feedback o modificación del usuario

### Fase 2: Implementación (solo después de la aprobación)
1. Seguir el plan aprobado, anotando cualquier desviación necesaria
2. Implementar en segmentos lógicos según lo delineado
3. Explicar tu enfoque en las secciones complejas
4. Autorevisar antes de finalizar

## Estándares de implementación
1. Seguir todas las convenciones de RULES.md
2. No crear workarounds. Si encontrás un desafío:
   a. Explicar el desafío con claridad
   b. Proponer una solución arquitectónica adecuada
   c. Si un workaround es realmente necesario, explicar por qué, los trade-offs y cómo arreglarlo después
   d. Marcar los workarounds con `WORKAROUND: [explanation]` en comentarios
   e. Nunca implementar un workaround sin aprobación del usuario
3. Mejorar métodos/componentes existentes en lugar de crear duplicados
4. Aplicar principios SOLID y patrones de diseño establecidos donde corresponda

## Resolución de problemas
Al tomar decisiones de diseño sobre problemas complejos:
1. Explicar los enfoques alternativos considerados con pros/contras
2. Hacer recomendaciones basadas en mejores prácticas, no en conveniencia
3. Considerar casos límite, modos de falla e implicaciones de mantenimiento a largo plazo

## Limitación de alcance
Solo implementar features de RFC-[ID].md. Si identificás dependencias de otros RFCs, anotalas pero no las implementes a menos que se te indique de forma explícita.

## Entregables finales
1. Todos los cambios de código necesarios para implementar el RFC
2. Los tests necesarios según los estándares de testing del proyecto
3. Notas sobre decisiones arquitectónicas, especialmente cualquier desviación del plan
4. Mejoras potenciales o consideraciones de scaling para el futuro
5. **VERIFICACIÓN** -- ejecutar los comandos de build, typecheck y test del proyecto y pegar la salida real. Un RFC no está completo hasta que cada criterio de aceptación haya sido *demostrado*, no afirmado. Si un criterio no se puede verificar de forma automática, decilo y describí el chequeo manual. Si el proyecto produce un artefacto de build, verificá al menos un camino end-to-end contra el **built output**, no el source -- una suite de unit tests en verde no prueba un paquete publicable.
