INSTALL_DIR="/home/mplageman/code/pginstall2/bin"
DB="postgres"

PRIMARY_PORT=5432
PRIMARY_DATADIR="/tmp/pgdataprimary"
PRIMARY_LOGFILE="logfileprimary"

REPLICA_PORT=6432
REPLICA_DATADIR="/tmp/pgdatareplica"
REPLICA_LOGFILE="logfilereplica"

# Stop both primary and replica if already running
for role in REPLICA PRIMARY; do
  DATADIR=${role}_DATADIR
  PORT=${role}_PORT
  LOGFILE=${role}_LOGFILE

  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" status

  STATUS="$?"

  if [ "$STATUS" -eq 0 ]; then
    echo "database running, must stop."
    "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" stop
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
  rm "${!LOGFILE}"
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
