docker stop grafana
docker stop prometheus
docker stop nginx
./run-prometheus.sh
./run-grafana.sh
./run-nginx.sh
