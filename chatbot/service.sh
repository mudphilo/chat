#!/usr/bin/env bash

. /go/src/github.com/mudphilo/chat/chatbot/ticktick.sh

# File
DATA=`cat /go/src/github.com/mudphilo/chat/chatbot/cookie.json`

tickParse "$DATA"

if [ ``schema`` = "login" ]; then
  echo "schema is login"
fi

if [ ``schema`` = "token" ]; then
  echo "schema is login"
fi