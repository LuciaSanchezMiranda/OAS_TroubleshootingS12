# Validación local de implementación

Fecha: 18 de noviembre de 2026. Entorno: Windows, Docker Desktop Linux y Kubernetes
v1.32.2, contexto `docker-desktop`. **Estas pruebas no constituyen evidencia AWS.**

| Comprobación ejecutada | Resultado observado |
| --- | --- |
| `docker compose up -d --build` | Imagen construida; app y PostgreSQL iniciados |
| `/api/status` y `/health/ready` en localhost:8080 | HTTP 200; consulta SQL devuelve 1 |
| `id` en ambos contenedores | UID y GID 10001 |
| Escritura `/app/no-debe-crearse` | Rechazada: Read-only file system |
| Validación YAML por kubectl | Siete manifiestos válidos |
| Aplicación de Deployments en Kubernetes local | Ambos Pods 1/1 Running |
| Falla A: ConfigMap APP_ENV incorrecto | Pod nuevo Error; CONFIG_ERROR; proceso sale |
| Corrección A | Rollout exitoso; app Ready |
| Falla B: Service targetPort 5433 | DNS resuelve; TCP ConnectionRefusedError; readiness falla |
| Corrección B | DNS, TCP y SELECT 1 exitosos; app Ready |
| Falla C: rutas de sondas inexistentes | Eventos HTTP 404 y reinicio de contenedor por liveness |
| Corrección C | Parches restauran /health/live y /health/ready |
| Sintaxis de scripts PowerShell | Sin errores del parser |
| `pip check` en imagen | Sin dependencias incompatibles |

Para no interferir con un servicio preexistente, solo el Service **local** de esta
prueba se creó con NodePort **30082**. El manifiesto del repositorio conserva
**30080** para AWS. Compose publica localhost:8080.

No se creó infraestructura AWS ni se publicaron imágenes o cambios a GitHub como
parte de estas pruebas. El informe del laboratorio debe completarse con la
ejecución cloud y las capturas de la estudiante.
