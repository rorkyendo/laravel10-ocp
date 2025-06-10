================ ImageStream Config ==================
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: laravel
  namespace: poc-ocp

================ BUILDS CONFIG ====================

apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  namespace: poc-ocp # hapus jika default
  name: laravel-build # Ganti build name nya (1,2,3,dstnya)
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

=============== DEPLOYMENT ==================

apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  labels:
    app: laravel
spec:
  replicas: 3 # jumlah pod yang di replica dapat di scaling
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
            - containerPort: 9000 # php-fpm default
          volumeMounts:
            - name: storage
              mountPath: /var/www/html/storage
      volumes:
        - name: storage
          emptyDir: {} # atau PersistentVolumeClaim jika diperlukan

=============== SERVICES ==================
apiVersion: v1
kind: Service
metadata:
  name: laravel-service
spec:
  selector:
    app: laravel
  ports:
    - protocol: TCP
      port: 9000
      targetPort: 9000

=============== NGINX ConfigMap ================
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  default.conf: |
    server {
        listen 8080;
        server_name localhost;

        location / {
            root /var/www/html/public;
            index index.php index.html index.htm;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass laravel-service:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /var/www/html/public$fastcgi_script_name;
        }
    }


=============== NGINX DEPLOYMENT ==================


apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1 # dapat di scaling jumlah deployment
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d
            - name: laravel-html
              mountPath: /var/www/html
      volumes:
        - name: nginx-conf
          configMap:
            name: nginx-conf
        - name: laravel-html
      volumeMounts:
  	- name: nginx-cache
          mountPath: /var/cache/nginx
      volumes:
        - name: nginx-cache
          emptyDir: {}
            emptyDir: {} # Gunakan PVC jika perlu sinkronisasi storage


=============== NGINX SERVICES ===================

apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP #(type: NodePort <= untuk akses dari luar)


=========== Routes ==============

apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: laravel-route
spec:
  to:
    kind: Service
    name: nginx-service
  port:
    targetPort: 8080
  tls:
    termination: edge
