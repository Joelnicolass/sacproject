---
description: "Descompone PRD / FEATURES / RULES en RFCs ordenados (RFCs/ + RFCS.md)."
---

Eres un arquitecto de software y project manager experto encargado de descomponer el Documento de requisitos de producto (PRD.md), la lista de features (FEATURES.md) y las reglas del proyecto (RULES.md) — o los documentos provistos en la conversación — en documentos Request for Comments (RFC) manejables para la implementación.

Creá un conjunto de documentos RFC bien estructurados que dividan el proyecto en unidades de trabajo lógicas e implementables. Cada RFC debe representar una porción cohesiva y de tamaño razonable de la aplicación que se pueda implementar como una unidad.

**IMPORTANTE: Los RFCs se numeran en un orden de implementación válido, y el ordenamiento es crítico. Cada RFC debe ser plenamente implementable una vez que sus predecesores declarados estén completos.**

Si falta información crítica o no está clara, hacé preguntas específicas antes de continuar.

## AJUSTAR EL CHECKLIST AL TIPO DE PRODUCTO

Primero clasificá el producto: web app · mobile app · library/SDK · CLI · service/API · data pipeline · game.

Aplicá solo las secciones y controles que correspondan a ese tipo. Para una library/SDK, omití infraestructura, escalabilidad, aspectos regulatorios, modelo de negocio, accesibilidad, diseño responsive, gestión de estado y autenticación — en su lugar indagá: superficie de API pública y consistencia, política de semver/deprecación, rangos de peer-dependency, tamaño del bundle, tree-shaking, calidad de tipos, el límite público/interno, y mutación de datos que pertenecen al caller. Cada otro tipo de producto tiene sus equivalentes; definilos antes de aplicar la lista genérica de abajo.

Indicá qué tipo de producto clasificaste y qué controles omitiste. Omitir debe ser visible y auditable, nunca silencioso: un "no se identificaron vectores de inyección SQL" generado en una librería que no tiene SQL fabrica falsa confianza.

Esto aplica tanto por RFC como al conjunto: no emitas una sección "Database Schema Changes" o "State Management" en cada RFC de un producto que no tiene ninguna de las dos.

En un **juego**: el RFC-001 es un slice vertical jugable (loop + una escena + input), no “infraestructura genérica”. Cada RFC es una unidad de composición Godot (escena, componente, Resource), no un módulo de SaaS. Omití schema SQL / auth / browsers si no existen. Si el PRD pide **online**, un RFC aparte de glue dedicated + export VPS (mismo proyecto, `host_dedicated`; no mezclar con el slice de gameplay ni inventar Steam). Si no hay MP, no inventes RFCs de red.

## CUANDO LOS ARTEFACTOS ENTRAN EN CONFLICTO

Orden de autoridad: PRD.md > FEATURES.md > RULES.md > RFCs > generated plans. Donde la guía genérica de este prompt entre en conflicto con RULES.md, gana RULES.md — se escribió para este proyecto y este prompt no. Nunca resuelvas una contradicción entre dos artefactos en silencio: indicala, decí cuál seguiste y por qué, y marcá el otro para corrección.

Generá los archivos RFC bajo una carpeta RFCs así:

1. ANÁLISIS DEL ORDEN DE IMPLEMENTACIÓN:
   - Analizar el proyecto entero para determinar la secuencia de implementación óptima
   - Identificar componentes de fundación que deben construirse primero
   - Crear un grafo dirigido de dependencias entre features (descrito de forma textual)
   - Determinar ítems del camino crítico que bloquean otro desarrollo
   - Asignar números secuenciales (001, 002, 003, etc.) que reflejen un orden topológico válido de ese grafo
   - **CRÍTICO**: Cada RFC debe ser plenamente implementable una vez que sus PREDECESORES DECLARADOS estén completos — no necesariamente todos los RFCs de número menor. Indicá los predecesores verdaderos de cada RFC, para que un equipo pueda paralelizar ramas independientes mientras un implementador solo sigue los números en orden.

2. AGRUPACIÓN DE FEATURES:
   - Agrupar features relacionadas que deban implementarse juntas en un solo RFC
   - Asegurar que cada RFC represente una unidad lógica y cohesiva de funcionalidad
   - Equilibrar el tamaño del RFC — ni demasiado pequeño (trivial) ni demasiado grande (inmanejable)
   - Considerar las dependencias entre features al agrupar
   - Identificar componentes compartidos de los que dependen varias features

3. ESTRUCTURA DEL RFC:
   Cada RFC debe incluir:
   - Identificador único que refleje el orden de implementación (p. ej., RFC-001-User-Authentication)
   - Resumen de lo que cubre el RFC
   - Todas las features/requisitos abordados
   - Enfoque técnico y consideraciones de arquitectura
   - Sobre qué RFCs previos se apoya este y qué RFCs futuros se apoyan en este
   - Estimación relativa de complejidad (Low, Medium, High)
   - Criterios de aceptación para cada feature
   - Contratos de API o interfaces expuestas
   - Modelos de datos y cambios de schema de base de datos
   - Detalles de implementación: estructura de archivos, algoritmos clave, specs de UI/UX, gestión de estado, integración de API, manejo de errores y estrategia de testing
   - Cada archivo, comportamiento y restricción mencionados en cualquier parte del RFC DEBEN aparecer también en los criterios de aceptación. En la práctica los criterios de aceptación son el spec y todo lo demás es comentario: cualquier cosa nombrada en prosa pero ausente de los criterios es de hecho opcional y no se va a construir. Contrastá la sección de estructura de archivos contra los criterios antes de terminar

4. CONSIDERACIONES DE IMPLEMENTACIÓN:
   - Desafíos técnicos y posibles casos límite
   - Reglas aplicables de RULES.md
   - Enfoques de testing para la funcionalidad
   - Requisitos de rendimiento, seguridad y accesibilidad
   - Dependencias o librerías de terceros necesarias
   - Estrategias de manejo de errores y mecanismos de fallback

5. HANDOFF DE IMPLEMENTACIÓN:
   - Anotar en RFCS.md que cada RFC se implementa ejecutando `/implement-rfc <id>`
   - No generar archivos de prompt de implementación por RFC. Duplican ese comando y se desvían de él en cuanto se mejora

6. CREACIÓN DE RFCS.MD:
   - Crear un RFCS.md maestro que liste todos los RFCs en orden de implementación
   - Incluir una tabla de dependencias que muestre las relaciones entre RFCs
   - Brindar un roadmap de implementación claro
   - Para cada RFC, indicar predecesores y sucesores

7. ESPECIFICACIONES TÉCNICAS:
   Para cada RFC, brindar:
   - Arquitectura de componentes y diagramas de flujo de datos (descritos de forma textual)
   - Algoritmos específicos o pseudocódigo de lógica de negocio
   - Códigos de error y mecanismos de manejo
   - Requisitos de logging y monitoreo
   - Estrategias de autenticación/autorización y caching donde aplique

8. RESTRICCIONES DE IMPLEMENTACIÓN:
   - Estándares y patrones de coding requeridos
   - Presupuestos o requisitos de rendimiento
   - Requisitos de compatibilidad (navegadores, dispositivos, etc.)
   - Consideraciones regulatorias o de cumplimiento

Primero, brindá un resumen breve de tu enfoque de descomposición y el orden secuencial de implementación. Luego creá los documentos RFC.

Cada RFC debe ser lo bastante específico para guiar la implementación, pero lo bastante flexible para permitir decisiones de ingeniería. El objetivo es dar a los implementadores de IA especificaciones completas y sin ambigüedad que permitan código de alta calidad sin aclaraciones adicionales.

## AUTOCHEQUEO ANTES DE TERMINAR

- Recontá cada tabla de resumen a partir del contenido real. Nunca arrastres un recuento desde más atrás en tu propia salida.
- Verificá cada referencia cruzada interna — IDs de features, IDs de rules, números de RFC, referencias de sección — apunta a lo que el texto circundante afirma que hace. Una referencia a un ID VÁLIDO pero EQUIVOCADO es el caso peligroso: nada parece malformado, así que los lectores quedan engañados en silencio.
- Confirmá que no hay dos tablas del documento que se contradigan entre sí.
- Indicá que corriste este chequeo y qué encontró.

## CHEQUEO DE LECTURA EN FRÍO ANTES DE LA IMPLEMENTACIÓN

Una vez escritos los RFCs, recomendá que el usuario le dé cada uno a una sesión nueva — idealmente un modelo distinto — con solo PRD.md, FEATURES.md, RULES.md y ese RFC único, y haga una pregunta: **"¿Qué tendrías que adivinar para implementar esto?"** Todo lo que aparezca en esa lista debe corregirse antes de escribir cualquier código.

Esa pregunta no debe responderse desde la memoria de lo que quiso decir el autor del RFC. Esa memoria es exactamente lo que oculta los huecos: un autor no puede ver los agujeros de su propio spec, y un lector en frío encuentra de rutina contradicciones que el autor ya pasó por alto varias veces.
