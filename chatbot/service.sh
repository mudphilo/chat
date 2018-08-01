#!/bin/sh

### BEGIN INIT INFO
# Provides:          chatbot
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Script to run chatbot as a service
### END INIT INFO

SCRIPT_NAME="/go/src/github.com/mudphilo/chat/chatbot/chatbot.py"
QUOTES="/go/src/github.com/mudphilo/chat/chatbot/quotes.txt"
RUNAS=root
NAME="chatbot"

PIDFILE="/var/run/$NAME.pid"
LOGFILE="/var/log/$NAME/daemon.log"

start() {
  if [ -f $PIDFILE ] && [ -s $PIDFILE ] && kill -0 $(cat $PIDFILE); then
    echo 'Service already running' >&2
    return 1
  fi
  echo 'Starting service?~@?' >&2

  CREDENTIALS="/go/src/github.com/mudphilo/chat/chatbot/cookie.ini"

  echo "loading ticktick library"
  . $CREDENTIALS

  echo "got secret $secret and schema $schema"

  SCRIPT="python3.6 $SCRIPT_NAME --login-$schema=$secret --quotes=$QUOTES"

  echo "$SCRIPT"

  local CMD="$SCRIPT &> \"$LOGFILE\" & echo \$!"
  su -c "$CMD" $RUNAS > "$PIDFILE"
 # Try with this command line instead of above if not workable
 # su -s /bin/sh $RUNAS -c "$CMD" > "$PIDFILE"
  sleep 2
  PID=$(cat $PIDFILE)
    if pgrep -u $RUNAS -f $NAME > /dev/null
    then
      echo "$NAME is now running, the PID is $PID"
    else
      echo ''
      echo "Error! Could not start $NAME!"
    fi
}

stop() {
  if [ ! -f "$PIDFILE" ] || ! kill -0 $(cat "$PIDFILE"); then
    echo 'Service not running' >&2
    return 1
  fi
  echo 'Stopping service?~@?' >&2
  kill -15 $(cat "$PIDFILE") && rm -f "$PIDFILE"
  echo 'Service stopped' >&2
}

uninstall() {
  echo -n "Are you really sure you want to uninstall this service? That cannot be undone. [yes|No] "
  local SURE
  read SURE
  if [ "$SURE" = "yes" ]; then
    stop
    rm -f "$PIDFILE"
    echo "Notice: log file was not removed: $LOGFILE" >&2
    update-rc.d -f $NAME remove
    rm -fv "$0"
  else
    echo "Abort!"
  fi
}


status() {
    printf "%-50s" "Checking $NAME ..."
    if [ -f $PIDFILE ] && [ -s $PIDFILE ]; then
        PID=$(cat $PIDFILE)
            if [ -z "$(ps axf | grep ${PID} | grep -v grep)" ]; then
                printf "%s\n" "The process appears to be dead but pidfile still exists"
            else
                echo "Running, the PID is $PID"
            fi
    else
        printf "%s\n" "Service not running"
    fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  uninstall)
    uninstall
    ;;
  restart)
    stop
    start
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart|uninstall}"
esac