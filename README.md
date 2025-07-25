## STEP BY STEP Configurasi OCP 
![image](https://github.com/user-attachments/assets/e283823b-ced3-4aba-bad0-69972523464a)

OCP Playgorund by RedHat OpenShift
https://www.redhat.com/en/interactive-labs/red-hat-openshift-4.17-playground

<ul>
<li>Membuat Project dengan nama poc-ocp</li>
<li>Membuat ImageStream</li>
<pre>
    apiVersion: image.openshift.io/v1
    kind: ImageStream
    metadata:
      name: laravel
      namespace: poc-ocp    
</pre>

<li>Membuat Build Config</li>
<pre>
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: laravel-build
  namespace: poc-ocp
spec:
  source:
    type: Git
    git:
      uri: https://github.com/rorkyendo/laravel10-ocp.git
      ref: main
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  output:
    to:
      kind: ImageStreamTag
      name: laravel:latest
</pre>
<li>Lakukan build image dari BuildConfig yang sudah dibuat sebelumnya</li>
<li>Buat Persitent Volume Claim</li>
<pre>
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: laravel-pvc
  namespace: poc-ocp
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
</pre>
<li>Lakukan Deployment PHP-FPM dari Build Image Laravel</li>
<pre>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  namespace: poc-ocp
spec:
  replicas: 3 #bisa scalable
  selector:
    matchLabels:
      app: laravel
  template:
    metadata:
      labels:
        app: laravel
    spec:
      containers:
        - name: laravel
          image: image-registry.openshift-image-registry.svc:5000/poc-ocp/laravel:latest
          ports:
            - containerPort: 9000
          command:
            - php-fpm
</pre>
<li>Buat service laravel (php-fpm) pada port 9000</li>
<pre>
apiVersion: v1
kind: Service
metadata:
  name: laravel-service
  namespace: poc-ocp
spec:
  selector:
    app: laravel
  ports:
    - protocol: TCP
      port: 9000
      targetPort: 9000
</pre>
<li>Buat ConfigMap NGINX</li>
<pre>
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
  namespace: poc-ocp
data:
  nginx.conf: |
    worker_processes auto;
    pid /tmp/nginx.pid;
    events {
        worker_connections 1024;
    }
    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        sendfile        on;
        keepalive_timeout  65;
        include /etc/nginx/conf.d/*.conf;
    }

  default.conf: |
    server {
        listen 8080;
        server_name localhost;

        root /var/www/html/public;
        index index.php;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass laravel-service:9000;
            fastcgi_param SCRIPT_FILENAME /var/www/html/public$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
        }
    }
</pre>
<li>Lakukan Deployment NGINX</li>
<pre>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: poc-ocp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      initContainers:
        - name: copy-laravel
          image: image-registry.openshift-image-registry.svc:5000/poc-ocp/laravel:latest
          command:
            - sh
            - -c
            - |
              echo "Copying Laravel app to PVC..."
              cp -r /var/www/html/. /shared
          volumeMounts:
            - name: laravel-storage
              mountPath: /shared
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
            - name: laravel-storage
              mountPath: /var/www/html
            - name: cache
              mountPath: /var/cache/nginx
      volumes:
        - name: nginx-conf
          configMap:
            name: nginx-conf
        - name: laravel-storage
          persistentVolumeClaim:
            claimName: laravel-pvc
        - name: cache
          emptyDir: {}
</pre>
<li>Buat NGINX Service</li>
<pre>
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: poc-ocp
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: NodePort #NodePort untuk diakses secara publik
</pre>
<li>Buat routes untuk dapat diakses dari internet</li>
<pre>
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: laravel-route
  namespace: poc-ocp
spec:
  to:
    kind: Service
    name: nginx-service
  port:
    targetPort: 8080
  tls:
    termination: edge
</pre>
</ul>
