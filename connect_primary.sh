INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

PRIMARY_PORT=5432

DB="postgres"

"$INSTALL_DIR"/psql -p "$PRIMARY_PORT" -d "$DB"
