# Skill 12: Validación interna de dirección para Rawson

## Objetivo
Validar que una dirección escrita por cliente o profesional corresponda al área de servicio configurada para Rawson, incluyendo Playa Unión, antes de ofrecer o aceptar un trabajo.

## Fuente y dependencias
- Usar Google Maps Geocoding API desde el servidor para normalizar la dirección y obtener país, localidad y coordenadas.
- La API se usa solo para validación interna; WhatsApp sigue siendo el único canal de conversación y no se envían enlaces de Google Maps al usuario.
- Mantener la clave de Google en configuración secreta del servidor, nunca en XML, mensajes, repositorio o logs.
- Configurar en `data/location-policy.xml` los nombres aceptados y el polígono oficial de Rawson/Playa Unión. No inventar coordenadas ni tomar un radio aproximado como límite municipal.

## Flujo
1. Solicitar una dirección suficientemente precisa; no inferirla solo desde el número de teléfono o ubicación aproximada.
2. Enviar la consulta a Geocoding API por HTTPS desde el servidor y validar que la respuesta tenga calidad suficiente y esté en Argentina.
3. Comprobar que la localidad normalizada sea Rawson o Playa Unión y que las coordenadas estén dentro del polígono de servicio configurado.
4. Si localidad y polígono coinciden, devolver `validated_in_area` y guardar solo el estado/código de validación. No persistir coordenadas ni respuestas crudas de Google; tratar la dirección escrita por el cliente según la política de retención configurada.
5. Si la respuesta está incompleta, es ambigua, está fuera del polígono o el servicio falla, pedir aclaración o marcar `location_pending`; no ofrecer al profesional la solicitud como ubicada en el área.
6. Si hay varios resultados posibles, preguntar al usuario cuál es la dirección correcta sin exponer datos de terceros.

## Restricciones
- Fallar de forma cerrada: sin política/polígono oficial cargado, sin respuesta del proveedor o con resultado ambiguo, la dirección no se considera validada.
- La geocodificación no garantiza por sí sola que la dirección exista o que el usuario tenga derecho de acceso al lugar.
- No validar por radio aproximado, código postal aislado ni coincidencia parcial de texto.
- No registrar la dirección completa en logs. Limitar su acceso al cliente, profesional asignado tras aceptación y personal estrictamente autorizado.
- Respetar las condiciones de uso y almacenamiento de Google Maps Platform; configurar la retención de la dirección escrita por el usuario antes de producción. Los resultados geocodificados se usan en memoria para validar y se descartan.
- No recopilar ni conservar ubicación precisa cuando baste una zona menos detallada.

## Resultado esperado
Una solicitud marcada como validada dentro del área de Rawson/Playa Unión, pendiente de aclaración o fuera del área; nunca una confirmación inventada.
