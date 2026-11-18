# Bitácora de troubleshooting y seguridad S12 AP9

## Datos de ejecución

- Estudiante: Lucía del Carmen Sánchez Miranda.
- Docente: Jean Carlos Simón Rojas.
- Fecha: 18 de noviembre de 2026.
- Entorno: AWS Academy, EC2 t3.medium, Ubuntu 24.04.5 LTS, us-east-1.
- Clúster: K3s v1.37.2+k3s1, nodo `s12-node`, namespace `practica-s12`.
- Repositorio: https://github.com/LuciaSanchezMiranda/OAS_TroubleshootingS12
- Imagen pública: `luci4sanchez2007/s12-cloud-lab:1.0.0`.
- Servicio durante la práctica: http://13.222.174.15:30080
- Video: pendiente de grabación y de insertar su enlace en el documento de entrega.

Estos resultados corresponden a la ejecución real en AWS y a las capturas de la
práctica. Las fallas fueron controladas y se corrigieron una por una. Las 14 capturas
se incorporaron al informe local `evidence/Informe_S12_AP9.docx`; evidence está
excluido de Git. El informe debe subirse a Google Docs para entregar su enlace.

## Arquitectura

Cliente → EC2:30080 → Service s12-app → FastAPI:8080 → Service db:5432 → PostgreSQL.
ConfigMap suministra parámetros y Secret inyecta credenciales desechables.
PostgreSQL utiliza un Service ClusterIP interno. La validación inicial mostró
el nodo Ready, dos Pods 1/1 Running y el panel accesible por la IP pública.

## A Configuración incorrecta

**Falla:** APP_ENV=incorrecto en ConfigMap s12-config y reinicio del Deployment.

**Antes:** el Pod nuevo mostró Error/CrashLoopBackOff. Los logs registraron
`CONFIG_ERROR: APP_ENV debe ser 'lab'; revisar ConfigMap s12-config`.
La consulta del ConfigMap confirmó `data.APP_ENV: incorrecto`. El Pod anterior
siguió sano durante el rolling update.

**Causa:** la validación de la aplicación rechazó la variable antes de completar
el arranque. La anotación last-applied del YAML es histórica; el valor efectivo
se comprueba en data.

**Corrección:** `bash scripts/scenario.sh A --fix`. Se restauró APP_ENV=lab y se
reinició el Deployment para renovar las variables envFrom. El cambio del ConfigMap
no modifica en caliente el entorno de un proceso ya iniciado.

**Después:** ambos Pods 1/1 Running, APP_ENV=lab y readiness HTTP 200 con base
conectada. Evidencias en figuras 3 a 5 del informe.

## B Puerto interno incorrecto

**Falla:** Service db con port 5432 y targetPort 5433, mientras PostgreSQL escucha
en 5432.

**Antes:** app 0/1 Running y DB 1/1. El script check-db.py ejecutado dentro de la
app resolvió db a 10.43.5.84, pero TCP devolvió ConnectionRefusedError. Los logs
registraron DB_CONNECTION_ERROR y readiness no disponible. El YAML mostró el
puerto incorrecto en spec.ports.

**Causa:** DNS funcionaba; el Service redirigía a un puerto sin proceso escuchando.
Readiness retiró al Pod del tráfico; liveness siguió comprobando el proceso HTTP
sin reinicios por esta dependencia.

**Corrección:** `bash scripts/scenario.sh B --fix` restauró targetPort=5432.

**Después:** DNS correcto, TCP accesible y SELECT 1 con resultado 1; ambos Pods
1/1 Running y readiness HTTP 200. Evidencias en figuras 6 a 8 del informe.

## C Sondas con endpoints incorrectos

**Falla:** liveness y readiness apuntaban a /ruta-incorrecta-live y
/ruta-incorrecta-ready.

**Antes:** el Pod nuevo quedó 0/1 y aumentó RESTARTS. Los eventos de describe pod
mostraron HTTP 404 para ambas sondas y el mensaje de reinicio por liveness.

**Causa:** las rutas no existían. Readiness impedía recibir tráfico y liveness
provocaba los reinicios del contenedor.

**Corrección:** `bash scripts/scenario.sh C --fix` restauró /health/live y
/health/ready. El Deployment volvió a la configuración saludable.

**Después:** dos Pods 1/1 Running; liveness HTTP 200 con alive y readiness HTTP 200
con base conectada. Evidencias en figuras 9 a 11 del informe.

## Seguridad verificada

La revisión de los Deployments confirmó runAsNonRoot=true, runAsUser=10001,
GID 10001 y seccomp RuntimeDefault. Ambos contenedores usan
readOnlyRootFilesystem=true, allowPrivilegeEscalation=false y capabilities drop ALL.
Los Pods no montan automáticamente el token de ServiceAccount.

El comando id confirmó UID/GID 10001 en app y PostgreSQL. La prueba
`touch /app/no-debe-crearse` en app fue rechazada con Read-only file system y salida 1,
que era el resultado esperado. PostgreSQL tiene volúmenes escribibles para datos,
socket y temporales y fsGroup 10001. Evidencia en figura 12 del informe.

El Secret utiliza data en Base64. Base64 es reversible y no cifra. Las credenciales
son públicas y desechables de laboratorio; no deben reutilizarse con datos reales.

## Exposición y estado final

El navegador accedió a 13.222.174.15:30080 y mostró base conectada, UID 10001 y
nombre del Pod AWS. La ruta pública /health/ready devolvió ready y database connected.
Evidencias en figuras 13 y 14 del informe.

El acceso usa HTTP. Los orígenes permitidos se configuran mediante el Security Group;
las capturas de servicio no certifican por sí solas las reglas de ese grupo.
HTTPS requiere configuración adicional. La IP pública puede cambiar tras detener
y volver a iniciar la instancia.

## Limitaciones y conclusiones

Un nodo y una réplica no proporcionan alta disponibilidad. PostgreSQL usa emptyDir:
sus datos se pierden al reemplazar el Pod. Para producción se requieren PVC,
backups, TLS y secretos administrados fuera de Git.

Los logs de arranque identificaron la configuración inválida; las pruebas DNS/TCP
permitieron aislar el puerto de destino; los eventos HTTP 404 y de reinicio
identificaron las sondas. Después de cada arreglo se comprobaron Pods Ready y
respuestas HTTP o SQL. El hardening se validó con UID no privilegiado y rechazo
de escritura en la raíz del contenedor.
