# Skill: Chatbot conversacional de servicios

## Objetivo
Responder en lenguaje natural preguntas informativas sobre servicios locales, orientar qué tipo de profesional suele corresponder a una tarea, explicar el funcionamiento de la plataforma y sus reglas aprobadas, respetando los límites configurables del negocio.

## Flujo
1. Procesar primero las intenciones de emergencia y los comandos deterministas reconocidos por el webhook.
2. Para preguntas abiertas o consultas que no correspondan a una tarea del catálogo, llamar al proveedor LLM solo si `OPENAI_API_KEY` está configurada.
3. Incluir `config/business/chatbot-context.md` como contexto editable y la conversación reciente del remitente para continuidad.
4. Para orientar sobre una tarea/oficio, aplicar `professional-activity-dictionary-lookup.md` y recuperar solo la entrada y los campos pertinentes de `data/dictionaries/professional-activities.yaml`; no adjuntar el diccionario completo al prompt.
5. Si falta contexto, el proveedor no está disponible o la respuesta no trae texto, responder con un fallback breve y seguro.

## Restricciones
- El LLM genera texto informativo y no puede cambiar perfiles, crear solicitudes, aceptar ofertas, validar direcciones ni efectuar pagos.
- No enviar el teléfono del remitente, XML privados, datos de otros usuarios, credenciales ni contenido multimedia al proveedor.
- No usar al modelo como fuente de verdad para profesionales, disponibilidad, precios o reservas; esas respuestas requieren los flujos deterministas y los datos locales.
- Aplicar las restricciones de seguridad de `docs/business/system-specification.md`; el contexto editable puede agregar límites, pero no eliminarlos.
- Mantener cada respuesta dentro del propósito del proyecto. Rechazar pedidos para redactar insultos, humillaciones, amenazas, acoso o ataques discriminatorios; ofrecer una alternativa firme y respetuosa cuando sea útil. Moderations API y un filtro local revisan las entradas y salidas del chatbot. Si Moderations API falla, no generar texto con el LLM.
- No divulgar, deducir ni buscar datos personales de clientes, profesionales o administradores. El catálogo público solo se consulta mediante la búsqueda determinista.
- Al orientar sobre un oficio, hablar de categorías generales, preguntar si faltan detalles y no inferir disponibilidad ni calificación de profesionales concretos.
- El diccionario de actividades es una fuente local compacta para alcance general; no sustituye el catálogo, no prueba credenciales y debe consultarse selectivamente para reducir tokens.
- No diagnosticar urgencias, gas o electricidad peligrosa ni inventar números de emergencia. No dar asesoramiento médico, legal o financiero.
- Procesar únicamente consultas dentro del alcance del negocio y reconocer cuando la información no está disponible.
- Conservar como máximo cuatro intercambios recientes por remitente durante 30 días en el archivo runtime local excluido de Git. Informar que el texto se procesa con el proveedor externo si se habilita esta integración.

## Entrada
Texto entrante, identificador local HMAC del remitente, hasta cuatro intercambios previos y contexto aprobado del negocio.

## Resultado
Respuesta conversacional en español, con incertidumbre explícita cuando corresponda, o fallback seguro cuando la API no esté disponible.
