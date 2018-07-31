#!/usr/bin/env bash

. /go/src/github.com/mudphilo/chat/chatbot/ticktick.sh

# File
DATA=`cat /go/src/github.com/mudphilo/chat/chatbot/cookie.json`

tickParse "$DATA"

schema=``schema``
secrete=``secret``

echo "$schema"

echo "$secret"