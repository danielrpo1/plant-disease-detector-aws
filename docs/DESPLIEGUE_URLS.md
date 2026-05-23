# URLs del despliegue EAFIT

| Servicio | URL |
|----------|-----|
| GitHub | https://github.com/danielrpo1/plant-disease-detector-aws |
| Web Ojoverde (S3) | http://plant-web-darestrepo-eafit.s3-website-us-east-1.amazonaws.com |
| API | http://18.188.204.143:8000 |
| API docs | http://18.188.204.143:8000/docs |
| RDS | `plant-disease-db-darestrepo-eafit.cbis88iw4dxg.us-east-2.rds.amazonaws.com` |

Si la web S3 no carga: consola S3 → bucket `plant-web-darestrepo-eafit` → permisos → desbloquear acceso público y política de lectura `GetObject` para `*`.
