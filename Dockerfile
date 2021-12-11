FROM mariadb:latest

COPY galera.cnf /etc/mysql/conf.d/galera.cnf.template
RUN chown -R mysql:mysql /etc/mysql/conf.d

# Overwrite "mariadb" so we can intercept the
# call from the upstream entrypoint
COPY galera.sh /usr/local/sbin/mariadb

ENV MYSQL_ROOT_PASSWORD="mariadb" \
	MYSQL_USER="mariadb" \
	MYSQL_PASSWORD="mariadb" \
	MYSQL_DATABASE="data" \
	MYSQL_MAX_CONNECTIONS="256" \
	MYSQL_MAX_STATEMENT_TIME="60" \
	MYSQL_MAX_ALLOWED_PACKET="16M" \
	MYSQL_QUERY_CACHE_LIMIT="128K" \
	MYSQL_QUERY_CACHE_SIZE="128M" \
	MYSQL_INNODB_BUFFER_POOL_SIZE="1G" \
	MYSQL_INNODB_LOCK_WAIT_TIMEOUT="60" \
	MYSQL_INITDB_SKIP_TZINFO="TRUE" \
	WSREP_FC_FACTOR="0.9" \
	WSREP_FC_LIMIT="32" \
	WSREP_SYNC_WAIT="7" \
	SERVICE_NAME="mariadb" \
	CLUSTER_NODES="3"
