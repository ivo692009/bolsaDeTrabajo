# ESPECIFICACIÓN DEL SISTEMA Y REGLAS DE NEGOCIO: PLATAFORMA DE INTERMEDIACIÓN DE SERVICIOS LOCALES

> **Fuente de verdad funcional:** este documento define el comportamiento del proyecto. `business-rules.yaml` y los archivos XML son sus representaciones estructuradas y deben mantenerse alineados con esta especificación.

## 1. PROPÓSITO DEL SISTEMA
El sistema actúa como un intermediario automatizado a través de WhatsApp para conectar a clientes potenciales que requieren servicios locales (ej. albañilería, sastrería, plomería, etc.) con profesionales calificados de la ciudad. Su objetivo principal es resolver la falta de visibilidad y contacto directo entre ambas partes mediante un flujo sencillo, rápido y automatizado.

---

## 2. ARQUITECTURA TÉCNICA Y LIMITACIONES
- **Canal de Comunicación Principal:** Exclusivamente la API oficial de Meta para WhatsApp (envío y recepción de mensajes).
- **Runtime inicial:** Servicio Windows PowerShell 5.1 en `scripts/whatsapp-bot.ps1`; recibe webhook local en `/webhook` y usa la Graph API configurada para responder.
- **Seguridad del webhook:** Verificar handshake GET y firma POST `X-Hub-Signature-256` con el App Secret sobre los bytes originales; rechazar firmas incorrectas y payloads mayores al límite configurado.
- **Respuestas iniciales:** Clasificación determinista por texto, rubros/alias XML, identidad única del perfil y código de oferta; no hay un proveedor LLM conectado en esta versión.
- **Almacenamiento de Datos de Usuarios/Profesionales:** Archivos locales estructurados en formato XML (Texto Plano).
- **Inicialización local:** En el primer arranque, el servicio crea los XML runtime de profesionales, solicitudes y allowlist administrativa desde plantillas vacías si faltan. Estos archivos pueden contener datos personales y no se versionan.
- **Escritura local:** Una sola instancia escribe los XML mediante una cola serializada, reemplazo atómico desde archivo temporal y copias de seguridad diarias, conservando 90 copias; no ejecutar escritores concurrentes.
- **Webhooks:** Los mensajes entrantes se deduplican permanentemente por el ID único de mensaje de Meta. Guardar el registro en archivos XML particionados por año y archivarlos sin borrarlos; las transiciones de estado son idempotentes.
- **Almacenamiento de Contenido Multimedia:** Galería de imágenes almacenada localmente en el servidor ejecutado, con referencias asociadas a la ID/registro de cada profesional en el XML.
- **Evidencia de pago:** Los comprobantes de comisión se almacenan localmente en un directorio privado separado de la galería pública y se referencian desde el XML de solicitudes.
- **Área inicial:** Rawson, Chubut, incluyendo Playa Unión. Las direcciones se validan internamente con Google Maps Geocoding API y un límite geográfico oficial configurado en `data/location-policy.xml`; WhatsApp sigue siendo el único canal de conversación.
- **Acceso administrativo:** Las acciones administrativas por WhatsApp requieren coincidencia con la allowlist local `data/admin-whatsapp-numbers.xml` y el rol de la acción.
- **Catálogo de trabajos:** Rubros y tipos de trabajo permitidos se definen en `data/service-categories.xml`; cada profesional registra los trabajos que ofrece mediante referencias a ese catálogo y declara zonas cubiertas en su XML.
- **Disponibilidad profesional:** Para ser listado, el perfil debe declarar al menos un horario semanal válido y una o más zonas activas de `data/location-policy.xml`.
- **Plantillas extensibles:** `data/templates/service-category.template.xml` define la estructura para agregar cualquier cantidad de rubros, descripciones, alias y tipos de trabajo sin modificar el esquema.
- **Simplicidad Operativa:** El software no utilizará bases de datos complejas ni interfaces gráficas sobrecargadas fuera de la gestión requerida por los archivos XML y archivos locales.

---

## 3. ROLES DEL SISTEMA
1. **Cliente Potencial:** Busca o contrata un servicio, selecciona profesionales, confirma el precio y el resultado. Cualquier número puede usar este flujo; tener un perfil profesional no lo impide.
2. **Profesional / Prestador de Servicios:** Se identifica exclusivamente por el número remitente verificado de WhatsApp vinculado a su perfil. Administra su propia información y capacidades, responde a solicitudes y paga su comisión.
3. **Bot / Asistente Virtual:** Determina la intención por mensaje, aplica el rol correspondiente a esa acción y registra los cambios. No inventa identidad ni verifica comprobantes.
4. **Administrador/a revisor/a:** Revisa comprobantes y solicitudes de cambio de número o retiro de información, con acceso restringido. Puede decidir si un comprobante es aceptable y marcar el pago como confirmado administrativamente, dejando método, evidencia, motivo, identidad y fecha; no existe verificación bancaria automática. Se autentica por allowlist de WhatsApp.
5. **Administrador/a del catálogo:** Agrega, modifica o desactiva rubros y tipos de trabajo globales usando la plantilla. No modifica perfiles individuales ni evidencia de pagos por esa función.

Una persona puede actuar como Cliente o Profesional según la intención de cada conversación. El rol no es una etiqueta global permanente: cada acción protegida vuelve a validar número remitente, perfil y permiso.

---

## 4. REGLAS DE NEGOCIO Y FLUJOS DE TRABAJO (WORKFLOWS)

### 4.1. Flujo de Atención al Cliente y Consulta de Servicios
1. **Inicio de Conversación:** El Cliente envía un mensaje inicial solicitando un servicio o especialidad.
2. **Filtro de profesionales:** El Bot exige coincidencia de rubro y tipo de trabajo. Solo incluye perfiles publicados (`status=active`), disponibles (`availabilityStatus=active`), que declaren ese trabajo, una zona de servicio configurada y al menos un horario válido. Si el Cliente indica día y hora, filtra además por ese intervalo local.
3. **Presentación de Catálogo:** El Bot muestra solo resultados que cumplan esos filtros, con horarios declarados y sin teléfonos. Si el cliente indica Rawson o Playa Unión y no hay coincidencias en esa zona, ofrece profesionales activos y disponibles que declaren el mismo tipo de trabajo, ordenados por cercanía aproximada entre puntos representativos oficiales de las zonas; no relaja el requisito de tarea.
4. **Límites de proximidad:** La distancia se calcula en línea recta entre puntos representativos configurados, no es tiempo de viaje ni garantiza cobertura. Si falta ubicación del Cliente, zonas declaradas, polígono o punto de referencia marcado como `configured`, el Bot pide aclaración o informa que no puede ordenar por cercanía; no inventa distancias.
5. **Consulta de Disponibilidad:** Si el Cliente especifica día y hora, solo se muestran horarios que cubren ese intervalo según la zona horaria del proyecto. Sin día/hora, se presentan horarios declarados, no una reserva confirmada.
6. **Muestra de Referencias (Fotos):** Si el Cliente solicita referencias o pruebas de trabajos anteriores, el Bot buscará localmente las fotos asociadas al profesional seleccionado y las adjuntará en la conversación de WhatsApp.

### 4.2. Flujo de Solicitud y Asignación del Trabajo
1. **Selección:** El Cliente elige a un profesional del catálogo.
2. **Notificación al Profesional:** El Bot envía una notificación por WhatsApp con código corto único de solicitud, detalles básicos y botones o instrucciones de respuesta que incluyan ese código. La aceptación/rechazo solo aplica si el código corresponde a una oferta pendiente de ese mismo profesional.
3. **Aceptación o Rechazo:**
   - **Si el Profesional acepta:** El Bot conecta formalmente al Cliente con el Profesional, compartiendo los datos de contacto directo para coordinar la tarea.
   - **Si el Profesional rechaza/no responde:** El Bot notifica al Cliente y le sugiere otras opciones disponibles.
4. **Acuerdo de trabajo y precio:** Cliente y Profesional detallan los servicios incluidos y acuerdan por separado el importe de mano de obra de cada uno. El Bot suma las líneas y solicita a ambas partes confirmar el mismo subtotal de mano de obra en pesos argentinos enteros. Materiales, trámites y otros cargos no entran en la base de comisión. Todo servicio agregado o cambio de precio requiere actualizar el desglose y obtener ambas confirmaciones antes de usar el nuevo subtotal.
5. **Validación de zona:** Antes de enviar una oferta, validar la dirección de servicio dentro del área oficial configurada para Rawson o Playa Unión. Si no hay polígono oficial, la dirección es ambigua o el proveedor no responde, dejar la solicitud pendiente y no asignarla.

### 4.3. Flujo de Comisión y Comprobante
1. **Confirmación del resultado:** El Bot consulta por WhatsApp a Cliente y Profesional cada 24 horas para confirmar si el trabajo se completó o se canceló. Se permiten dos reintentos después de la consulta inicial. Solo `completed` confirmado por ambos habilita el cálculo.
2. **Cancelación o falta de respuesta:** Si ambas partes confirman `cancelled`, no se cobra comisión. Si no hay respuestas tras los dos reintentos, se cierra como `closed_unconfirmed` sin comisión y se conserva la trazabilidad; si una parte informa que el trabajo no se realizó, se solicita confirmación a la otra.
3. **Desacuerdos:** Si una parte informa `completed` y la otra `cancelled`, o el subtotal no coincide, se vuelve a consultar hasta dos veces. Si persiste el desacuerdo, cambia a `disputed` y se deriva al Administrador revisor; no se solicita comisión hasta que se resuelva.
4. **Base e importe:** Se cobra una sola comisión por solicitud completada: el 5% de la suma confirmada de mano de obra, pagada únicamente por el Profesional. Materiales, trámites e impuestos declarados aparte quedan excluidos.
5. **Moneda y redondeo:** Se usa ARS y se redondea hacia abajo al peso entero. Ejemplo: el 5% de ARS 12.345 es ARS 617,25 y la comisión es ARS 617. Si el subtotal no está confirmado, no calcular ni solicitar el pago.
6. **Comprobante y revisión administrativa:** Se solicita al Profesional una captura de transferencia por el importe exacto de la comisión esperada. Se almacena en `evidence/commission-payments/<request-id>/`. Un Administrador revisa manualmente la captura y puede aceptarla o rechazarla, registrando decisión, método, motivo, fecha e identidad. La decisión es una confirmación administrativa, no una verificación bancaria automática.
7. **Un solo cargo:** Reenvíos, rechazos o recordatorios actualizan el comprobante de la misma comisión. Nunca crean una comisión ni un cobro adicional.

### 4.4. Flujo de Seguimiento y Reseña
1. **Verificación Pos-Servicio:** Después del plazo configurado desde la aceptación, el Bot pide al Cliente y al Profesional que informen por WhatsApp si el trabajo se completó o se canceló. Si no responden, reintenta cada 24 horas, hasta dos veces.
2. **Recopilación de Reseñas:** Si ambas partes confirman que se completó, se solicita al Cliente una reseña. Si se canceló, no se solicita reseña ni comisión.

### 4.5. Flujo de Administración de Profesionales (Gestión por el Bot)
1. **Registro de Nuevos Profesionales:** El Bot permite el alta de nuevos prestadores de servicio solicitando únicamente los campos obligatorios:
   - Nombre
   - Apellido
   - Número de WhatsApp, obtenido del remitente del mensaje entrante y no de un número escrito manualmente
   - Redes sociales
2. **Rubros y trabajos:** Para publicar el perfil en el catálogo, el Profesional selecciona uno o más rubros y tipos de trabajo definidos en `data/service-categories.xml`. La lista no es cerrada ni tiene un máximo fijo. Cada rubro y trabajo puede tener descripción y múltiples alias o variaciones. Se usa `data/templates/service-category.template.xml` para agregar entradas compatibles.
3. **Zonas y disponibilidad:** Para publicar, el Profesional declara una o más zonas cubiertas ya configuradas y horarios semanales válidos, incluyendo zona horaria. No se registra ni se muestra su domicilio particular para ordenar resultados.
4. **Persistencia:** La información se inserta o actualiza en los XML locales; rubros, tipos y zonas se guardan como referencias a catálogos comunes.
5. **Asociación de Galería:** Las imágenes enviadas o cargadas para un profesional se guardarán en el almacenamiento local vinculadas a su perfil en el XML.

### 4.6. Autogestión del Perfil Profesional
1. El Bot normaliza el número remitente a E.164 y busca una coincidencia exacta y única con el número de WhatsApp del perfil XML.
2. Solo esa coincidencia autoriza consultar o modificar el perfil. El número debe ser único: no puede vincularse a más de un profesional ni un perfil puede tener varios números de autenticación.
3. El profesional puede agregar o modificar sus datos descriptivos, disponibilidad, rubros y trabajos ofrecidos dentro del catálogo existente. Cada cambio se confirma antes de guardar y conserva fecha y valores anteriores en el historial local.
4. El profesional no puede borrar perfiles, rubros, trabajos ni historial. Puede desactivar o reactivar su propio perfil por WhatsApp con el mismo número verificado. La desactivación lo excluye de búsquedas y ofertas nuevas, pero no cancela trabajos ya aceptados; las ofertas pendientes conservan su vencimiento original. La reactivación restaura su perfil conservado.
5. El número vinculado no se cambia mediante autogestión. El cambio requiere revisión autorizada y verificación del nuevo número por WhatsApp antes de reasignar el perfil.

### 4.7. Resolución de Rol por Intención
1. El Bot clasifica la intención del mensaje actual antes de seleccionar el flujo.
2. Si el número coincide con un profesional y este solicita un servicio, el Bot lo trata como Cliente para esa solicitud, sin modificar su perfil profesional.
3. La gestión del perfil, aceptación de trabajos, confirmación de precios y envío de comprobantes requieren coincidencia exacta del número de WhatsApp registrado.
4. Si la intención es ambigua o hay más de un perfil con el mismo número, el Bot pregunta o deriva a revisión; no ejecuta acciones protegidas.

### 4.8. Robustez Operativa
1. Antes de aplicar un webhook, el Bot comprueba si su ID de mensaje de Meta ya fue procesado. Un reintento no puede duplicar solicitudes, cambios de perfil, recordatorios ni comisiones. Conservar estos IDs permanentemente, particionados por año y sin purga.
2. Todas las escrituras XML pasan por una cola única: se escribe un archivo temporal, se valida, se reemplaza atómicamente el original y se conserva una copia diaria hasta 90 días.
3. Si el archivo está bloqueado, mal formado o falla el reemplazo, no se confirma la acción al usuario; se conserva el original y se registra el error para reintento o revisión.
4. Cada oferta tiene un código único, estado y destinatario. Un “acepto” sin código válido no cambia ninguna solicitud; solicitudes con múltiples ofertas requieren la respuesta asociada al código correspondiente.
5. Archivos recibidos por WhatsApp se validan por tamaño y tipo real, se renombran con IDs internos y se guardan en rutas separadas según sean galería o comprobantes.
6. En el MVP, las credenciales profesionales no se verifican. El Bot no debe afirmar que una matrícula, licencia o calificación fue comprobada.
7. Ante una urgencia o riesgo inmediato (por ejemplo, fuga de gas o peligro eléctrico), el Bot no diagnostica ni coordina una oferta ordinaria; indica contactar los servicios de emergencia locales. No inventa números telefónicos.
8. Las copias son locales en el MVP, con riesgo residual ante pérdida o daño del servidor. Mantener procedimiento de restauración y documentar que una copia externa cifrada queda como mejora recomendada.

### 4.9. Infraestructura WhatsApp inicial
1. Meta envía eventos a `https://<dominio-publico>/webhook`; un proxy HTTPS los reenvía a `http://127.0.0.1:<puerto>/webhook`. El listener no se expone directamente a Internet.
2. El handshake del webhook usa un token de verificación configurado; cada POST debe validar HMAC-SHA256 antes de leer o actuar sobre el evento.
3. El servicio responde solo a mensajes compatibles con sus intents implementados. Eventos de estado no crean conversaciones ni disparan acciones.
4. La primera versión puede mostrar categorías/perfiles activos, consultar perfil, pausar/reactivar y responder a ofertas existentes con código válido. No crea solicitudes nuevas ni valida ubicaciones hasta cargar el polígono oficial.
5. Los secretos se inyectan como variables de entorno del proceso y nunca se guardan en el repositorio o archivos de datos.

---

## 5. RESTRICCIONES Y BOUNDARIES PARA EL LLM
- **No inventar datos:** El Bot solo debe responder con los profesionales, horarios y fotos explícitamente registrados en los archivos XML y directorios locales.
- **Filtrado por trabajo, no por género:** La búsqueda usa rubros y tipos de trabajo registrados para cada Profesional. No infiere capacidades a partir del género de una persona.
- **Privacidad financiera:** Los comprobantes solo son visibles para el Profesional que los envía y las personas revisoras autorizadas; nunca se envían a otros clientes o profesionales.
- **Identidad profesional:** Solo el número remitente de WhatsApp verificado autentica al Profesional. El ID XML sirve para referencias internas, no para iniciar sesión ni autorizar cambios.
- **No borrado arbitrario:** El profesional puede agregar y modificar su propia información, pero retirar o borrar requiere revisión autorizada y conservación de historial.
- **Estado del comprobante:** Una revisión visual no se debe describir como depósito confirmado ni como pago acreditado.
- **Direcciones:** Google Maps se usa solo para geocodificación interna. No se envían enlaces al mapa; sin un límite oficial configurado, no se confirma que la dirección pertenece al área.
- **Credenciales:** No presentar a los profesionales como verificados o certificados mientras no exista un flujo de validación de credenciales.
- **Mantener la simplicidad:** WhatsApp es el único canal ofrecido al usuario. La única integración externa adicional del MVP es Google Maps Geocoding API para validar direcciones internamente; no se envían páginas ni enlaces de mapas.
- **Respetar el flujo de privacidad:** No compartir información de contacto directo entre Cliente y Profesional hasta que el Profesional haya aceptado explícitamente la solicitud de trabajo.
