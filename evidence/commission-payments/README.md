# Evidencia privada de comisiones

Almacena aquí únicamente comprobantes enviados por profesionales para pagar la comisión de intermediación. No guardes estos archivos dentro de `gallery/`.

Usa una carpeta por ID de solicitud (`<request-id>/`) y conserva una ruta relativa en el registro de comisión de `data/requests.xml`. La ruta no debe exponerse a clientes ni servirse como URL pública.

La evidencia contiene datos financieros personales: limita permisos de lectura y escritura al proceso de la aplicación y a las personas revisoras autorizadas; protégela también en copias de seguridad y define una política de retención antes de producción. No agregues comprobantes reales a repositorios públicos.

La recepción de una imagen solo registra que se presentó evidencia. Mantén el pago pendiente hasta que una persona autorizada revise el importe, fecha, destino y referencia, y registre su decisión en el XML.
