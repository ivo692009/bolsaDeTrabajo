# ESPECIFICACIÓN DEL SISTEMA Y REGLAS DE NEGOCIO: PLATAFORMA DE INTERMEDIACIÓN DE SERVICIOS LOCALES

> **Fuente de verdad funcional:** este documento define el comportamiento del proyecto. `config/business/business-rules.yaml` y los archivos XML son sus representaciones estructuradas y deben mantenerse alineados con esta especificación.

## 1. PROPÓSITO DEL SISTEMA
El sistema actúa como un intermediario automatizado a través de WhatsApp para conectar a clientes potenciales que requieren servicios locales (ej. albañilería, sastrería, plomería, etc.) con profesionales calificados de la ciudad. Su objetivo principal es resolver la falta de visibilidad y contacto directo entre ambas partes mediante un flujo sencillo, rápido y automatizado.

---

## 2. ARQUITECTURA TÉCNICA Y LIMITACIONES
- **Canal de Comunicación Principal:** Exclusivamente la API oficial de Meta para WhatsApp (envío y recepción de mensajes).
- **Runtime inicial:** Servicio Windows PowerShell 5.1 en `src/whatsapp/whatsapp-bot.ps1`; recibe webhook local en `/webhook` y usa la Graph API configurada para responder.
- **Seguridad del webhook:** Verificar handshake GET y firma POST `X-Hub-Signature-256` con el App Secret sobre los bytes originales; rechazar firmas incorrectas y payloads mayores al límite configurado.
- **Configuración de secretos:** Leer `.env` local ignorado por Git sin evaluar contenido; las variables ya configuradas en el entorno del proceso tienen prioridad. Nunca registrar tokens ni incluirlos en archivos versionados.
- **Respuestas:** Las acciones de negocio se clasifican determinísticamente por texto, rubros/alias XML, identidad única del perfil y código de oferta. Los mensajes que no sean acciones reconocidas pueden pasar a una integración opcional con OpenAI Responses API para preguntas generales, limitada por `config/business/chatbot-context.md`; sin clave API el webhook ofrece una respuesta de fallback.
- **Límites del LLM:** El modelo solo genera respuestas informativas; no modifica XML ni ejecuta acciones, no consulta datos privados o disponibilidad en tiempo real y debe distinguir capacidades implementadas de flujos planeados. Las reglas de seguridad y privacidad de esta especificación prevalecen sobre el contexto editable.
- **Alcance conversacional:** Puede orientar de forma general sobre el tipo de profesional que suele corresponder a una tarea o sus características, sin diagnosticar ni asegurar calificaciones o disponibilidad. Debe ceñirse a la intermediación local y al funcionamiento del proyecto; no divulga ni infiere datos personales fuera de los flujos deterministas autorizados.
- **Lenguaje respetuoso:** El asistente no redacta insultos, humillaciones, amenazas, acoso ni ataques discriminatorios aunque lo solicite cualquier rol. El prompt lo prohíbe y el webhook comprueba las entradas y salidas del chatbot con Moderations API (`omni-moderation-latest`) y un filtro local de vocabulario explícito. El contenido marcado se rechaza o reemplaza por una respuesta segura; si la moderación falla, el chatbot no genera respuesta con LLM.
- **Memoria conversacional:** El historial local conserva hasta cuatro intercambios por remitente (identificador HMAC del número usando el secreto de Meta) durante un máximo de 30 días. Se envía solo el contexto reciente a OpenAI usando `store=false`; nunca se envían números remitentes ni datos del perfil. El operador puede borrar el archivo local para limpiar toda la memoria.
- **Preferencias de mensajería:** El estado de baja se guarda en `runtime/data/messaging-preferences.xml` usando HMAC-SHA256 de E.164 y una clave dedicada `WA_PREFERENCES_HMAC_KEY`; no se conserva el número en ese registro. La clave debe permanecer estable al rotar el secreto de Meta para no perder bajas vigentes.
- **Retención de datos de solicitudes:** Los datos identificatorios del Cliente y la dirección del servicio se anonimizan 90 días después del cierre de la solicitud. Se conservan los datos operativos no identificatorios necesarios para el historial. Direcciones precisas y respuestas geográficas crudas no se conservan.
- **Almacenamiento de Datos de Usuarios/Profesionales:** Archivos locales estructurados en formato XML (Texto Plano).
- **Organización de archivos:** `data/catalog/` contiene catálogos estáticos, `data/policies/` las políticas de zona, `data/templates/` las plantillas versionadas y `runtime/` los datos y respaldos locales excluidos de Git. Las imágenes y comprobantes se guardan bajo `storage/` en directorios separados.
- **Inicialización local:** En el primer arranque, el servicio crea los XML runtime de profesionales, solicitudes, allowlist administrativa y preferencias de mensajería desde plantillas vacías si faltan. Estos archivos pueden contener datos personales o identificadores seudónimos y no se versionan.
- **Escritura local:** Una sola instancia escribe los XML mediante una cola serializada, reemplazo atómico desde archivo temporal y copias de seguridad diarias, conservando 90 copias; no ejecutar escritores concurrentes.
- **Webhooks:** Los mensajes entrantes se deduplican permanentemente por el ID único de mensaje de Meta. Guardar el registro en archivos XML particionados por año y archivarlos sin borrarlos; las transiciones de estado son idempotentes.
- **Almacenamiento de Contenido Multimedia:** Galería de imágenes almacenada localmente en el servidor ejecutado, con referencias asociadas a la ID/registro de cada profesional en el XML.
- **Evidencia de pago:** Los comprobantes de comisión se almacenan localmente en un directorio privado separado de la galería pública y se referencian desde el XML de solicitudes.
- **Área inicial:** Rawson, Chubut, incluyendo Playa Unión. Las direcciones se validan internamente con Google Maps Geocoding API y un límite geográfico oficial configurado en `data/policies/location-policy.xml`; WhatsApp sigue siendo el único canal de conversación.
- **Acceso administrativo:** Las acciones administrativas por WhatsApp requieren coincidencia con la allowlist local `runtime/data/admin-whatsapp-numbers.xml` y el rol de la acción.
- **Catálogo de trabajos:** Rubros y tipos de trabajo permitidos se definen en `data/catalog/service-categories.xml`; cada profesional registra los trabajos que ofrece mediante referencias a ese catálogo y declara zonas cubiertas en su XML.
- **Disponibilidad profesional:** Para ser listado, el perfil debe declarar al menos un horario semanal válido y una o más zonas activas de `data/policies/location-policy.xml`.
- **Plantillas extensibles:** `data/templates/service-category.template.xml` define la estructura para agregar cualquier cantidad de rubros, descripciones, alias y tipos de trabajo sin modificar el esquema.
- **Simplicidad Operativa:** El software no utilizará bases de datos complejas ni interfaces gráficas sobrecargadas fuera de la gestión requerida por los archivos XML y archivos locales.

---

## 3. ROLES DEL SISTEMA
1. **Cliente Potencial:** Busca o contrata un servicio, selecciona profesionales, confirma el precio y el resultado. Cualquier número puede usar este flujo; tener un perfil profesional no lo impide.
2. **Profesional / Prestador de Servicios:** Se identifica exclusivamente por el número remitente verificado de WhatsApp vinculado a su perfil. Administra su propia información y capacidades, responde a solicitudes y paga su comisión.
3. **Bot / Asistente Virtual:** Determina la intención por mensaje, aplica el rol correspondiente a esa acción y registra los cambios. No inventa identidad ni verifica comprobantes.
4. **Administrador/a revisor/a:** Revisa comprobantes y solicitudes de cambio de número o retiro de información, con acceso restringido. Puede decidir si un comprobante es aceptable y marcar el pago como confirmado administrativamente, dejando método, evidencia, motivo, identidad y fecha; no existe verificación bancaria automática. Se autentica por allowlist de WhatsApp.
5. **Administrador/a del catálogo:** Agrega, modifica o desactiva rubros y tipos de trabajo globales usando la plantilla. No modifica perfiles individuales ni evidencia de pagos por esa función.
6. **Administrador/a de confiabilidad (`professional_reliability_admin`):** Revisa casos de trabajos acordados no completados, registra atribución y motivo, y aplica o levanta suspensiones. No puede declarar una finalización bilateral ni generar una comisión.

Una persona puede actuar como Cliente o Profesional según la intención de cada conversación. El rol no es una etiqueta global permanente: cada acción protegida vuelve a validar número remitente, perfil y permiso.

---

## 4. REGLAS DE NEGOCIO Y FLUJOS DE TRABAJO (WORKFLOWS)

### 4.1. Flujo de Atención al Cliente y Consulta de Servicios
1. **Inicio de Conversación:** El Cliente envía un mensaje inicial solicitando un servicio o especialidad.
2. **Filtro de profesionales:** El Bot exige coincidencia de rubro y tipo de trabajo. Solo incluye perfiles publicados (`status=active`), disponibles (`availabilityStatus=active`), que declaren ese trabajo, una zona de servicio configurada y al menos un horario válido. Si el Cliente indica día y hora, filtra además por ese intervalo local.
3. **Presentación de Catálogo:** El Bot muestra solo resultados que cumplan esos filtros, con horarios declarados y tamaño total de cuadrilla (profesional más trabajadores adicionales declarados), sin teléfonos.
4. **Filtro horario:** Si el Cliente indica día y hora, solo se listan intervalos que cubren esa hora según la zona horaria configurada. Sin día/hora, se muestran horarios declarados, no una reserva confirmada.
5. **Alternativas cercanas:** Si no hay coincidencias en la zona indicada, se listan profesionales activos y disponibles que realicen el mismo tipo de trabajo, ordenados por distancia aproximada entre puntos representativos configurados. No se relaja el requisito de tarea. Si faltan ubicación, zonas, polígono o puntos marcados `configured`, el Bot pide aclaración o indica que no puede ordenar cercanía.
6. **Referencias:** Si el Cliente solicita fotos, el Bot busca imágenes autorizadas locales del profesional seleccionado y las adjunta por WhatsApp.
### 4.2. Flujo de Solicitud y Asignación del Trabajo
1. **Selección:** El Cliente elige a un profesional del catálogo.
2. **Notificación al Profesional:** El Bot envía una notificación por WhatsApp con código corto único de solicitud, detalles básicos y botones o instrucciones de respuesta que incluyan ese código. La aceptación/rechazo solo aplica si el código corresponde a una oferta pendiente de ese mismo profesional.
3. **Aceptación o Rechazo:**
   - **Si el Profesional acepta:** El Bot conecta formalmente al Cliente con el Profesional, compartiendo los datos de contacto directo para coordinar la tarea.
   - **Si el Profesional rechaza/no responde:** El Bot notifica al Cliente y le sugiere otras opciones disponibles.
4. **Acuerdo de trabajo, precio y plazo:** Cliente y Profesional detallan los servicios, acuerdan la mano de obra y proponen una duración estimada como entero positivo de minutos. El Bot suma los importes y ambos deben confirmar el mismo subtotal y la misma duración. Materiales y trámites quedan fuera de la comisión. Cualquier cambio de tareas, monto o plazo reinicia las confirmaciones correspondientes.
5. **Inicio y vencimiento esperado:** El Profesional informa el inicio y el Cliente lo confirma. Al existir ambas confirmaciones se guarda `startedAt` y se calcula `expectedCompletionAt = startedAt + agreedDurationMinutes`; se conserva la zona horaria del proyecto.
6. **Confirmación al vencer el plazo:** Al llegar `expectedCompletionAt`, el Bot pregunta por WhatsApp a ambas partes si el trabajo terminó correctamente, sigue en curso o se canceló. No marca el trabajo como terminado automáticamente. Si sigue en curso, cualquier nuevo plazo requiere confirmación de ambos y queda en el historial.
7. **Registro de duración:** Guardar el primer reporte de finalización de cada parte y la hora en que ambas confirman. `completedAt` representa el primer reporte de término aceptado por ambas partes; `completionConfirmedAt` guarda la confirmación mutua. Calcular el tiempo transcurrido desde `startedAt` hasta `completedAt`, sin presentarlo como horas efectivas de mano de obra.
8. **Validación de zona:** Antes de enviar una oferta, validar la dirección de servicio dentro del área oficial configurada para Rawson o Playa Unión. Si no hay polígono oficial, la dirección es ambigua o el proveedor no responde, dejar la solicitud pendiente y no asignarla.

### 4.3. Flujo de Comisión y Comprobante
1. **Confirmación del resultado:** El Bot consulta por WhatsApp a Cliente y Profesional cada 24 horas para confirmar si el trabajo se completó o se canceló. Se permiten dos reintentos después de la consulta inicial. Solo `completed` confirmado por ambos habilita el cálculo.
2. **Cancelación o falta de respuesta:** Si ambas partes confirman `cancelled`, no se cobra comisión. Si no hay respuestas tras los dos reintentos, se cierra como `closed_unconfirmed` sin comisión y se conserva la trazabilidad; si una parte informa que el trabajo no se realizó, se solicita confirmación a la otra.
3. **Desacuerdos:** Si una parte informa `completed` y la otra `cancelled`, o el subtotal no coincide, se vuelve a consultar hasta dos veces. Si persiste el desacuerdo, cambia a `disputed` y se deriva al Administrador revisor. La revisión no reemplaza el consentimiento de las partes: no se solicita comisión mientras no exista confirmación bilateral explícita de finalización y subtotal.
4. **Base e importe:** Se cobra una sola comisión por solicitud completada: el 5% de la suma confirmada de mano de obra, pagada únicamente por el Profesional. Materiales, trámites e impuestos declarados aparte quedan excluidos.
5. **Moneda y redondeo:** Se usa ARS y se redondea hacia abajo al peso entero. Ejemplo: el 5% de ARS 12.345 es ARS 617,25 y la comisión es ARS 617. Si el subtotal no está confirmado, no calcular ni solicitar el pago.
6. **Comprobante y revisión administrativa:** Se solicita al Profesional una captura de transferencia por el importe exacto de la comisión esperada. Se almacena en `storage/evidence/commission-payments/<request-id>/`. Un Administrador revisa manualmente la captura y puede aceptarla o rechazarla, registrando decisión, método, motivo, fecha e identidad. La decisión es una confirmación administrativa, no una verificación bancaria automática.
7. **Un solo cargo:** Reenvíos, rechazos o recordatorios actualizan el comprobante de la misma comisión. Nunca crean una comisión ni un cobro adicional.

### 4.4. Flujo de Seguimiento y Reseña
1. **Verificación Pos-Servicio:** Al llegar `expectedCompletionAt`, el Bot pide al Cliente y al Profesional que informen por WhatsApp si el trabajo se completó, sigue en curso o se canceló. Si no responden, reintenta cada 24 horas, hasta dos veces. No hay un plazo de seguimiento independiente contado desde la aceptación.
2. **Recopilación de Reseñas:** Si ambas partes confirman que se completó, se solicita al Cliente una reseña. Si se canceló, no se solicita reseña ni comisión.

### 4.5. Flujo de Administración de Profesionales (Gestión por el Bot)
1. **Registro de Nuevos Profesionales:** El Bot permite el alta de nuevos prestadores de servicio solicitando únicamente los campos obligatorios:
   - Nombre
   - Apellido
   - Número de WhatsApp, obtenido del remitente del mensaje entrante y no de un número escrito manualmente
   - Redes sociales
2. **Rubros y trabajos:** Para publicar el perfil en el catálogo, el Profesional selecciona uno o más rubros y tipos de trabajo definidos en `data/catalog/service-categories.xml`. La lista no es cerrada ni tiene un máximo fijo. Cada rubro y trabajo puede tener descripción y múltiples alias o variaciones. Se usa `data/templates/service-category.template.xml` para agregar entradas compatibles.
3. **Cuadrilla:** El Profesional declara si tiene trabajadores adicionales a su cargo y cuántos. El conteo es entero, no negativo y excluye al Profesional; el total para un trabajo es `1 + additionalWorkers`. La bandera `hasAdditionalWorkers` debe ser verdadera exactamente cuando el conteo sea mayor que cero.
4. **Zonas y disponibilidad:** Para publicar, el Profesional declara una o más zonas cubiertas ya configuradas y horarios semanales válidos, incluyendo zona horaria. No se registra ni se muestra su domicilio particular para ordenar resultados.
5. **Persistencia:** La información se inserta o actualiza en los XML locales; rubros, tipos y zonas se guardan como referencias a catálogos comunes.
6. **Asociación de Galería:** Las imágenes enviadas o cargadas para un profesional se guardarán en el almacenamiento local vinculadas a su perfil en el XML.
7. **Control de perfiles previos:** Un teléfono verificado ya asociado a un perfil suspendido o desactivado no puede crear otro perfil ni reactivarlo por autogestión. Un número diferente no prueba por sí solo que sea otra persona ni que exista evasión; indicios concretos llevan el alta a revisión humana, con oportunidad de aclaración y sin revelar información del perfil previo. Los tombstones identificables solo pueden conservarse si una política de retención aplicable lo autoriza expresamente.
8. **Filtro de servicios prohibidos:** Antes de publicar un perfil y al cambiar tareas, rubros, alias o descripciones, aplicar `skills/professional-prohibited-services-review.md`. No publicar ofertas claramente dirigidas a actividades ilícitas o dañinas (incluida producción o tráfico ilícito de drogas, explotación sexual/trata, tráfico de armas, violencia o fraude). Las coincidencias ambiguas requieren aclaración y revisión; no se rechaza por palabras aisladas si el propósito es lícito. Se permiten las tareas lícitas separables del mismo perfil.

### 4.6. Autogestión del Perfil Profesional
1. El Bot normaliza el número remitente a E.164 y busca una coincidencia exacta y única con el número de WhatsApp del perfil XML.
2. Solo esa coincidencia autoriza consultar o modificar el perfil. El número debe ser único: no puede vincularse a más de un profesional ni un perfil puede tener varios números de autenticación.
3. El profesional puede agregar o modificar sus datos descriptivos, disponibilidad, rubros, trabajos ofrecidos y cantidad de trabajadores adicionales. Cada cambio se confirma antes de guardar y conserva fecha y valores anteriores en el historial local.
4. El profesional no puede borrar perfiles, rubros, trabajos ni historial. Puede pausar o reactivar su disponibilidad por WhatsApp con el mismo número verificado mientras el perfil tenga estado de ciclo de vida `active`. La pausa lo excluye de búsquedas y ofertas nuevas, pero no cancela trabajos ya aceptados; las ofertas pendientes conservan su vencimiento original. Esta acción no puede levantar estados `suspended`, `deactivated` o `permanently_deactivated`, que requieren la revisión definida en la sección 4.11.
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

### 4.10. Solicitud de borrado de datos del profesional
1. El Profesional solicita el borrado por WhatsApp desde el mismo número E.164 autenticado. El Bot crea un código y una solicitud `pending_admin_review` sin copiar el teléfono a la cola de revisión.
2. El perfil pasa a `deletion_requested` y `availabilityStatus=inactive` para ocultarlo de búsquedas y nuevas ofertas; no se cancelan ni se borran solicitudes existentes.
3. Solo un `commission_admin` autenticado mediante `runtime/data/admin-whatsapp-numbers.xml` puede aprobar o rechazar la solicitud. Una allowlist vacía o un rol ausente deniega la acción.
4. Antes de aprobar, se revisan trabajos abiertos, disputas, pagos y obligaciones de conservación. Mientras haya asuntos pendientes, no se anonimiza el perfil.
5. Al aprobar, se eliminan del perfil los identificadores personales, teléfono, redes, trabajos, zonas, horarios, cuadrilla y referencias de galería; se conserva solo un tombstone no identificable y la constancia mínima de la decisión administrativa.
6. Si se rechaza, se registra el motivo y se restaura el estado previo del perfil y disponibilidad. La resolución se comunica al profesional por WhatsApp.

El servicio inicial todavía no implementa el planificador del plazo ni los comandos de revisión/borrado; sus modelos y skills quedan definidos aquí para la siguiente implementación ejecutable.

---

### 4.11. Confiabilidad, incumplimientos y suspensiones profesionales
1. **Acuerdo elegible:** Un trabajo solo se considera acordado para esta política cuando Cliente y Profesional confirmaron el alcance, el subtotal de mano de obra y la duración. Aceptar una oferta no basta.
2. **Apertura del caso:** Una cancelación, un reporte unilateral, un desacuerdo o la falta de respuesta pueden abrir una revisión, pero no prueban por sí mismos responsabilidad ni generan una sanción.
3. **Atribución:** Solo una persona autenticada con rol `professional_reliability_admin` puede determinar si el incumplimiento es atribuible al Profesional. Debe registrar resultado (`attributable_to_professional`, `not_attributable_to_professional` o `inconclusive`), motivo, fecha e identidad administrativa. Cada solicitud puede generar como máximo un caso computable.
4. **Umbral:** Tres casos confirmados y atribuibles al Profesional, dentro de una ventana móvil de 60 días y todavía no asociados a una sanción, generan una suspensión de 60 días. Los casos utilizados se asocian a esa sanción para impedir que vuelvan a dispararla.
5. **Efecto:** El perfil pasa a `suspended`, queda fuera de búsquedas y no recibe nuevas ofertas. La suspensión no cancela trabajos ya aceptados. Se guarda un evento de sanción en el historial del profesional; el conteo acumulado de suspensiones no se reinicia al reactivar.
6. **Reactivación:** Antes de cumplir 60 días, solo una decisión administrativa explícita y registrada puede reactivar el perfil. Sin reactivación anticipada, el sistema lo reactiva automáticamente al cumplirse 60 días.
7. **Tercera suspensión:** Al alcanzar tres suspensiones acumuladas, el perfil pasa a `deactivated` y deja de recibir oportunidades. La desactivación sigue el mismo plazo: requiere decisión administrativa explícita para reactivarse antes de los 60 días y se reactiva automáticamente al cumplirse ese plazo si no se resolvió antes.
8. **Reincidencia posterior:** Tras reactivarse de la tercera suspensión, si se confirman otros tres casos atribuibles al Profesional dentro de una ventana móvil de 60 días, pasa a `permanently_deactivated`. No hay reactivación automática; solo una decisión administrativa explícita puede restablecerlo.
9. **Comisión independiente:** La revisión de confiabilidad no sustituye la confirmación del resultado del trabajo. Solo se cobra comisión si Cliente y Profesional confirman explícitamente que se completó y también confirmaron el subtotal; si no hay acuerdo bilateral explícito, no se cobra, aunque una revisión atribuya incumplimiento al Profesional.
10. **Persistencia y alcance actual:** El resultado del caso se registra en `request.nonCompletionCase` y el historial de sanciones en `professional.reliabilityHistory`. La plantilla y la política están especificadas; la revisión, los contadores y el planificador de vencimiento/reactivación todavía no están implementados en el webhook.

### 4.11.1. Cancelaciones reiteradas tras una derivación y señales anti fraude
1. **Etapas diferenciadas:** Registrar si el Profesional rechazó antes de aceptar, aceptó y canceló antes del acuerdo, o canceló después de confirmar bilateralmente alcance, subtotal y duración. Un rechazo previo a la aceptación es una opción legítima y no cuenta como cancelación reiterada.
2. **Registro mínimo:** Por solicitud, conservar estado y marcas de tiempo, quién canceló, etapa del acuerdo, motivo declarado o `not_provided`, solicitud de explicación y respuesta. No inventar motivos ni duplicar datos de contacto en notas de revisión.
3. **Umbral de alerta:** Tres cancelaciones sin motivo informado en solicitudes distintas dentro de una ventana móvil de 60 días crean una alerta de revisión humana. Excluir duplicados, cancelaciones iniciadas por el Cliente y rechazos anteriores a la aceptación. La alerta indica un patrón que requiere revisión, no prueba fraude ni responsabilidad.
4. **Revisión imparcial:** Un `professional_reliability_admin` solicita contexto al Profesional, contrasta los eventos disponibles y registra resultado, motivo, revisor y fecha. Debe considerar circunstancias justificadas y permitir que el Profesional responda antes de una medida adversa.
5. **Medida posible:** Tras confirmar administrativamente un patrón, el revisor puede imponer una pausa temporal de nuevas derivaciones, con causa, alcance y fecha de vencimiento registrados, y comunicar al Profesional cómo aportar información o pedir revisión. No afecta automáticamente solicitudes aceptadas ni determina cobros.
6. **Separación de sanciones:** Las cancelaciones previas al acuerdo no cuentan para los tres casos de incumplimiento acordado ni activan las suspensiones de la sección 4.11. Una cancelación posterior al acuerdo puede abrir el caso allí descrito, sujeto a atribución individual por revisión.
7. **Trato al Cliente:** Informar el estado de su propia solicitud y ofrecer alternativas; no revelar evaluaciones internas, acusaciones ni historial individual del Profesional.
8. **Alcance actual:** El registro, contador, alertas, revisión y pausa de derivaciones descritos aquí todavía no están implementados en el webhook. El asistente debe explicar las reglas y derivar a revisión, pero no afirmar que ejecutó una medida automática.

### 4.11.2. Revisión de altas y reportes de posible fraude
1. **Alta con número coincidente:** Un número remitente verificado ya asociado a un perfil restringido no puede crear un perfil duplicado ni levantar la restricción por autogestión; se deriva a una persona revisora.
2. **Alta con otro número:** Un número nuevo no demuestra identidad distinta ni evasión. Señales concretas y pertinentes pueden poner el alta en `pending_admin_review`; coincidencias aisladas de nombre, rubro, localidad o dispositivo no justifican un rechazo automático. El solicitante puede aclarar homónimos o cambios legítimos.
3. **Revisión de vínculo:** Solo un administrador autenticado con `professional_reliability_admin` puede decidir el alta o determinar que se intentó eludir una desactivación. Debe registrar hechos, señales consideradas, motivo, fecha e identidad de revisión, y dar una vía para solicitar revisión de la decisión. No revela datos del perfil previo.
4. **Reporte de posible estafa:** Registrar por separado alegación y hechos verificables. Cancelación, disputa, falta de respuesta o denuncia unilateral no prueban fraude. Un revisor registra `substantiated`, `not_substantiated` o `inconclusive`, los hechos considerados, motivo y fecha; no se comunica una acusación como hecho probado.
5. **Medidas y alcance:** Si existe riesgo operativo concreto, el revisor puede pausar temporalmente nuevas derivaciones con alcance y vencimiento registrados mientras revisa. No hay bloqueo, sanción ni desactivación automática por el chatbot. Los trabajos aceptados y el flujo de comisión conservan sus reglas independientes.
6. **Datos y estado:** Solicitar solo información necesaria; no pedir credenciales, datos bancarios completos ni documentos de identidad por WhatsApp como parte de esta revisión. Un tombstone identificable tras borrado solo se conserva cuando la política de retención aplicable lo autoriza expresamente.
7. **Alcance actual:** La detección de vínculos entre números, la cola de casos, la revisión y las pausas de derivación están especificadas pero no implementadas en el webhook. El bot puede explicar y derivar el caso, no afirmar que impidió una evasión o confirmó una estafa.

### 4.12. Consentimiento y ciclo de vida de datos del Cliente
1. **Baja inmediata:** El mensaje exacto `BAJA` registra la preferencia de no contacto y bloquea todos los mensajes salientes automatizados al remitente. No se envía acuse de recibo; el webhook guarda el evento como procesado y no ejecuta otro intent.
2. **Reconsentimiento:** Solo el mensaje exacto `ACEPTO MENSAJES` levanta la baja; se elimina el HMAC de la lista de supresión y se confirma la reactivación. Cualquier otro mensaje, incluidos `hola`, `ayuda` o comandos de trabajo, permanece bloqueado mientras la baja esté vigente.
3. **Persistencia mínima:** Mientras la baja esté vigente, `runtime/data/messaging-preferences.xml` conserva HMAC-SHA256 del número E.164, estado `opted_out` y fecha de cambio. El reconsentimiento elimina ese registro. `WA_PREFERENCES_HMAC_KEY` debe ser una clave aleatoria de 32 bytes (64 caracteres hexadecimales), obligatoria y estable incluso si rotan credenciales de Meta.
4. **Datos de solicitud:** Al cerrar una solicitud, guardar `closedAt` y `anonymizeAfter = closedAt + 90 días`. Al vencer el plazo, eliminar o anonimizar teléfono del Cliente y dirección cruda/normalizada. Conservar los estados y eventos no identificatorios requeridos para auditoría.
5. **Copias de seguridad:** El plazo de 90 días también aplica a los respaldos: las copias que contengan esos datos deben anonimizarse o eliminarse a más tardar en la misma fecha límite.
6. **Límites de retención:** No guardar coordenadas precisas ni respuestas crudas de geocodificación. Los IDs técnicos de webhooks pueden conservarse para deduplicación solo si no contienen el remitente ni el cuerpo del mensaje.
7. **Estado de implementación:** El bloqueo de mensajes y el registro HMAC se aplican en el webhook. La anonimización automática a los 90 días —incluyendo sus copias— requiere un planificador todavía no implementado; hasta entonces no se debe afirmar que los datos se purgan automáticamente.

### 4.13. Panel administrativo local de revisiones
1. El panel estático HTML/CSS/JavaScript se sirve mediante PowerShell en `127.0.0.1`; no requiere CDN ni conexión a servicios externos. La sesión usa un token temporal generado al iniciar el servidor y transmitido en el fragmento de la URL.
2. En cada decisión se valida el rol del revisor contra `runtime/data/admin-whatsapp-numbers.xml`. `commission_admin` revisa transferencias y borrados; `professional_reliability_admin` revisa disputas, incumplimientos, sospechas de fraude y suspensiones; `catalog_manager` atiende revisiones de servicios/categorías. La allowlist vacía deniega decisiones.
3. La bandeja indexa comprobantes pendientes, disputas, casos de no finalización y borrados pendientes que existan en los XML. Los demás casos sin flujo de captura se ingresan manualmente; las decisiones, motivos y actor se registran en `runtime/data/admin-review-cases.json`.
4. Aceptar un comprobante marca el pago como aceptado tras inspección visual (`paidByAdminReview=true`) y conserva `bankDepositVerified=false`. La revisión nunca reemplaza confirmación bilateral del trabajo ni comprueba depósitos bancarios automáticamente.
5. La atribución de incumplimientos se persiste en el caso de solicitud. Una suspensión solo se aplica desde el panel con tres solicitudes distintas atribuibles, revisadas dentro de 60 días y no asociadas previamente; se registra el historial y se actualizan los XML pertinentes. El planificador de vencimiento no se ejecuta desde el panel.
6. Rechazar un pedido de borrado restaura el estado anterior; aprobarlo requiere no tener trabajos/comisiones abiertos, anonimiza los campos del perfil y elimina esa fila de los respaldos `professionals.xml` disponibles. La operación queda en auditoría.
7. El listener está enlazado a loopback. No exponerlo a redes o proxies. El panel y el webhook no comparten un bloqueo transaccional para sus archivos XML: las revisiones deben ejecutarse con el webhook detenido hasta implementar sincronización de escrituras.
8. Las revisiones de vinculación de altas, cancelaciones repetidas, fraude y servicios prohibidos se pueden ingresar y resolver en la cola local. El webhook aún no crea automáticamente esos casos ni aplica decisiones genéricas de esa cola sobre el perfil; el panel conserva su resultado y auditoría.
9. La pestaña de métricas cuenta cada evento `professional_referred`, conexión, acuerdo bilateral, finalización bilateral y cierre por fecha explícita en `request.analytics` o `request.timeline`. El motivo de no concreción es un código enumerado; nunca se expone texto libre de clientes en los gráficos. Los hitos históricos sin fecha no se reconstruyen ni se imputan.
10. La pestaña del servicio distingue configuración completa de listener activo con `GET /health`, disponible solo en el listener local del webhook. `WA_DISPLAY_PHONE_NUMBER` informa el número empresarial visible; `WA_TEST_PHONE_NUMBER` se usa como alternativa de prueba. No se publica el token ni el Phone Number ID.

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
