INSTALL_DIR="/home/mplageman/code/pginstall2/bin"
DB="postgres"

PRIMARY_PORT=5432
PRIMARY_DATADIR="/tmp/pgdataprimary"
PRIMARY_LOGFILE="logfileprimary"

REPLICA_PORT=6432
REPLICA_DATADIR="/tmp/pgdatareplica"
REPLICA_LOGFILE="logfilereplica"

# LS is Logical Standby
LS1_PORT=7432
LS1_DATADIR="/tmp/pgdatalogicalstandby1"
LS1_LOGFILE="logfilelogicalstandby1"

# Stop both primary and replica if already running
for role in REPLICA PRIMARY LS1; do
  DATADIR=${role}_DATADIR
  PORT=${role}_PORT
  LOGFILE=${role}_LOGFILE

  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" status

  STATUS="$?"

  if [ "$STATUS" -eq 0 ]; then
    echo "database running, must stop."
    "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" stop -m smart
  fi

  if [ $STATUS -eq 4 ]; then
    echo "no valid data dir."
  fi

  if [ $STATUS -eq 3 ]; then
    echo "database already stopped."
  fi

  # Delete their datadirs and logfiles so that we are ready to init the
  # primary, take a backup, and start the standby
  rm -rf "${!DATADIR}"
  rm -f "${!LOGFILE}"
done

# Init the primary
"$INSTALL_DIR"/pg_ctl -D "$PRIMARY_DATADIR" -l "$PRIMARY_LOGFILE" init
"$INSTALL_DIR"/pg_ctl -D "$PRIMARY_DATADIR" -o "-p $PRIMARY_PORT" -l "$PRIMARY_LOGFILE" start

PSQL_PRIMARY=("$INSTALL_DIR"/psql -p "$PRIMARY_PORT" -d "$DB")
PSQL_REPLICA=("$INSTALL_DIR"/psql -p "$REPLICA_PORT" -d "$DB")

# Enable streaming replication and two-phase xacts
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET max_standby_streaming_delay=0"
"${PSQL_PRIMARY[@]}" -c "ALTER SYSTEM SET max_prepared_transactions=10"

# Take a backup of the primary into the replica's data directory
"$INSTALL_DIR"/pg_basebackup -c fast -h localhost -p "$PRIMARY_PORT" -D "$REPLICA_DATADIR" -R

# Start replica
"$INSTALL_DIR"/pg_ctl -D "$REPLICA_DATADIR" -o "-p $REPLICA_PORT" -l "$REPLICA_LOGFILE" start

# Set wal_level logical on replica
"${PSQL_REPLICA[@]}" -c "ALTER SYSTEM SET wal_level = logical;"

# Restart physical replica
"$INSTALL_DIR"/pg_ctl -D "$REPLICA_DATADIR" -o "-p $REPLICA_PORT" -l "$REPLICA_LOGFILE" restart -m smart

# Init the logical standby
"$INSTALL_DIR"/pg_ctl -D "$LS1_DATADIR" -l "$LS1_LOGFILE" init
"$INSTALL_DIR"/pg_ctl -D "$LS1_DATADIR" -o "-p $LS1_PORT" -l "$LS1_LOGFILE" start

PSQL_LS1=("$INSTALL_DIR"/psql -p "$LS1_PORT" -d "$DB")

"${PSQL_LS1[@]}" -c "ALTER SYSTEM SET wal_level = logical;"

# Restart logical standby
"$INSTALL_DIR"/pg_ctl -D "$LS1_DATADIR" -o "-p $LS1_PORT" -l "$LS1_LOGFILE" restart -m smart

# Set up some replication
TABLE_NAME="foo"
TABLE2_NAME="bar"
PUB="pub1"
SUB="sub1"

# Create table
"${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE_NAME}(a int, b int);"
"${PSQL_PRIMARY[@]}" -c "CREATE TABLE ${TABLE2_NAME}(a int, b int);"
"${PSQL_LS1[@]}" -c "CREATE TABLE ${TABLE_NAME}(a int, b int);"
"${PSQL_LS1[@]}" -c "CREATE TABLE ${TABLE2_NAME}(a int, b int);"

"${PSQL_REPLICA[@]}" -c "CREATE PUBLICATION $PUB FOR TABlE $TABLE_NAME, $TABLE2_NAME;"
"${PSQL_LS1[@]}" -c "CREATE SUBSCRIPTION $SUB CONNECTION 'dbname=$DB user=mplageman host=localhost port=$REPLICA_PORT' PUBLICATION $PUB;"

"${PSQL_PRIMARY[@]}" -c "INSERT INTO $TABLE_NAME SELECT i, i FROM generate_series(1,10)i;"
"${PSQL_PRIMARY[@]}" -c "INSERT INTO $TABLE2_NAME SELECT 1, 2 FROM generate_series(1,3)i;"
