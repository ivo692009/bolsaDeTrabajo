# Plantilla de documentación para una skill

## 1. Nombre

Nombre de la skill.

## 2. Objetivo

Describe el problema que resuelve esta skill y el resultado esperado.

## 3. Estado y dependencias

Indica qué partes están implementadas, cuáles son política futura y qué datos, permisos, servicios o configuración requiere. No describas una propuesta como función activa.

## 4. Usuario objetivo

Indica quién la utilizará y en qué contexto.

## 5. Entrada

Lista los datos que recibe la skill:

- usuario
- solicitud
- contexto
- historial o información adicional

## 6. Proceso

Explica la lógica interna:

1. Recibir la intención del usuario.
2. Validar los datos de entrada.
3. Consultar reglas o información del negocio.
4. Generar respuesta o acción.
5. Verificar cumplimiento de restricciones.

Incluye resultados para entradas incompletas o ambiguas, identidad/permiso no válido, datos corruptos, dependencia fuera de servicio y persistencia fallida. Especifica cuándo preguntar, reintentar, dejar pendiente o escalar.

## 7. Salida esperada

Describe la respuesta, estructura o acciones recomendadas.

## 8. Restricciones

Define limites del comportamiento:

- no inventar información
- no revelar datos sin permiso
- no ejecutar acciones no autorizadas

## 9. Casos de uso y límites

Incluye al menos 2 ejemplos reales o hipotéticos.

Incluye al menos un caso normal, uno ambiguo y uno de fallo; explica también qué casos quedan fuera de esta skill.

## 10. Métricas de éxito

Ejemplo:

- precisión de la respuesta
- cumplimiento de la política
- tiempo de respuesta
- tasa de escalamiento manual

Mide seguridad y calidad además de volumen: acciones duplicadas, falsos positivos, decisiones revertidas, fallos sin estado claro y solicitudes de revisión pendientes. No optimices una métrica a costa de privacidad o de decisiones injustas.

## 11. Historial

Registra fecha, cambio y motivo. No borres definiciones anteriores: márcalas como superadas y agrega la versión corregida.
