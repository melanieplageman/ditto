INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

LS1_PORT=7432

DB="postgres"

"$INSTALL_DIR"/psql -p "$LS1_PORT" -d "$DB"
