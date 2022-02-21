docker run --rm --network host --env-file $(pwd)/grafana.env \
       -v $(pwd)/grafana-prom-datasource.yaml:/etc/grafana/provisioning/datasources/prometheus.yml \
       -v $(pwd)/grafana-dashboard.yaml:/etc/grafana/provisioning/dashboards/grafana-dashboard.yml \
       -v $(pwd)/dashboard.json:/var/lib/grafana/dashboards/dashboard.json \
       --name grafana grafana/grafana-oss:8.2.0
