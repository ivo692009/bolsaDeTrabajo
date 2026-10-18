# Skill 03: Catálogo de profesionales (XML)

## Objetivo
Administrar el catálogo local de profesionales en XML, manteniendo datos estructurados y referencias estables.

## Acciones
- Consultar profesionales por identificador, categoría o estado.
- Guiar por WhatsApp el alta solicitando nombre, apellido y redes sociales; obtener el número único del evento entrante, normalizarlo a E.164 y evitar duplicados.
- Autenticar consultas y cambios de perfil exclusivamente mediante coincidencia exacta y única con el número remitente de WhatsApp.
- Insertar el alta o actualizar el registro XML asociado al número remitente ya verificado.
- Asignar cualquier cantidad de rubros y tipos de trabajo existentes en `data/catalog/service-categories.xml` antes de publicar el perfil.
- Usar `data/dictionaries/professional-activities.yaml` solo para aclarar qué tareas suelen corresponder a cada oficio; el catálogo XML sigue determinando qué opciones pueden asignarse.
- Durante altas o cambios de tareas declaradas, aplicar `professional-registration-activity-enrichment.md` para comparar con el diccionario y proponer mejoras documentadas cuando falte especificidad.
- Declarar una o más zonas activas desde `data/policies/location-policy.xml` y horarios semanales válidos con zona horaria antes de aparecer en búsquedas.
- Mantener un catálogo extensible sin enumeraciones cerradas: agregar rubros siguiendo `data/templates/service-category.template.xml`, con ID estable, descripciones y tantos alias y tipos de trabajo como sean necesarios.
- Mantener rubros/trabajos, zonas de cobertura, horarios y referencias de galería en el perfil; son requisitos para publicar, aunque no campos obligatorios del alta inicial.
- Usar `data/templates/professional-profile.template.xml` como referencia de formato; los perfiles operativos se guardan en `runtime/data/professionals.xml` y no se versionan.

## Entradas
- Mensajes del profesional recibidos por WhatsApp y operación solicitada (alta, consulta o actualización).
- XML local de profesionales.

## Restricciones
- No sobrescribir registros si el número remitente no coincide exactamente o existe ambigüedad; pedir revisión.
- El ID interno del XML sirve para referencias de datos, no autentica al profesional.
- No permitir que el profesional cambie directamente el número vinculado ni elimine sus datos o historial; los cambios de número y retiros requieren revisión autorizada.
- Registrar en el historial el campo cambiado, los valores anterior y nuevo, la fecha y el número remitente autenticado.
- No publicar perfiles con rubros o tipos de trabajo que no existan en el catálogo XML.
- Solo declarar zonas que el profesional realmente atiende; no registrar su domicilio particular como zona pública de búsqueda.
- Los cambios estructurales al catálogo los realiza el rol `catalog_manager` usando la plantilla; el Profesional elige entre opciones existentes y no crea categorías mediante texto libre durante una solicitud.
- No inferir rubros ni capacidades por el género del profesional; registrar solo los trabajos que la persona declara ofrecer.
- Recopilar y almacenar solo los datos necesarios, con acceso limitado y consentimiento adecuado.
- No publicar teléfonos o redes sociales sin autorización explícita del profesional.
- Mantener copias de seguridad y evitar ediciones simultáneas que puedan perder cambios.
- El archivo XML de ejemplo no contiene datos personales reales.

## Resultado esperado
Registro XML local válido, o una pregunta concreta por los datos obligatorios que faltan. El bot confirma el alta solo después de persistirla.

## Estado de implementación
La consulta y algunas modificaciones autenticadas de perfiles están disponibles; el alta conversacional y la administración completa del catálogo siguen pendientes. No afirmar que un alta o cambio se guardó sin verificar el XML persistido.
