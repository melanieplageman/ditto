INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

PRIMARY_PORT=5432
PRIMARY_DATADIR="/tmp/pgdataprimary"
PRIMARY_LOGFILE="logfileprimary"

for role in PRIMARY; do
  DATADIR=${role}_DATADIR
  PORT=${role}_PORT
  LOGFILE=${role}_LOGFILE

  # Delete old logfile
  rm "${!LOGFILE}"

  # Init cluster
  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" status

  STATUS="$?"

  if [ "$STATUS" -eq 0 ]; then
    echo "database running, must stop, then initdb"
    "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" stop
  fi

  if [ $STATUS -eq 4 ]; then
    echo "no valid data dir. need initdb anyway"
  fi

  if [ $STATUS -eq 3 ]; then
    echo "database stopped. doing initdb"
  fi

  rm -rf "${!DATADIR}"
  mkdir "${!DATADIR}"
  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -l "${!LOGFILE}" init
  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" start
done

DB="postgres"

PSQL_PRIMARY=("$INSTALL_DIR"/psql -p "$PRIMARY_PORT" -d "$DB")

# Set wal_level logical
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_level = logical;"

# Set max_replication_slots
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET max_replication_slots = 10;"

# Set log level
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET log_min_messages = DEBUG2;"

# Set wal sender and receiver timeouts
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_receiver_timeout='3000s'"
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_sender_timeout='3000s'"

# Restart primary
"$INSTALL_DIR"/pg_ctl -D "$PRIMARY_DATADIR" -o "-p $PRIMARY_PORT" -l "$PRIMARY_LOGFILE" restart -m smart

# # Create a slot 'regression_slot' using the output plugin 'test_decoding'
# "${PSQL_PRIMARY[@]}" -c "SELECT * FROM pg_create_logical_replication_slot('regression_slot', 'test_decoding', false, true);"

# "${PSQL_PRIMARY[@]}" -c "SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;"

# # Confirm no changes yet
# "${PSQL_PRIMARY[@]}" -c "SELECT * FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL);"

# # Create table
# "${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE_NAME}(a int, b int);"
# "${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE2_NAME}(a int, b int);"
