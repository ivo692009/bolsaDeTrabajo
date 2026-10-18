# Skill 22: Consulta compacta del diccionario de actividades profesionales

## Objetivo
Orientar al usuario sobre qué oficio suele realizar una actividad y ayudar a expresar su solicitud con el menor contexto necesario, consultando definiciones locales y vigentes.

## Fuente
- Leer `data/dictionaries/professional-activities.yaml` y, para rubros y tipos disponibles en la plataforma, `data/catalog/service-categories.xml`.
- El XML es la fuente de verdad de categorías y trabajos que pueden seleccionarse. El diccionario amplía su significado general y no habilita categorías nuevas por sí mismo.

## Procedimiento de consulta
1. Identificar el oficio/tarea probable por nombre, alias o descripción. Recuperar solo la entrada de oficio relevante y los campos necesarios (resumen, actividades, aclaración y límites); no cargar ni enviar el diccionario completo al modelo.
2. Si una misma tarea corresponde a más de un oficio (por ejemplo, obra que combina albañilería, plomería, electricidad o gas), mencionar las opciones con una frase breve y preguntar el dato mínimo que las distingue.
3. Usar las actividades como ejemplos orientativos, no como lista exhaustiva ni afirmación sobre lo que una persona concreta puede hacer. Para filtrar profesionales, exigir el tipo de trabajo exacto declarado en el perfil y el catálogo.
4. Consultar límites antes de responder. En gas, electricidad peligrosa, urgencias u otros riesgos, detener la orientación técnica y seguir el contexto de seguridad aprobado.
5. Si no hay definición o es insuficiente, reconocerlo, pedir una aclaración concreta y derivar propuesta de mejora a la skill de mantenimiento. No inventar alcance, credenciales ni disponibilidad.

## Restricciones
- No enviar perfiles, datos privados, historial de conversaciones ni XML runtime a un proveedor externo para enriquecer una definición.
- No afirmar que una persona está matriculada, habilitada, calificada, disponible o certificada a partir del diccionario.
- No usar el diccionario para justificar tareas prohibidas; aplicar `professional-prohibited-services-review.md` al alta y cambios de perfiles.
- Reducir tokens consultando únicamente entradas y campos pertinentes, y sintetizando la respuesta sin perder límites relevantes.

## Resultado esperado
Orientación breve y específica sobre el oficio probable y preguntas útiles para describir el trabajo, con incertidumbre y límites claros.
