INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

PRIMARY_PORT=5432
PRIMARY_DATADIR="/tmp/pgdataprimary"
PRIMARY_LOGFILE="logfileprimary"
DB="postgres"

TABLE3_NAME="baz"

PSQL_PRIMARY=("$INSTALL_DIR"/psql -p "$PRIMARY_PORT" -d "$DB")

"${PSQL_PRIMARY[@]}" -c "INSERT INTO $TABLE3_NAME SELECT 77, 77 FROM generate_series(1,3);"
