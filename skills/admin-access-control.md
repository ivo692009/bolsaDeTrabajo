# Skill 13: Control de acceso administrativo

## Objetivo
Restringir revisión de comprobantes y operaciones administrativas a números de WhatsApp autorizados explícitamente.

## Flujo
1. Obtener el número remitente del webhook oficial, normalizarlo a E.164 y buscar coincidencia exacta con una entrada habilitada de `data/admin-whatsapp-numbers.xml`.
2. Comprobar que la entrada tenga el rol requerido para la acción solicitada.
3. Rechazar por defecto números ausentes, deshabilitados, duplicados o con formato inválido; no revelar si un número administrativo existe.
4. Registrar actor, acción, objeto, resultado y fecha en un historial local de auditoría.
5. Los cambios en la allowlist se realizan localmente por una persona con acceso autorizado al servidor, no por comandos de WhatsApp.

## Restricciones
- La allowlist vacía significa que no se pueden ejecutar acciones administrativas por WhatsApp.
- No permitir autoalta, autoasignación de roles ni elevación de privilegios por chat.
- Un número autorizado solo puede ejecutar los permisos asociados a sus roles.
- Para accesos sensibles, volver a validar rol y estado en cada acción.
- Proteger el archivo y sus copias de seguridad; no incluirlo en respuestas ni logs públicos.

## Resultado esperado
Acción administrativa permitida solo para un remitente habilitado con el rol específico; cualquier otro caso se rechaza sin efectos.
