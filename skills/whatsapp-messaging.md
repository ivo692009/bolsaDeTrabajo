# Skill 01: Gestión de mensajería WhatsApp (Meta API)

## Objetivo
Gestionar la comunicación bidireccional entre clientes, profesionales y el sistema mediante WhatsApp Business Platform de Meta.

## Implementación inicial
El webhook local está implementado en `src/whatsapp/whatsapp-bot.ps1` para Windows PowerShell 5.1. Su configuración y conexión con Meta se documentan en `docs/operations/whatsapp-bot.md`.

## Acciones
- Recibir mensajes entrantes y asociarlos al número de teléfono y conversación correspondientes.
- Enviar respuestas automatizadas y plantillas aprobadas cuando corresponda.
- Entregar mensajes de estado sobre solicitudes, propuestas y conexiones.
- Registrar identificadores, marcas de tiempo y estados de entrega disponibles en la API.
- Persistir el ID de cada mensaje entrante de Meta en `runtime/webhook-events/<year>.xml` para deduplicar webhooks repetidos antes de ejecutar acciones.
- Procesar `BAJA` como intent prioritario y bloquear cualquier mensaje saliente a ese remitente hasta `ACEPTO MENSAJES`; aplicar la preferencia en el webhook y en el envío central.
- Usar exclusivamente la API oficial de Meta para WhatsApp; no cambiar a otros canales ni dirigir a páginas o aplicaciones externas.

## Entradas
- Evento entrante validado de Meta.
- Número de teléfono y mensaje del usuario.
- Estado de la solicitud y datos autorizados para comunicar.

## Restricciones
- Usar únicamente credenciales almacenadas de forma segura; nunca incluir tokens en mensajes, logs o respuestas.
- Respetar consentimiento, preferencias de contacto, políticas de Meta y la ventana de atención aplicable. Fuera de ella, usar una plantilla aprobada cuando sea necesario.
- No guardar el E.164 en la lista de preferencias; usar el HMAC con la clave estable `WA_PREFERENCES_HMAC_KEY`.
- No enviar datos personales de terceros sin autorización.
- Validar la autenticidad de webhooks antes de procesar eventos y evitar duplicar mensajes ante reintentos.
- Aceptar POST solo en `/webhook`, con HMAC-SHA256 válido; verificar el handshake GET con `WA_VERIFY_TOKEN`.
- Procesar escrituras por una sola cola; validar el XML temporal antes del reemplazo atómico y respaldar el original.
- Si el ID ya está registrado, devolver respuesta exitosa al webhook sin repetir efectos de negocio.
- No afirmar que un mensaje fue entregado si la API no confirmó ese estado.

## Resultado esperado
Mensaje enviado o evento procesado con estado verificable; si hay error, registrar el motivo técnico sin exponer secretos y permitir reintento controlado.
