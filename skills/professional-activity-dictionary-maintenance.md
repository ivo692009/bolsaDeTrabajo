# Skill 23: Mantenimiento incremental del diccionario de actividades

## Objetivo
Ampliar de forma progresiva y específica `data/dictionaries/professional-activities.yaml` a partir de tareas y consultas recurrentes, conservando todas las definiciones previas.

## Flujo de ampliación
1. Identificar la definición insuficiente y la nueva distinción útil: nombre de oficio/tarea, alias regional, actividad concreta, señal para aclarar o límite de alcance.
2. Verificar si existe una entrada equivalente. Si existe, enriquecerla aditivamente con detalles más específicos; si no, agregar una entrada con ID estable y referencia al rubro/tipo del catálogo cuando corresponda.
3. Mantener separados: descripción general del oficio, actividades habituales, ejemplos de consulta y límites/derivaciones. Usar frases compactas y concretas para reducir tokens de consulta.
4. No presentar usos frecuentes como tareas exclusivas ni suponer matrículas, licencias, formación, experiencia o alcance legal. Para tareas reguladas o de riesgo, indicar la necesidad de verificación externa sin afirmar que se realizó.
5. Registrar en `metadata.changelog` fecha, ID afectado, resumen del agregado/mejora y motivo de utilidad. Si el campo aún no existe, agregarlo.
6. Si una definición queda imprecisa, insegura o desactualizada, conservarla y marcarla como `deprecated` o `superseded_by` con motivo y fecha; añadir la versión corregida. Nunca borrar entradas, alias, actividades, límites ni historial.
7. Mantener las restricciones de privacidad, seguridad y servicios prohibidos. Las propuestas sobre nuevas categorías globales siguen el flujo de `catalog_manager`; este diccionario no modifica el catálogo.

## Validación editorial
- Usar español claro, sin datos personales ni secretos.
- Evitar duplicar la misma frase entre entradas; referenciar otra entrada cuando ayude.
- Señalar ambigüedades en vez de inventar precisión.
- Conservar texto previo íntegro al corregir: ampliar o marcar como superado, nunca eliminar.
- Consultar únicamente la entrada afectada durante una interacción, no volcar todo el archivo al modelo.

## Resultado esperado
Diccionario más útil y específico, con adiciones trazables y todo el contenido previo preservado.
