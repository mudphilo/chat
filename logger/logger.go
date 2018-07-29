package logger

import (
	"flag"
	"os"
	"log"
)

var (
	Log      *log.Logger
)


func init() {

	var logpath = "/var/log/tinode/info.log"
	flag.Parse()

	var file, err1 = os.Create(logpath)

	if err1 != nil {
		panic(err1)
	}

	Log = log.New(file, "", log.LstdFlags|log.Lshortfile)
	Log.Println("LogFile : " + logpath)

}