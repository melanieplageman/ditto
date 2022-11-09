INSTALL_DIR="/home/mplageman/code/pginstall2/bin"

PRIMARY_PORT=5432
PRIMARY_DATADIR="/tmp/pgdataprimary"
PRIMARY_LOGFILE="logfileprimary"

REPLICA_PORT=6432
REPLICA_DATADIR="/tmp/pgdatareplica"
REPLICA_LOGFILE="logfilereplica"

for role in REPLICA PRIMARY; do
  DATADIR=${role}_DATADIR
  PORT=${role}_PORT
  LOGFILE=${role}_LOGFILE

  # Delete old logfile
  rm "${!LOGFILE}"

  # Init cluster
  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" status &> primary_out

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
PSQL_REPLICA=("$INSTALL_DIR"/psql -p "$REPLICA_PORT" -d "$DB")

# Set wal_level logical and restart
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_level = logical;"
"${PSQL_REPLICA[@]}" -c "ALTER SYSTEM SET wal_level = logical;"

# Set log level
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET log_min_messages = DEBUG2;"
"${PSQL_REPLICA[@]}" -c "ALTER SYSTEM SET log_min_messages = DEBUG2;"

# Set wal sender and receiver timeouts
"${PSQL_REPLICA[@]}" -c "ALTER SYSTEM SET wal_receiver_timeout='3000s'"
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_receiver_timeout='3000s'"
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET wal_sender_timeout='3000s'"
"${PSQL_REPLICA[@]}" -c "ALTER SYSTEM SET wal_sender_timeout='3000s'"

# Restart primary
"$INSTALL_DIR"/pg_ctl -D "$PRIMARY_DATADIR" -o "-p $PRIMARY_PORT" -l "$PRIMARY_LOGFILE" restart -m smart

# Restart replica
"$INSTALL_DIR"/pg_ctl -D "$REPLICA_DATADIR" -o "-p $REPLICA_PORT" -l "$REPLICA_LOGFILE" restart -m smart

# Set up replication
TABLE_NAME="foo"
TABLE2_NAME="bar"
PUB="pub1"
SUB="sub1"

# Create table
"${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE_NAME}(a int, b int);"
"${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE2_NAME}(a int, b int);"
"${PSQL_REPLICA[@]}" -c "CREATE TABLE ${TABLE_NAME}(a int, b int);"
"${PSQL_REPLICA[@]}" -c "CREATE TABLE ${TABLE2_NAME}(a int, b int);"

"${PSQL_PRIMARY[@]}" -c "CREATE PUBLICATION $PUB FOR TABlE $TABLE_NAME, $TABLE2_NAME;"
"${PSQL_REPLICA[@]}" -c "CREATE SUBSCRIPTION $SUB CONNECTION 'dbname=$DB user=mplageman host=localhost port=$PRIMARY_PORT' PUBLICATION $PUB;"

"${PSQL_PRIMARY[@]}" -c "INSERT INTO $TABLE_NAME SELECT i, i FROM generate_series(1,10)i;"
"${PSQL_PRIMARY[@]}" -c "INSERT INTO $TABLE2_NAME SELECT 1, 2 FROM generate_series(1,3)i;"
