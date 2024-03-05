#!/bin/bash
# This script is modified from `pbs_habitat` and `pbs_db_utility`
# Some varibles shall be adjusted according to your deployment.

# load conf
. /etc/pbs.conf
export PBS_HOME
export PBS_EXEC
export PBS_SERVER
export PBS_ENVIRONMENT

# Source the file that sets DB env variables
. "$PBS_EXEC"/libexec/pbs_db_env
export PBS_DATA_SERVICE_USER=postgres
export PBS_DATA_SERVICE_PORT=15007

server_started=0
create_new_svr_data=1

echo "*** Stopping PBS services"
systemctl stop pbs || { echo "Error stopping PBS, exit..."; exit 1; }

echo "*** Removing old database"
rm -rf "${PBS_HOME}/datastore" || { echo "Error rm datastore, exit..."; exit 1; }

# invoke the dataservice creation script for pbs
echo "*** Reinitializing PBS dataservice"
resp=`${PBS_EXEC}/libexec/pbs_db_utility install_db 2>&1`
ret=$?
if [ $ret -ne 0 ]; then
	echo "*** Error initializing the PBS dataservice"
	echo "Error details:"
	echo "$resp"
	exit $ret
fi

# add default data in postgres
if [ $create_new_svr_data -eq 1 ] ; then
	echo "*** Setting default queue and resource limits."

	${PBS_EXEC}/sbin/pbs_server -t create
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "*** Error starting pbs server"
		exit $ret
	fi
	server_started=1

	tries=3
	while [ $tries -ge 0 ]
	do
		echo "Trying to connect server..."
		${PBS_EXEC}/bin/qmgr <<-EOF > /dev/null
			create queue workq
		EOF
		ret=$?
		if [ $ret -eq 0 ]; then
			echo "Connected!"
			break
		fi
		tries=$((tries-1))
		sleep 2
	done
	${PBS_EXEC}/bin/qmgr <<-EOF > /dev/null
		set queue workq queue_type = Execution
		set queue workq enabled = True
		set queue workq started = True
		set server default_queue = workq
	EOF
	if [ -f ${PBS_HOME}/server_priv/$PBS_licensing_loc_file ]; then
		read ans < ${PBS_HOME}/server_priv/$PBS_licensing_loc_file
		echo "*** Setting license file location(s)."
		${PBS_EXEC}/bin/qmgr <<-EOF > /dev/null
			set server pbs_license_info = $ans
		EOF
	fi
fi

if [ $server_started -eq 1 ]; then
	echo "*** Adding default settings"
	${PBS_EXEC}/bin/qmgr -c "set server job_history_enable=1"
	${PBS_EXEC}/bin/qmgr -c "set server acl_roots=root"

	echo "*** Stopping PBS Server"
	${PBS_EXEC}/bin/qterm
fi

echo "================================"
echo "PBS dataservice is reconfigured."
echo "Please restart the PBS service."
