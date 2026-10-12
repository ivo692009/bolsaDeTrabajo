# Servicio inicial de WhatsApp

El servicio usa PowerShell 5.1 y componentes .NET incluidos en Windows; no requiere paquetes npm. Implementa el webhook de Meta, verificación HMAC-SHA256, deduplicación por ID de mensaje, escritura XML atómica con copias diarias y respuestas deterministas en español.

## Prueba local

Desde la raíz del proyecto, en PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\whatsapp-bot.ps1 -SelfTest
```

El cambio de política aplica solo a esa sesión. El modo de autoprueba no lee secretos ni llama a Meta.

## Configuración

En el primer arranque, si faltan, el servicio inicializa `data/professionals.xml`, `data/requests.xml` y `data/admin-whatsapp-numbers.xml` desde plantillas vacías de `data/templates/`. Esos XML pueden contener datos personales y `.gitignore` los excluye del repositorio.

Crea una aplicación en Meta for Developers, agrega el producto WhatsApp y registra un número empresarial en WhatsApp Cloud API. No compartas el número personal: Meta debe indicar el `Phone Number ID` correspondiente al número empresarial.

Configura estas variables en el entorno protegido del proceso que ejecutará el bot:

- `WA_APP_SECRET`: App Secret de la aplicación Meta; se usa para verificar la firma del webhook.
- `WA_VERIFY_TOKEN`: valor aleatorio elegido por el administrador para el handshake del webhook. Debe coincidir en Meta y en el proceso.
- `WA_ACCESS_TOKEN`: token de acceso con permisos de WhatsApp Cloud API para enviar mensajes.
- `WA_PHONE_NUMBER_ID`: Phone Number ID que entrega Meta para el número registrado.
- `WA_GRAPH_API_VERSION`: versión Graph actualmente soportada por la aplicación, con formato `vNN.0`.

`whatsapp-bot.env.example` enumera los nombres sin contener credenciales reales. No guardes tokens o secretos en XML, archivos versionados, mensajes ni logs; tampoco los pegues en conversaciones.

## Conectar el webhook

1. Expón el servicio local mediante un reverse proxy o túnel HTTPS administrado por ti. Meta no puede conectarse a `localhost`.
2. Configura el proxy para reenviar `https://TU-DOMINIO/webhook` al listener local `http://127.0.0.1:8080/webhook`.
3. Ejecuta el servicio:

```powershell
.\scripts\whatsapp-bot.ps1 -Port 8080
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
- `acepto A7K2` o `rechazo A7K2`: responde a una oferta pendiente solo si código, perfil y remitente coinciden y la ubicación ya está validada.
- Mensajes que describen urgencias reciben una respuesta segura; el bot no coordina emergencias ni inventa teléfonos locales.

La ubicación está configurada para Rawson y Playa Unión, pero falta cargar los polígonos oficiales y puntos representativos en `data/location-policy.xml`. Sin esos puntos el bot no puede afirmar cuál alternativa es más cercana; los perfiles deben declarar zonas en `serviceAreas` y horarios válidos. La distancia es aproximada entre centroides de zonas, no una ruta. Por seguridad, no valida direcciones ni crea ofertas mientras el polígono siga pendiente. El perfil de muestra está en borrador/inactivo y no aparecerá en listados.

## Límites y operación

- El análisis es determinista por reglas y catálogo XML; no hay un proveedor LLM conectado ni se inventan resultados.
- Esta versión no crea solicitudes nuevas, recibe imágenes, ejecuta la geocodificación, procesa pagos ni gestiona plantillas salientes de WhatsApp.
- Los IDs de mensajes se guardan permanentemente en `data/webhook-events/<año>.xml`. Cambios XML conservan hasta 90 copias diarias locales.
- Ejecuta una sola instancia. Los errores de negocio se registran sin texto, teléfono ni credenciales. Un fallo de envío puede requerir revisar el estado del mensaje antes de reintentar manualmente.
- Las copias permanecen en el mismo servidor en este MVP; un daño o pérdida del equipo también puede perderlas.
