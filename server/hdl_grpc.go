/******************************************************************************
 *
 *  Description :
 *
 *    Handler of gRPC connections. See also hdl_websock.go for websockets and
 *    hdl_longpoll.go for long polling.
 *
 *****************************************************************************/

package main

import (
	"io"
	"github.com/mudphilo/chat/logger"
	"net"

	"github.com/mudphilo/chat/pbx"
	"google.golang.org/grpc"
)

type grpcNodeServer struct {
}

func (sess *Session) closeGrpc() {
	if sess.proto == GRPC {
		sess.grpcnode = nil
	}
}

// Equivalent of starting a new session and a read loop in one
func (*grpcNodeServer) MessageLoop(stream pbx.Node_MessageLoopServer) error {
	sess := globals.sessionStore.Create(stream, "")

	defer func() {
		logger.Log.Println("grpc.MessageLoop - stop")
		sess.closeGrpc()
		sess.cleanUp()
	}()

	go sess.writeGrpcLoop()

	for sess.grpcnode != nil {
		in, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		logger.Log.Println(in.String())
		sess.dispatch(pbCliDeserialize(in))
	}

	return nil
}

func (sess *Session) writeGrpcLoop() {

	defer func() {
		sess.closeGrpc() // exit MessageLoop
	}()

	for {
		select {
		case msg, ok := <-sess.send:
			if !ok {
				// channel closed
				return
			}
			if err := grpcWrite(sess, msg); err != nil {
				logger.Log.Println("sess.writeLoop: " + err.Error())
				return
			}
		case msg := <-sess.stop:
			// Shutdown requested, don't care if the message is delivered
			if msg != nil {
				grpcWrite(sess, msg)
			}
			return

		case topic := <-sess.detach:
			sess.delSub(topic)
		}
	}
}

func grpcWrite(sess *Session, msg interface{}) error {
	out := sess.grpcnode
	if out != nil {
		// Will panic if format is wrong. This is an intentional panic.
		logger.Log.Println("grpc: writing message to stream", msg)
		return out.Send(msg.(*pbx.ServerMsg))
	}
	return nil
}

func serveGrpc(addr string) (*grpc.Server, error) {
	if addr == "" {
		return nil, nil
	}

	lis, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}

	srv := grpc.NewServer()
	pbx.RegisterNodeServer(srv, &grpcNodeServer{})
	logger.Log.Printf("gRPC server is registered at [%s]", addr)

	go func() {
		if err := srv.Serve(lis); err != nil {
			logger.Log.Println("gRPC server failed:", err)
		}
	}()

	return srv, nil
}
