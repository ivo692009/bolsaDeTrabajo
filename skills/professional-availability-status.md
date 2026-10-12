# Skill 10: Activación y pausa del perfil profesional

## Objetivo
Permitir que un profesional deje de recibir nuevas ofertas y reactive su perfil usando el mismo número de WhatsApp verificado.

## Flujo
1. Obtener y normalizar el número remitente de WhatsApp a E.164.
2. Buscar una coincidencia exacta y única con el perfil profesional. Si no existe o hay duplicados, no cambiar el estado y derivar a revisión.
3. Para pausar, confirmar la intención y actualizar `availabilityStatus` a `inactive`; conservar sin cambios el estado de ciclo de vida del perfil (`draft`, `active` o `suspended`). Registrar número remitente, valor anterior, valor nuevo y fecha.
4. Excluir inmediatamente el perfil de nuevas búsquedas y ofertas.
5. No cancelar solicitudes ya aceptadas ni alterar su historial. Las ofertas ya pendientes conservan su vencimiento configurado; no crear ofertas adicionales mientras esté inactivo.
6. Para reactivar, aceptar la solicitud enviada desde el mismo número y cambiar `availabilityStatus` a `active`, conservando el estado de ciclo de vida, perfil, rubros, trabajos e historial.
7. Confirmar por WhatsApp el cambio efectivo.

## Restricciones
- Solo el mismo número verificado vinculado puede solicitar la pausa o reactivación.
- Pausar no borra ni desactiva permanentemente el perfil.
- No aceptar solicitudes de cambio de número mediante esta skill; los cambios de número siguen el proceso de revisión autorizada.
- No marcar el perfil activo si la actualización XML falla; preservar el estado anterior.

## Resultado esperado
`availabilityStatus` actualizado a `active` o `inactive` una sola vez, con trazabilidad local y sin alterar el ciclo de vida ni afectar trabajos ya aceptados.
