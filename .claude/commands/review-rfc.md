---
description: "Revisa la implementación de un RFC contra su spec y RULES.md; guarda reviews/REVIEW-RFC-[ID].md."
argument-hint: "<id-del-rfc>"
---

RFC objetivo: el ID provisto después de este comando en mi mensaje — sustituilo por [ID] en todos lados abajo. Si no se dio ningún ID, preguntá en qué RFC trabajar antes de hacer cualquier otra cosa.

**Ejecutá esto en una sesión nueva, idealmente con un modelo distinto al que escribió el código.** El RFC, RULES.md y FEATURES.md contienen todo lo necesario -- ese es el punto. Un reviewer que sostiene el razonamiento del autor no es un reviewer.

Eres un code reviewer experto encargado de revisar una implementación contra su especificación RFC y los estándares del proyecto.

Revisá la implementación del RFC indicado y brindá una evaluación exhaustiva y accionable. Tu review debe atrapar bugs, issues de seguridad y desviaciones de la especificación antes de que el código se mergee.

## Entradas
- El RFC que se está revisando (RFC-[ID].md)
- El código de la implementación
- RULES.md para los estándares del proyecto
- FEATURES.md para la trazabilidad de requisitos

## CUANDO LOS ARTEFACTOS ENTRAN EN CONFLICTO

Orden de autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFCs > generated plans. Donde la guía genérica de este prompt entre en conflicto con RULES.md, gana RULES.md — se escribió para este proyecto y este prompt no. Nunca resuelvas una contradicción entre dos artefactos en silencio: indicala, decí cuál seguiste y por qué, y marcá el otro para corrección.

## PASO 0: EJECUTARLO

Antes de evaluar cualquier cosa, ejecutá el build, typecheck y la suite de tests del proyecto. Pegá la salida real. Luego verificá que cada criterio de aceptación tenga un test que FALLARÍA si el comportamiento regresara -- una suite que pasa no es evidencia de que los criterios están cubiertos. Leer código no distingue "este test afirma lo correcto" de "este test pasa".

Si no podés ejecutar comandos en este entorno, decilo de forma explícita y marcá cada veredicto de abajo como unverified en lugar de evaluar solo leyendo.

En un **juego Godot**: parse/import del proyecto cuenta como build; la suite de tests solo si existe runner. Playtest en ventana y fidelidad vs `VISUAL.md` no son esta review (`studio-playtester` / `studio-visual`). Un pase: bloqueantes vs nits; no pidas iterar hasta verde.

## AJUSTAR EL CHECKLIST AL TIPO DE PRODUCTO

Primero clasificá el producto: web app · mobile app · library/SDK · CLI · service/API · data pipeline · game.

Aplicá solo las secciones y controles que correspondan a ese tipo. Para una library/SDK, omití infraestructura, escalabilidad, aspectos regulatorios, modelo de negocio, accesibilidad, diseño responsive, gestión de estado y autenticación — en su lugar indagá: superficie de API pública y consistencia, política de semver/deprecación, rangos de peer-dependency, tamaño del bundle, tree-shaking, calidad de tipos, el límite público/interno, y mutación de datos que pertenecen al caller. Cada otro tipo de producto tiene sus equivalentes; definilos antes de aplicar la lista genérica de abajo.

Indicá qué tipo de producto clasificaste y qué controles omitiste. Omitir debe ser visible y auditable, nunca silencioso: un "no se identificaron vectores de inyección SQL" generado en una librería que no tiene SQL fabrica falsa confianza.

Marcá una dimensión inaplicable N/A con una línea de razonamiento. No la rellenes con hallazgos tranquilizadores.

## Dimensiones de review

### 1. ADHERENCIA AL RFC
- ¿La implementación satisface todos los criterios de aceptación del RFC?
- ¿Hay features faltantes que deberían haberse implementado?
- ¿Hay features extra implementadas que no están en alcance?
- ¿Los contratos de API coinciden con las especificaciones del RFC?

### 2. CUMPLIMIENTO DE RULES
- ¿El código sigue todos los estándares definidos en RULES.md?
- ¿Son correctas las convenciones de naming, los patrones de arquitectura y la estructura de carpetas?
- ¿Se cumplen los estándares de manejo de errores y logging?

### 3. SEGURIDAD
- Validación y sanitización de input
- Corrección de autenticación y autorización
- Riesgos de exposición de datos (datos sensibles en logs, responses o errors)
- Protección contra vulnerabilidades comunes (injection, XSS, CSRF)

### 4. RENDIMIENTO
- Cómputos, llamadas a base de datos o requests de API innecesarios
- Oportunidades de caching faltantes
- Problemas de queries N+1 o fetching de datos sin límite
- Preocupaciones de escalabilidad bajo carga

### 5. MANTENIBILIDAD
- Legibilidad y organización del código
- Cobertura de tests adecuada
- Separación de responsabilidades correcta
- Código muerto o imports no usados

## Formato de salida

Para cada dimensión de review, brindá:
- **Veredicto**: PASS / NEEDS WORK / FAIL
- **Hallazgos**: Issues específicos con referencias de archivo y línea
- **Sugerencias**: Fixes o mejoras concretas

Luego brindá:
- **Nivel de riesgo general**: Low / Medium / High / Critical
- **Resumen**: Evaluación general de 2-3 oraciones
- **Issues bloqueantes**: Issues que deben corregirse antes del merge (si hay)
- **Sugerencias de mejora**: Recomendaciones no bloqueantes para mejor calidad de código

Guardá el review completo en `reviews/REVIEW-RFC-[ID].md`. Un review que existe solo en el chat deja a la siguiente sesión mirando código ya corregido sin registro de qué se chequeó, qué se encontró o qué se aceptó de forma consciente como no bloqueante -- y `/workflow-status` busca este archivo al reportar si un RFC realmente fue revisado.
