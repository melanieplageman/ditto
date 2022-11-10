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

  "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" status &> primary_out

  STATUS="$?"

  if [ "$STATUS" -eq 0 ]; then
    echo "database running, must stop"
    "$INSTALL_DIR"/pg_ctl -D "${!DATADIR}" -o "-p ${!PORT}" -l "${!LOGFILE}" stop -m smart
  fi

  if [ $STATUS -eq 4 ]; then
    echo "no valid data dir. no need to shutdown."
  fi

  if [ $STATUS -eq 3 ]; then
    echo "database stopped. no need to shutdown."
  fi

done
