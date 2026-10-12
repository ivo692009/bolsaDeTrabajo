# Skill 06: Seguimiento y reseñas

## Objetivo
Cerrar el ciclo de una solicitud, recopilar comentarios y registrar la comisión aplicable según la configuración acordada.

## Acciones
- Al aceptar el profesional, programar el seguimiento según `follow_up_delay_hours` configurado en las reglas del proyecto.
- Solicitar una reseña al cliente únicamente después de confirmar que el servicio concluyó.
- Registrar la respuesta, la valoración y el estado en el XML local de solicitudes.
- Solicitar por WhatsApp a Cliente y Profesional que confirmen `completed` o `cancelled`; repetir la consulta cada 24 horas con un máximo de dos reintentos.
- Si ambas partes confirman `completed`, iniciar `commission-settlement.md` y solicitar una reseña al Cliente.
- Si ambas partes confirman `cancelled`, registrar la cancelación y cerrar sin reseña ni comisión.
- Si nadie responde tras los dos reintentos, cerrar como `closed_unconfirmed`, conservar historial y no cobrar.
- Si difieren, solicitar confirmación nuevamente hasta dos veces; si continúa el desacuerdo, dejar la solicitud en revisión y no cobrar.

## Restricciones
- No asumir que el trabajo terminó ni enviar más de dos reintentos; detener recordatorios cuando ambas partes respondan o la solicitud se cierre.
- No publicar reseñas sin consentimiento; no modificar su contenido para cambiar su sentido.
- Si el Cliente informa que el trabajo no se completó correctamente o existe una disputa, detener el flujo de comisión y dejar la solicitud pendiente de resolución.

## Resultado esperado
Seguimiento oportuno, reseña asociada a una solicitud concluida y derivación al proceso de comisión solo tras confirmar la finalización correcta.
