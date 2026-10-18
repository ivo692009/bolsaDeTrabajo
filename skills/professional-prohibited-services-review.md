# Skill 21: Revisión incremental de servicios profesionales prohibidos

## Objetivo
Impedir la creación o publicación de perfiles cuyo servicio ofrecido facilite actividades ilegales, explotación o daño grave. Mantener los criterios ampliables de forma incremental, con revisión de casos ambiguos y trazabilidad de cambios.

## Cuándo aplicarla
- Antes de crear/publicar un perfil profesional.
- Cada vez que se agregue o cambie una categoría, tipo de trabajo, alias o descripción de servicio.
- Al revisar un reporte concreto sobre una tarea ofrecida.

## Procedimiento de evaluación
1. Evaluar la actividad concreta que se ofrece y el propósito descrito, incluyendo categorías, tipos, alias y descripción; no decidir únicamente por el nombre, identidad, nacionalidad, ocupación previa u otros atributos de la persona.
2. Comparar la tarea con las clases prohibidas de esta skill y sus ejemplos acumulados.
3. Si la oferta coincide claramente con una clase prohibida, negar la creación/publicación de ese servicio, explicar brevemente que la plataforma no acepta esa actividad y dejar constancia mínima de la regla aplicada. No ayudar a reescribirla para ocultar su propósito.
4. Si la tarea es ambigua, pedir una aclaración breve y neutral. Mientras no se resuelva, no publicar esa tarea; derivar a `catalog_manager` o a una persona revisora autorizada. No bloquear otros servicios legítimos del perfil salvo que también estén implicados.
5. Si el profesional puede ofrecer servicios permitidos separables, permitir que quite o reemplace solo las tareas prohibidas y continuar la revisión de las restantes.
6. No inferir ilegalidad por términos aislados si el contexto indica un uso lícito (por ejemplo, servicios legales, sanitarios, educativos, de prevención o seguridad autorizada). Si persiste la duda, revisión humana antes de publicar.

## Clases prohibidas iniciales
Rechazar tareas cuyo objeto sea promover, facilitar, proveer medios o ejecutar:
- Producción, venta, distribución o transporte ilícito de drogas o sustancias controladas; fabricación de drogas, adulteración o evasión de controles.
- Captación, publicidad, intermediación o explotación comercial de servicios sexuales, incluida la trata, coerción o explotación de personas. No clasificar automáticamente servicios sanitarios, de acompañamiento no sexual ni recursos de asistencia como actividad prohibida.
- Fabricación, venta, modificación o suministro ilícito de armas, municiones o explosivos; tráfico o provisión de armas para violencia. No bloquear por coincidencia de palabra los servicios de seguridad autorizados, cerrajería, reparación lícita ni actividades deportivas reguladas.
- Trata de personas, trabajo forzado, explotación, violencia por encargo, amenazas, secuestro, robo, tráfico de bienes ilícitos o evasión deliberada de controles legales.
- Estafas, suplantación, falsificación, robo de credenciales, lavado de dinero u otros servicios cuyo fin declarado sea engañar, robar o encubrir delitos.
- Cualquier otra tarea que el solicitante describa como ilícita o que claramente facilite un delito o daño grave.

## Actualización incremental de criterios
1. Cuando una nueva expresión o caso revele una laguna, registrar propuesta de actualización con: término/tarea, contexto en que apareció, clase prohibida relacionada, posibles usos legítimos y riesgo de falsos positivos.
2. El `catalog_manager` revisa la redacción para evitar que una palabra ambigua se convierta por sí sola en prohibición. Si el cambio afecta decisiones de acceso o requiere interpretación, obtener aprobación del responsable de la política antes de publicarlo.
3. Agregar el nuevo ejemplo o criterio en la clase correspondiente, con fecha y breve motivo en el historial de cambios. Mantener sin cambios la decisión sobre casos previos, salvo revisión explícita.
4. Evaluar las categorías y alias existentes al actualizar la skill y poner en revisión las coincidencias dudosas; no borrar perfiles ni sancionar retroactivamente de forma automática.

## Registro, privacidad y comunicación
- Registrar solo ID interno de perfil/caso, tareas revisadas, regla aplicada, resultado, fecha y persona revisora cuando corresponda. Evitar copiar teléfonos, direcciones o relatos sensibles.
- Comunicar una decisión concreta y neutral: qué tarea no puede publicarse y cómo corregir el perfil o pedir revisión. No etiquetar públicamente al profesional como delincuente.
- No solicitar documentos de identidad, credenciales bancarias ni detalles innecesarios por WhatsApp para esta evaluación.

## Restricciones
- El bot puede identificar una coincidencia clara y detener la publicación de la tarea; no determina culpabilidad penal ni sanciona a la persona.
- Los casos ambiguos y las decisiones de vinculación/legalidad requieren revisión humana; no rechazar un perfil entero por una palabra, alias o denuncia aislada.
- No ofrecer instrucciones para realizar, ocultar o reformular actividades prohibidas a fin de evadir el control.
- Hasta implementar el filtro de alta/edición y su registro en el webhook, no afirmar que el control se ejecutó.

## Resultado esperado
Las tareas claramente prohibidas no se publican; las ambiguas quedan pendientes de aclaración/revisión; los servicios legítimos separables pueden continuar; y los criterios se amplían con cambios documentados y revisables.

## Historial incremental
- 2026-10-17: versión inicial; incluye drogas ilícitas, explotación sexual/trata, armas ilícitas, violencia, contrabando, estafas y facilitación de otros delitos.
