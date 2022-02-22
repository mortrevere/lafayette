docker run --network host -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.console.libraries=/usr/share/prometheus/console_libraries --web.console.templates=/usr/share/prometheus/consoles --web.external-url=/prometheus/
