# Panel administrativo local

Panel local liviano en HTML, CSS y JavaScript. `npm start` inicia el servidor PowerShell 5.1, ligado exclusivamente a `127.0.0.1`. Node.js 18 o posterior proporciona los comandos de desarrollo y pruebas; el panel no usa dependencias npm ni requiere `npm install`. Windows PowerShell debe estar disponible.

## Organización

- `index.html`: estructura y navegación de la aplicación.
- `styles.css`: estilos y adaptación a pantallas pequeñas.
- `app.js`: estado de interfaz, renderizado, gráficos y llamadas a la API.
- `start-admin-panel.ps1`: servidor HTTP local, autenticación por token temporal, endpoints y persistencia XML/JSON.
- `../tests/admin-panel.integration.test.js`: pruebas de integración del servidor usando un directorio temporal aislado.

El servidor y las operaciones de escritura se mantienen en un único proceso PowerShell para conservar el comportamiento existente sobre XML. La interfaz no necesita compilación ni un proceso adicional.

## Desarrollo y pruebas

```sh
npm start       # Inicia el panel
npm test        # Ejecuta las pruebas de integración
npm run check   # Comprueba sintaxis JS y ejecuta todas las pruebas
```

Las pruebas levantan el servidor en un puerto local temporal y usan un directorio temporal para runtime. Verifican salud sin datos privados, autenticación de API, estructura de la respuesta, cabeceras CSP y rechazo de rutas que intentan salir del directorio del panel. No modifican los XML ni el runtime real del proyecto.

## Iniciar

Desde la raíz del proyecto, ejecuta:

```sh
npm start
```

Abre la URL con token temporal que muestra la consola. Mantén la consola abierta; `Ctrl+C` detiene el servidor. Para elegir otro puerto, ejecuta directamente `powershell -NoProfile -ExecutionPolicy Bypass -File ./admin-panel/start-admin-panel.ps1 -ProjectRoot . -Port 8788`.

La allowlist local `runtime/data/admin-whatsapp-numbers.xml` debe contener administradores habilitados y roles. La pantalla solo muestra sus IDs internos y roles; nunca los números de WhatsApp. Acciones:

- `commission_admin`: comprobantes de transferencia y solicitudes de borrado de datos.
- `professional_reliability_admin`: disputas, casos de no finalización, cancelaciones repetidas, fraude, altas relacionadas, cambios o suspensiones de confiabilidad y reactivaciones.
- `catalog_manager`: casos de revisión de categorías/servicios.

## Bandejas y persistencia

El panel indexa comisiones pendientes, disputas de solicitudes, casos de confiabilidad y solicitudes de borrado presentes en los XML runtime. Permite cargar revisiones manuales de fraude, altas relacionadas, cancelaciones, servicios y cambios telefónicos que todavía no tienen flujo de captura en el webhook.

La pestaña **Métricas** muestra derivaciones, conexiones, acuerdos, finalizaciones exitosas y solicitudes no concretadas en ventanas de 7, 30, 90 días o fechas personalizadas; los motivos filtran los casos no concretados. Los conteos usan los hitos con fecha del XML y el estado de la solicitud, sin exponer datos de clientes. Las fechas históricas que no existan se dejan fuera del hito correspondiente.

La pestaña **Servicio del bot** distingue configuración completa, proceso activo y detenido mediante `GET /health` del listener local. El número mostrado se configura con `WA_DISPLAY_PHONE_NUMBER`; en su ausencia se usa `WA_TEST_PHONE_NUMBER`. La API de salud solo devuelve el estado, el puerto local y ese número; no envía ni muestra credenciales.

Los casos creados, decisiones y eventos de auditoría se guardan en `runtime/data/admin-review-cases.json`, excluido de Git. Las decisiones de transferencia, disputa y no finalización actualizan `runtime/data/requests.xml`; las suspensiones y el borrado aprobado actualizan `runtime/data/professionals.xml`. Cada actualización XML crea copia local; al aprobar un borrado, el panel anonimiza el perfil y elimina esa fila de las copias `professionals.xml` que encuentre.

Los comprobantes se abren desde `storage/evidence/commission-payments/` usando una ruta relativa. Para iniciar una revisión de transferencia desde el panel, la solicitud debe existir, ambas partes deben confirmar la finalización y el subtotal de mano de obra, el importe debe coincidir con el 5% configurado y el comprobante ya debe estar guardado en esa carpeta.

Las suspensiones solo se pueden aplicar después de que existan tres casos distintos atribuibles al profesional, revisados dentro de 60 días y todavía no asociados a una sanción. La tercera suspensión acumulada marca `deactivated`; la reactivación anticipada queda registrada. El panel no ejecuta el planificador de vencimientos.

## Limitaciones operativas

- Mantén el panel en la misma máquina que los XML locales; no lo publiques detrás de un proxy ni lo expongas a la red.
- Ejecuta las revisiones cuando el webhook esté detenido. El webhook y el panel son procesos separados y aún no comparten bloqueo de escritura XML; operar ambos a la vez puede sobrescribir cambios concurrentes.
- El webhook todavía no crea todos los casos de revisión definidos en las skills. Regístralos manualmente desde **Registrar revisión** hasta que se implemente la captura automática.
- El webhook actual registra ofertas y respuestas de profesionales; aún no implementa el flujo completo de acuerdos, inicio y cierre del trabajo. Para obtener métricas completas, esos flujos deben escribir `analytics.formalizedAt`, `analytics.startedAt`, `analytics.completedAt` o `analytics.closedAt` y `analytics.closureReason`. El XML conserva marcas de tiempo/eventos previos, pero no se inventan hitos retrospectivos.
- Los cambios de transferencia son revisión visual; no constituyen conciliación bancaria automática. Las disputas no cambian el resultado informado por Cliente/Profesional ni habilitan comisión.
- El historial local de auditoría no se envía por WhatsApp ni a servicios externos.
