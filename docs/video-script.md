# Guion natural para el video S12 AP9

Duración orientativa: 4 minutos a 4 minutos y medio, hablando con calma y haciendo
pausas para señalar cada evidencia. Las fallas ya se resolvieron: muestra las
capturas del antes y después y termina con una comprobación en vivo.

## Antes de grabar

- Abre el informe con las capturas de A, B, C y seguridad.
- Abre el repositorio y el diagrama del README.
- Mantén abierta la terminal Ubuntu conectada a EC2.
- Abre http://13.222.174.15:30080 y la ruta /health/ready.
- Usa zoom suficiente para leer los comandos y los mensajes.
- No muestres la llave .pem ni credenciales AWS.

## 0:00 a 0:40 Presentación y arquitectura

**Muestra:** diagrama del README y después la terminal con:

```bash
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods,svc -n practica-s12
```

**Di:**

“Hola, soy Lucía Sánchez Miranda. En este video voy a mostrar mi laboratorio de
Kubernetes en AWS y cómo resolví tres fallas de configuración, conexión y salud
de los contenedores.

Para esta práctica usé una instancia EC2 de AWS Academy e instalé Kubernetes con
K3s. La aplicación tiene un backend en FastAPI y una base de datos PostgreSQL.
Todo está dentro del namespace practica-s12.

Como se ve aquí, el nodo está Ready y los dos Pods están funcionando. Para entrar
a la aplicación uso la IP pública de la instancia con el puerto 30080.”

## 0:40 a 1:20 Falla A

**Muestra:** capturas A antes y diagnóstico; señala CrashLoopBackOff,
CONFIG_ERROR y APP_ENV incorrecto. Después muestra A después.

**Di:**

“La primera falla fue una variable mal configurada. Cambié APP_ENV por un valor
que la aplicación no aceptaba y el nuevo Pod entró en CrashLoopBackOff.

Para saber qué pasaba revisé los logs. El mensaje decía que APP_ENV debía tener
el valor lab. Luego revisé el ConfigMap y confirmé que ahí estaba el valor incorrecto.

Lo corregí y reinicié el Deployment para que el Pod tomara la nueva configuración.
Aquí se ve el resultado: los dos Pods están listos y la aplicación vuelve a
responder HTTP 200.”

## 1:20 a 2:00 Falla B

**Muestra:** captura B antes con targetPort 5433 y diagnóstico DNS/TCP.
Después muestra B después con SELECT 1 y HTTP 200.

**Di:**

“La segunda falla fue de conexión con la base de datos. El Service estaba enviando
las conexiones al puerto 5433, pero PostgreSQL escuchaba en el 5432.

Hice una prueba desde el Pod de la aplicación. El nombre db sí se resolvía, pero
la conexión era rechazada. Eso me ayudó a ubicar el problema en el puerto del Service.

Restauré targetPort a 5432 y repetí la prueba. Ahora DNS funciona, la conexión TCP
se establece y la consulta SELECT 1 devuelve uno. La aplicación también recuperó
su estado Ready.”

## 2:00 a 2:40 Falla C

**Muestra:** captura C antes, eventos 404 y reinicio, y captura C después.

**Di:**

“La tercera falla estaba en las sondas de salud. Configuré rutas que no existían
y el nuevo Pod empezó a reiniciarse.

Con describe pod revisé los eventos y encontré respuestas 404 en las sondas.
Readiness determina si el Pod está listo para recibir tráfico. Liveness comprueba
si el contenedor responde y puede reiniciarlo cuando falla repetidamente.

Corregí las rutas a health live y health ready. Después de eso, ambas respondieron
HTTP 200 y el despliegue volvió a quedar estable.”

## 2:40 a 3:25 Seguridad

**Muestra:** captura de seguridad y el securityContext de
k8s/03-app-deployment.yaml en GitHub.

**Di:**

“También configuré la seguridad de los contenedores. Aquí ejecuto id y se ve que
la aplicación y PostgreSQL usan el UID 10001, por lo que sus procesos no corren
como root.

Además, el sistema de archivos raíz está en modo de solo lectura. Para comprobarlo
intenté crear un archivo y la operación fue rechazada, que era lo esperado.

Los manifiestos también deshabilitan la elevación de privilegios y eliminan las
capabilities adicionales. Las credenciales del laboratorio se inyectan con un
Secret en Base64. Base64 es codificación, no cifrado.”

## 3:25 a 4:10 Servicio funcionando y cierre

**Muestra:** panel web mediante la IP pública y pulsa Actualizar estado.
Luego abre /health/ready. Termina mostrando las carpetas k8s, scripts y docs del repo.

**Di:**

“Finalmente, esta es la aplicación funcionando desde la IP pública de AWS.
El panel muestra la base conectada y el usuario sin privilegios de root.
La ruta de readiness también confirma que el servicio está listo.

En el repositorio dejé los manifiestos, los scripts de diagnóstico y la bitácora.
En el informe están las capturas del antes y después de cada problema.

Con esta práctica pude identificar cada falla usando logs, eventos y pruebas de
conexión, y comprobar que la solución realmente funcionaba. Esta instalación es
de laboratorio; para producción agregaría almacenamiento persistente, backups y
HTTPS. Gracias.”

## Comprobaciones en vivo opcionales

Si deseas mostrar la validación de seguridad en vivo, ejecuta estos comandos
antes de volver al navegador. Considera el tiempo total para no superar 5 minutos.

```bash
sudo k3s kubectl exec deployment/s12-app -n practica-s12 -- id
sudo k3s kubectl exec deployment/s12-db -n practica-s12 -- id
sudo k3s kubectl exec deployment/s12-app -n practica-s12 -- touch /app/no-debe-crearse
```

El último comando debe fallar con Read-only file system. No hace falta volver a
provocar las fallas para grabar: utiliza tus capturas reales y explica lo ocurrido.
