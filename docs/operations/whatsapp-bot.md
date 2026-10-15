# Servicio inicial de WhatsApp

El servicio usa PowerShell 5.1 y componentes .NET incluidos en Windows; no requiere paquetes npm. Implementa el webhook de Meta, verificación HMAC-SHA256, deduplicación por ID de mensaje, escritura XML atómica con copias diarias y respuestas en español. Las acciones de negocio siguen siendo deterministas; las preguntas generales pueden usar opcionalmente el chatbot LLM.

## Prueba local

Desde la raíz del proyecto, en PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\src\whatsapp\whatsapp-bot.ps1 -SelfTest
```

El cambio de política aplica solo a esa sesión. El modo de autoprueba no lee secretos ni llama a Meta.

## Configuración

En el primer arranque, si faltan, el servicio inicializa `runtime/data/professionals.xml`, `runtime/data/requests.xml` y `runtime/data/admin-whatsapp-numbers.xml` desde plantillas vacías de `data/templates/`. Esos XML pueden contener datos personales y `.gitignore` los excluye del repositorio.

Crea una aplicación en Meta for Developers, agrega el producto WhatsApp y registra un número empresarial en WhatsApp Cloud API. No compartas el número personal: Meta debe indicar el `Phone Number ID` correspondiente al número empresarial.

El módulo `src/whatsapp/runtime-config.ps1` resuelve la configuración en un único lugar y lee `.env` desde la raíz sin evaluar comandos. Una variable ya definida en el entorno del proceso tiene prioridad sobre el archivo. `.env` está excluido de Git. Copia solo los valores que uses desde `config/whatsapp-bot.env.example` a `.env`; nunca completes ni publiques valores reales en la plantilla. También puedes inyectar los valores mediante el administrador de secretos del proceso:

- `META_APP_ID`: ID de la aplicación Meta (solo referencia).
- `META_BUSINESS_ID`: ID del negocio mostrado en la configuración de Meta (solo referencia).
- `WA_BUSINESS_ACCOUNT_ID`: ID de la cuenta de WhatsApp Business (solo referencia).
- `WA_TEST_PHONE_NUMBER`: número de prueba asignado por Meta.
- `WA_APP_SECRET`: App Secret de la aplicación Meta; se usa para verificar la firma del webhook.
- `WA_PREFERENCES_HMAC_KEY`: clave aleatoria de 32 bytes codificada como 64 caracteres hexadecimales para seudonimizar las preferencias `BAJA`; mantenla estable aunque rotes el App Secret de Meta.
- `WA_VERIFY_TOKEN`: valor aleatorio elegido por el administrador para el handshake del webhook. Debe coincidir en Meta y en el proceso.
- `WA_ACCESS_TOKEN`: token de acceso con permisos de WhatsApp Cloud API para enviar mensajes.
- `WA_PHONE_NUMBER_ID`: Phone Number ID que entrega Meta para el número registrado.
- `WA_GRAPH_API_VERSION`: versión Graph actualmente soportada por la aplicación, con formato `vNN.0`.
- `WA_OPENAI_MODERATION_TIMEOUT_SECONDS`: timeout para moderación; por defecto `12`.
- `WA_OPENAI_RESPONSE_TIMEOUT_SECONDS`: timeout para la generación de respuestas; por defecto `25`.
- `WA_WHATSAPP_REQUEST_TIMEOUT_SECONDS`: timeout al enviar mensajes a Meta; por defecto `20`.- `OPENAI_API_KEY`: clave API de OpenAI (opcional; si falta, las preguntas generales reciben una respuesta de disponibilidad limitada).
- `OPENAI_MODEL`: modelo habilitado para tu proyecto API; opcional, por defecto `gpt-6-astra`.

Genera la clave HMAC de preferencias con este comando de PowerShell y copia el resultado de 64 caracteres hexadecimales a `.env`:

```powershell
$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($randomBytes); [BitConverter]::ToString($randomBytes).Replace('-', '').ToLowerInvariant() }
finally { $rng.Dispose() }
```

La clave es obligatoria para iniciar el servicio. Guárdala junto a los otros secretos en el `.env` local o en el entorno del proceso, y conserva una copia segura: cambiarla impediría reconocer las bajas guardadas. La clave de OpenAI se lee del mismo `.env` local o del entorno del proceso; nunca la guardes en archivos versionados. La integración usa la Responses API. Requiere un proyecto API con facturación/acceso configurado y conexión saliente HTTPS desde el servidor. ChatGPT Plus/Pro no sustituye una clave de API.

Los IDs y el número de prueba se cargaron en el `.env` local. **El token que apareció en la captura debe regenerarse en Meta antes de usarlo**; el `.env` deja `WA_ACCESS_TOKEN` vacío para que ingreses el nuevo token directamente en tu equipo. Completa también `WA_APP_SECRET` y genera un `WA_VERIFY_TOKEN` privado. No los pegues en conversaciones ni los guardes en archivos versionados.

`config/whatsapp-bot.env.example` documenta los nombres de las variables sin valores reales.

## Conectar el webhook

1. Expón el servicio local mediante un reverse proxy o túnel HTTPS administrado por ti. Meta no puede conectarse a `localhost`.
2. Configura el proxy para reenviar `https://TU-DOMINIO/webhook` al listener local `http://127.0.0.1:8080/webhook`.
3. Ejecuta el servicio:

```powershell
.\src\whatsapp\whatsapp-bot.ps1 -Port 8080
```

4. En la configuración del webhook de Meta, usa `https://TU-DOMINIO/webhook`, el mismo `WA_VERIFY_TOKEN` y suscríbete a `messages` para la cuenta de WhatsApp Business.
5. Confirma que el handshake GET termina correctamente. Los POST se aceptan únicamente con `X-Hub-Signature-256` válida.
6. Usa el número de prueba y destinatarios permitidos por Meta para probar recepción y respuesta antes de producción.

El listener se enlaza solo a `127.0.0.1`; no lo expongas directamente a Internet. El proxy debe terminar TLS, preservar el path `/webhook` y limitar tamaño y tasa de solicitudes.

## Qué responde el MVP

- `hola`, `menu` o `ayuda`: opciones disponibles.
- `buscar instalar luminaria en Rawson`: exige rubro/tarea específicos y muestra perfiles publicados, disponibles, con horario/zona válidos y esa tarea declarada; no muestra teléfonos.
- `buscar reparar fuga de agua en Playa Unión lunes 10:00`: además filtra por el horario declarado. Si no hay perfiles en esa zona, ordena alternativas que hacen la misma tarea por cercanía aproximada entre zonas configuradas.
- `mi perfil`, `pausar perfil`, `reactivar perfil`: consulta o cambia disponibilidad solo si el número remitente coincide de forma única con un perfil profesional publicado.
- `cuadrilla 3`: registra tres trabajadores adicionales a cargo (cuatro personas en total contando al profesional) en el perfil asociado al remitente autenticado.
- El flujo documentado `borrar mis datos` dejará el perfil fuera de búsquedas y requerirá revisión de `commission_admin`; los comandos ejecutables de solicitud/aprobación todavía no están implementados.
- `acepto A7K2` o `rechazo A7K2`: responde a una oferta pendiente solo si código, perfil y remitente coinciden y la ubicación ya está validada.
- Mensajes que describen urgencias reciben una respuesta segura; el bot no coordina emergencias ni inventa teléfonos locales.
- Cualquier otro mensaje compatible con texto que no sea un comando reconocido puede recibir una respuesta conversacional del modelo OpenAI, con el contexto y límites definidos en `config/business/chatbot-context.md`.
- `BAJA`: bloquea todos los mensajes automatizados al remitente sin enviar respuesta. `ACEPTO MENSAJES`: registra el reconsentimiento y vuelve a habilitarlos. Mientras la baja esté activa, cualquier otro mensaje entrante se ignora.

La ubicación está configurada para Rawson y Playa Unión, pero falta cargar los polígonos oficiales y puntos representativos en `data/policies/location-policy.xml`. Sin esos puntos el bot no puede afirmar cuál alternativa es más cercana; los perfiles deben declarar zonas en `serviceAreas` y horarios válidos. La distancia es aproximada entre centroides de zonas, no una ruta. Por seguridad, no valida direcciones ni crea ofertas mientras el polígono siga pendiente. El perfil de muestra está en borrador/inactivo y no aparecerá en listados.

## Límites y operación

- Las operaciones (buscar perfiles, gestionar el propio perfil y responder ofertas) siguen deterministas y no dependen del modelo. Las preguntas generales usan OpenAI si `OPENAI_API_KEY` está configurada; el modelo no ejecuta acciones ni consulta por su cuenta el catálogo o los datos privados XML.
- El contexto del negocio editable está en `config/business/chatbot-context.md`. Modifícalo solo con información aprobada, y mantén explícita la diferencia entre funciones implementadas y planeadas.
- El LLM puede orientar qué tipo de profesional suele corresponder a una tarea o sus características, pero no diagnostica ni asegura disponibilidad o calificaciones. Rechaza temas ajenos al proyecto y solicitudes de contenido ofensivo; el webhook filtra vocabulario conocido y consulta Moderations API tanto para las entradas como para las respuestas generadas. Si la moderación no está disponible, usa el fallback sin generar con el LLM.
- No se proporcionan al modelo perfiles XML, teléfonos, pagos ni datos personales. Tampoco debe revelar o inferir datos personales en sus respuestas.
- El historial conversacional local guarda hasta cuatro intercambios por remitente, identificado con HMAC del número usando el secreto de Meta, en `runtime/chatbot-conversations.xml`; se conservan hasta 30 días y el archivo se excluye de Git. Cada solicitud envía ese contexto reciente a OpenAI, con `store=false`. Las preguntas y respuestas se procesan en el proveedor externo; evita incluir datos sensibles.
- El LLM puede equivocarse pese a las instrucciones de alcance. No es autoridad para disponibilidad, precios, reservas, emergencias o datos personales. El fallo de API cae a una respuesta segura sin bloquear los comandos existentes.
- Esta versión no crea solicitudes nuevas, recibe imágenes, ejecuta la geocodificación, procesa pagos ni gestiona plantillas salientes de WhatsApp.
- El modelo de duración y borrado está documentado, pero el MVP aún no incluye el planificador de vencimientos ni los comandos ejecutables para iniciar/cerrar trabajos o revisar/borrar perfiles.
- La anonimización de teléfono y dirección del Cliente 90 días después del cierre está definida, pero depende de implementar un planificador de retención; no se ejecuta automáticamente todavía.
- Los IDs de mensajes se guardan permanentemente en `runtime/webhook-events/<año>.xml`. Cambios XML conservan hasta 90 copias diarias locales.
- Ejecuta una sola instancia. Los errores de negocio se registran sin texto, teléfono ni credenciales. Un fallo de envío puede requerir revisar el estado del mensaje antes de reintentar manualmente.
- Las copias permanecen en el mismo servidor en este MVP; un daño o pérdida del equipo también puede perderlas.
