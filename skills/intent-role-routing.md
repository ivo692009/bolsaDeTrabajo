# Skill 09: Detección de intención y contexto de rol

## Objetivo
Determinar qué flujo corresponde a cada mensaje de WhatsApp sin fijar permanentemente a una persona en un único rol.

## Flujo de decisión
1. Usar el número remitente verificado de WhatsApp para consultar si existe un perfil profesional único.
2. Clasificar la intención del mensaje actual:
   - Administrar perfil o capacidades propias: activar el flujo profesional y exigir coincidencia exacta del número.
   - Responder a una solicitud, confirmar un precio, informar finalización o enviar comprobante: activar el flujo profesional y exigir coincidencia exacta del número.
   - Buscar o contratar un servicio: activar el flujo de cliente, incluso si el remitente también tiene perfil profesional.
   - Registrarse como profesional: iniciar alta y vincular el perfil exclusivamente al número remitente verificado.
3. Mantener el rol como contexto de la acción actual, no como una condición global de la persona. Cambiar de profesional a cliente según la intención explícita sin modificar ni duplicar su perfil profesional.
4. Si la intención no está clara, preguntar si desea administrar su perfil, responder a un trabajo o buscar un servicio; no ejecutar acciones hasta aclarar.
5. Antes de cada operación protegida, volver a validar la identidad y el permiso correspondiente.

## Restricciones
- El número de WhatsApp del evento entrante es la única credencial de identidad para el perfil profesional. No usar nombre, redes sociales, ID interno ni texto declarado para suplantar la coincidencia.
- Una coincidencia profesional no impide que la misma persona actúe como cliente.
- La intención de buscar un profesional no autoriza a leer ni modificar el perfil profesional.
- Si el número no coincide con un perfil, tratar el mensaje como cliente o iniciar el alta solo cuando la intención sea explícita.
- No inferir intención únicamente por el historial; dar prioridad al mensaje actual y al contexto confirmado.

## Resultado esperado
Una acción en el flujo correcto, con permisos verificados y el rol limitado al contexto de esa acción.
