#!/bin/bash

# Cross-compiling script using https://github.com/mitchellh/gox
# I use this to compile the Linux version of the server on my Mac.

# Supported OSs: darwin windows linux
goplat=( darwin windows linux )
# Supported CPU architectures: amd64
goarc=( amd64 )
# Supported database tags
dbtags=( mysql rethinkdb )

DAEMON=$GOPATH/bin/server
DB_DAEMON = $GOPATH/bin/tinode_db
PROGRAM_CONFIG=$GOPATH/src/github.com/mudphilo/chat/server/tinode.conf
DB_CONFIG=$GOPATH/src/github.com/mudphilo/chat/tinode-db/tinode.conf
PROGRAM_DATA = $GOPATH/tinode-web
DB_DATA=$GOPATH/src/github.com/mudphilo/chat/tinode-db/data.json
LOGFILE=/var/log/somefile.log

RETHINK_DIR_DIRECTORY="$GOPATH/src/rethinkdb_data"
RETHINK_PROCESS="rethinkdb --bind all --daemon"
rethink_running=0

for line in $@; do
  eval "$line"
done

version=${tag#?}

if [ -z "$version" ]; then
  # Get last git tag as release version. Tag looks like 'v.1.2.3', so strip 'v'.
  version=`git describe --tags`
  version=${version#?}
fi

echo "Releasing $version"

GOSRC=${GOPATH}/src/github.com/mudphilo

install() {

    echo -n "installing $DAEMON"

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
                rethinkdb --bind all --daemon > $LOGFILE 2>&1
        fi
    }

    pushd ${GOSRC}/chat > $LOGFILE 2>&1

    # Prepare directory for the new release
    rm -fR ./releases/${version}
    mkdir ./releases/${version}

    for plat in "${goplat[@]}"
    do
      for arc in "${goarc[@]}"
      do
        # Keygen is database-independent
        # Remove previous build
        rm -f $GOPATH/bin/keygen
        # Build
        ~/go/bin/gox -osarch="${plat}/${arc}" -ldflags "-s -w" -output $GOPATH/bin/keygen ./keygen > $LOGFILE 2>&1

        for dbtag in "${dbtags[@]}"
        do
          echo "Building ${dbtag}-${plat}/${arc}..."

          # Remove previous builds
          rm -f $GOPATH/bin/tinode
          rm -f $GOPATH/bin/init-db
          # Build tinode server and database initializer for RethinkDb and MySQL.
          ~/go/bin/gox -osarch="${plat}/${arc}" \
            -ldflags "-s -w -X main.buildstamp=`git describe --tags`" \
            -tags ${dbtag} -output $GOPATH/bin/tinode ./server > $LOGFILE 2>&1
          ~/go/bin/gox -osarch="${plat}/${arc}" \
            -ldflags "-s -w" \
            -tags ${dbtag} -output $GOPATH/bin/init-db ./tinode-db > $LOGFILE 2>&1
          # Tar on Mac is inflexible about directories. Let's just copy release files to
          # one directory.
          rm -fR ./releases/tmp
          mkdir -p ./releases/tmp/static

          # Copy templates and database initialization files
          cp ./server/tinode.conf ./releases/tmp
          cp -R ./server/templ ./releases/tmp
          cp -R ./server/static/img ./releases/tmp/static
          cp -R ./server/static/audio ./releases/tmp/static
          cp -R ./server/static/css ./releases/tmp/static
          cp ./server/static/index.html ./releases/tmp/static
          cp ./server/static/tinode.js ./releases/tmp/static
          cp ./server/static/drafty.js ./releases/tmp/static
          cp ./tinode-db/data.json ./releases/tmp
          cp ./tinode-db/*.jpg ./releases/tmp
          cp ./tinode-db/credentials.sh ./releases/tmp

          # Build archive. All platforms but Windows use tar for archiving. Windows uses zip.
          if [ "$plat" = "windows" ]; then
            # Copy binaries
            cp $GOPATH/bin/tinode.exe ./releases/tmp
            cp $GOPATH/bin/init-db.exe ./releases/tmp
            cp $GOPATH/bin/keygen.exe ./releases/tmp

            # Remove possibly existing archive.
            rm -f ./releases/${version}/tinode-${dbtag}."${plat}-${arc}".zip
            # Generate a new one
            pushd ./releases/tmp > $LOGFILE 2>&1
            zip -q -r ../${version}/tinode-${dbtag}."${plat}-${arc}".zip ./*
            popd > /dev/null
          else
            plat2=$plat
            # Rename 'darwin' tp 'mac'
            if [ "$plat" = "darwin" ]; then
              plat2=mac
            fi
            # Copy binaries
            cp $GOPATH/bin/tinode ./releases/tmp
            cp $GOPATH/bin/init-db ./releases/tmp
            cp $GOPATH/bin/keygen ./releases/tmp

            # Remove possibly existing archive.
            rm -f ./releases/${version}/tinode-${dbtag}."${plat2}-${arc}".tar.gz
            # Generate a new one
            tar -C ${GOSRC}/chat/releases/tmp -zcf ./releases/${version}/tinode-${dbtag}."${plat2}-${arc}".tar.gz .
          fi
        done
      done
    done

    # Need to rebuild lthe inux-rethink binary without stripping debug info.
    echo "Building the binary for the demo at api.tinode.co"

    rm -f $GOPATH/bin/tinode
    rm -f $GOPATH/bin/init-db

    ~/go/bin/gox -osarch=linux/amd64 \
      -ldflags "-X main.buildstamp=`git describe --tags`" \
      -tags rethinkdb -output $GOPATH/bin/tinode ./server > $LOGFILE 2>&1
    ~/go/bin/gox -osarch=linux/amd64 \
      -tags rethinkdb -output $GOPATH/bin/init-db ./tinode-db > $LOGFILE 2>&1


    # Build chatbot release
    echo "Building chatbot..."

    rm -fR ./releases/tmp
    mkdir -p ./releases/tmp

    cp ${GOSRC}/chat/chatbot/chatbot.py ./releases/tmp
    cp ${GOSRC}/chat/chatbot/quotes.txt ./releases/tmp
    cp ${GOSRC}/chat/pbx/model_pb2.py ./releases/tmp
    cp ${GOSRC}/chat/pbx/model_pb2_grpc.py ./releases/tmp

    tar -C ${GOSRC}/chat/releases/tmp -zcf ./releases/${version}/chatbot.tar.gz .
    pushd ./releases/tmp > $LOGFILE 2>&1
    zip -q -r ../${version}/chatbot.zip ./*
    popd > $LOGFILE 2>&1

    # Clean up temporary files
    rm -fR ./releases/tmp

    popd > $LOGFILE 2>&1
}

stop() {
    killall $DAEMON
}

status() {
    killall -0 $DAEMON

    if [ "$?" -eq 0 ]; then
        echo "Running."
    else
        echo "Not Running."
    fi
}

start() {
    echo -n "starting up $DAEMON"
    echo -n "starting db"

    RUN=`cd / && $DB_DAEMON --config=$DB_CONFIG --data=$DB_DATA > $LOGFILE 2>&1`

    if [ "$?" -eq 0 ]; then
        echo "Done."
    else
        echo "FAILED."
    fi
}

case "$1" in
    start)
    start
    ;;

    restart)
    stop
    sleep 2
    start
    ;;

    stop)
    stop
    ;;

    status)
    status
    ;;

    *)
    echo "usage : $0 start|restart|stop|status"
    ;;
esac

exit 0
