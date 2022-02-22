docker run --rm -d --network host --env-file $(pwd)/grafana.env \
       -e GF_SECURITY_ADMIN_PASSWORD=$(cat /opt/lafayette/grafana.pw) \
       -v $(pwd)/grafana-prom-datasource.yaml:/etc/grafana/provisioning/datasources/prometheus.yml \
       -v $(pwd)/grafana-dashboard.yaml:/etc/grafana/provisioning/dashboards/grafana-dashboard.yml \
       -v $(pwd)/dashboard.json:/var/lib/grafana/dashboards/dashboard.json \
       --name grafana grafana/grafana-oss:8.2.0
