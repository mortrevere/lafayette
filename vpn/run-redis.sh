docker run -d --name redis --network host -v /opt/lafayette/redis-data:/data -v /opt/lafayette/redis.conf:/redis.conf redis:6 redis-server /redis.conf
