# Skill 05: Intermediación y conexión de clientes

## Objetivo
Coordinar una solicitud de trabajo y conectar al cliente con un profesional solo después de obtener la aceptación de este.

## Flujo
1. Recibir la necesidad del cliente y recopilar los datos mínimos para describir la tarea. Un remitente con perfil profesional también puede iniciar este flujo como Cliente.
2. Mostrar profesionales del XML que coincidan con rubro, tipo de trabajo, ciudad y disponibilidad registrada.
3. Permitir que el cliente seleccione un profesional y registrar la solicitud localmente con estado `offered`.
4. Notificar al profesional por WhatsApp como posible trabajo, incluyendo detalles básicos de la tarea y sin revelar el teléfono del cliente.
5. Registrar la respuesta como `accepted` o `rejected`; si acepta, cambiar a `connected` y compartir los contactos por WhatsApp.
6. Si rechaza, informar al cliente por WhatsApp y ofrecer otros profesionales disponibles del XML.
7. Si no responde, esperar el plazo configurado; al vencer, marcar `no_response`, informar al cliente y ofrecer alternativas. Sin plazo configurado, mantener `offered` pendiente.
8. Registrar cada trabajo incluido y su importe de mano de obra en ARS. Sumar esas líneas y persistir el subtotal solo cuando Cliente y Profesional confirmen el mismo monto. Materiales y trámites quedan fuera de la base de comisión.
9. Si un Profesional acepta la derivación y luego la cancela, registrar el estado, momento, etapa (antes o después de acordar alcance/precio/duración) y el motivo declarado; ofrecer alternativas al Cliente y no revelar datos de contacto antes de una aceptación válida.
10. Si el Profesional cancela sin motivo o no responde, solicitar una explicación neutral una sola vez, sin presionar ni impedir que decline un trabajo. Contabilizar como señal de patrón solo cancelaciones repetidas y diferenciadas dentro de 60 días; derivar el patrón a `professional_reliability_admin` para revisión.

## Restricciones
- La selección del cliente no equivale a aceptación del profesional ni a una reserva confirmada.
- No compartir datos de contacto del cliente con el profesional hasta que exista aceptación y autorización según las reglas del proyecto.
- No presentar una propuesta como trabajo confirmado antes de registrar la aceptación.
- Si agregan un trabajo o cambia el importe, actualizar las líneas y solicitar a ambas partes una nueva confirmación del subtotal; no calcular la comisión durante este flujo.
- Conservar el historial de estados y evitar conexiones duplicadas para la misma solicitud.
- No etiquetar una cancelación como fraude por sí sola, no penalizar rechazos previos a la aceptación y no atribuir responsabilidad automáticamente a partir de la versión de una parte.
- Una señal de cancelación reiterada sin motivo solo permite abrir una revisión del patrón; una restricción temporal de nuevas derivaciones requiere decisión explícita, motivada y registrada de una persona autorizada, con aviso al Profesional y posibilidad de aportar contexto.
- No sumar cancelaciones anteriores al acuerdo a los casos de incumplimiento de trabajos acordados ni aplicar automáticamente las suspensiones definidas para esos casos.
- No usar otros canales ni derivar a sitios o aplicaciones externas para cerrar la conexión.

## Resultado esperado
Solicitud trazable con estado actualizado y, únicamente tras aceptación, contacto habilitado entre ambas partes.
