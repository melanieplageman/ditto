INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

REPLICA_PORT=6432

DB="postgres"

"$INSTALL_DIR"/psql -p "$REPLICA_PORT" -d "$DB"
