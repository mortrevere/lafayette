ls /opt/lafayette/prometheus-data || mkdir /opt/lafayette/prometheus-data
chown 65534:65534 /opt/lafayette/prometheus-data
docker run --name prometheus --rm -d --network host -v /opt/lafayette/prometheus-data/:/prometheus -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.console.libraries=/usr/share/prometheus/console_libraries --web.console.templates=/usr/share/prometheus/consoles --web.external-url=/prometheus/
