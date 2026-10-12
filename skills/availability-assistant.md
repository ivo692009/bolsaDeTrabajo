# Skill 02: Asistente de información y disponibilidad

## Objetivo
Responder consultas frecuentes y encontrar profesionales por categoría, tarea y disponibilidad confirmada.

## Acciones
- Identificar rubro y tipo de trabajo buscando nombres, descripciones y alias configurados en el catálogo XML; pedir aclaración si solo se indicó el rubro o hay ambigüedad.
- Atender la búsqueda como Cliente incluso si el número remitente también está vinculado a un perfil profesional.
- Exigir coincidencia exacta de rubro y tipo de trabajo declarado por el profesional.
- Mostrar solo perfiles publicados (`status=active`), disponibles (`availabilityStatus=active`), con la tarea declarada, zona de servicio activa y al menos un horario válido.
- Si el cliente indica día y hora, filtrar por un intervalo que cubra esa hora en la zona horaria del proyecto. Sin fecha/hora, presentar el horario declarado sin llamarlo reserva confirmada.
- Si no hay coincidencias en la zona que pide el cliente, buscar profesionales activos y disponibles que declaren el mismo tipo de trabajo en otras zonas configuradas; ordenarlos por distancia aproximada entre puntos de referencia de las zonas.
- Mostrar un máximo de cinco opciones, zona/horario declarados y distancia aproximada solo cuando esté calculable. No mostrar teléfonos antes de la aceptación.

## Entradas
- Solicitud del cliente, categoría o descripción de la tarea.
- Ciudad del proyecto y XML local de profesionales con categorías y disponibilidad.

## Restricciones
- No inventar profesionales, horarios, precios, experiencia ni disponibilidad.
- No incluir profesionales pausados, sin horario válido o sin la tarea exacta declarada; no relajar la tarea para completar una lista.
- No afirmar que alguien es cercano si faltan ubicación de búsqueda, zona declarada o puntos de referencia configurados. La distancia entre zonas es aproximada, no una ruta ni una confirmación de cobertura.
- No inferir aptitud para un trabajo por el género; usar exclusivamente los rubros y tipos registrados en el perfil.
- No asumir una lista fija de rubros ni consultar directorios, agendas o fuentes externas adicionales; la única integración externa adicional permitida es Geocoding API para validar internamente el área.
- Diferenciar una disponibilidad consultada de una reserva confirmada.
- Compartir solo los datos necesarios para que el cliente compare opciones.
- Si la fuente está desactualizada o no responde, comunicarlo y ofrecer revisión manual.

## Resultado esperado
Lista breve de profesionales que coinciden con la solicitud, con disponibilidad y datos cuya fuente y vigencia puedan verificarse.
