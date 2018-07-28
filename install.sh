#!/bin/bash

name=$1
RETHINK_DIR_DIRECTORY="$GOPATH/src/rethinkdb_data"
RETHINK_PROCESS="rethinkdb --bind all --daemon"
rethink_running=0
zero=0

SERVER=$GOPATH/src/github.com/mudphilo/chat/server
DB=$GOPATH/src/github.com/mudphilo/chat/tinode-db

DB_CONFIG=$GOPATH/src/github.com/mudphilo/chat/tinode-db/tinode.conf
DB_DATA=$GOPATH/src/github.com/mudphilo/chat/tinode-db/data.json
LOGFILE=/var/log/tinode/log.log

cd $GOPATH

if [ -d "$RETHINK_DIR_DIRECTORY" ]
    then
    echo "clearing previous DB logs "
    rm -Rfv $RETHINK_DIR_DIRECTORY/*
fi

# check if rethinkdb daemon is running
pgrep -f "$RETHINK_PROCESS" |
{
     while read -r pid ; do
        echo "GOT PID $pid killing process"
        kill $pid
        (( rethink_running += 1 ))
    done

    echo "GOT rethinkdb daemon running instances $rethink_running"

    # initialize application
    if [ "$rethink_running" -gt "$zero" ]
        then
            # initialize database
            echo " rethinkdb database not running"
            echo "starting rethinkdb as daemon "
            rethinkdb --bind all --daemon >> $LOGFILE
    fi
}

echo "installing main application. switching to chat/server "
# build application
cd $DB
pwd
go install -tags rethinkdb

# check DB

if [ "$name" = "reset" ]
    then
        # initialize database
        echo "initialize database "
        $GOPATH/bin/tinode-db -config=$DB_CONFIG -data=$DB_DATA >> $LOGFILE
fi

# initialize application
cd $SERVER

go install -tags rethinkdb
# dont run the server, we do this using service
echo "finished, run app as daemon "
exit