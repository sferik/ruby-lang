/************************************************

  tcpserver.c -

  created at: Thu Mar 31 12:21:29 JST 1994

  Copyright (C) 1993-2007 Yukihiro Matsumoto

************************************************/

#include "rubysocket.h"

/*
 * call-seq:
 *   TCPServer.new([hostname,] port) => tcpserver
 *
 * Creates a new server socket bound to _port_.
 *
 * If _hostname_ is given, the socket is bound to it.
 *
 *   serv = TCPServer.new("127.0.0.1", 28561)
 *   s = serv.accept
 *   s.puts Time.now
 *   s.close
 *
 * Internally, TCPServer.new calls getaddrinfo() function to
 * obtain addresses.
 * If getaddrinfo() returns multiple addresses,
 * TCPServer.new tries to create a server socket for each address
 * and returns first one that is successful.
 *
 */
static VALUE
tcp_svr_init(int argc, VALUE *argv, VALUE sock)
{
    VALUE hostname, port;

    rb_scan_args(argc, argv, "011", &hostname, &port);
    return rsock_init_inetsock(sock, hostname, port, Qnil, Qnil, INET_SERVER, Qnil, Qnil, Qnil, Qfalse, Qnil);
}

/*
 * call-seq:
 *   tcpserver.accept => tcpsocket
 *
 * Accepts an incoming connection. It returns a new TCPSocket object.
 *
 *   TCPServer.open("127.0.0.1", 14641) {|serv|
 *     s = serv.accept
 *     s.puts Time.now
 *     s.close
 *   }
 *
 */
static VALUE
tcp_accept(VALUE server)
{
    union_sockaddr buffer;
    socklen_t length = sizeof(buffer);

    return rsock_s_accept(rb_cTCPSocket, server, &buffer.addr, &length);
}

/* :nodoc: */
static VALUE
tcp_accept_nonblock(VALUE sock, VALUE ex)
{
    rb_io_t *fptr;
    union_sockaddr from;
    socklen_t len = (socklen_t)sizeof(from);

    GetOpenFile(sock, fptr);
    return rsock_s_accept_nonblock(rb_cTCPSocket, ex, fptr, &from.addr, &len);
}

/*
 * call-seq:
 *   tcpserver.sysaccept => file_descriptor
 *
 * Returns a file descriptor of a accepted connection.
 *
 *   TCPServer.open("127.0.0.1", 28561) {|serv|
 *     fd = serv.sysaccept
 *     s = IO.for_fd(fd)
 *     s.puts Time.now
 *     s.close
 *   }
 *
 */
static VALUE
tcp_sysaccept(VALUE server)
{
    union_sockaddr buffer;
    socklen_t length = sizeof(buffer);

    return rsock_s_accept(0, server, &buffer.addr, &length);
}

void
rsock_init_tcpserver(void)
{
    /*
     * Document-class: TCPServer < TCPSocket
     *
     * TCPServer represents a TCP/IP server socket.
     *
     * A simple TCP server may look like:
     *
     *   require 'socket'
     *
     *   server = TCPServer.new 2000 # Server bind to port 2000
     *   loop do
     *     client = server.accept    # Wait for a client to connect
     *     client.puts "Hello !"
     *     client.puts "Time is #{Time.now}"
     *     client.close
     *   end
     *
     * A more usable server (serving multiple clients):
     *
     *   require 'socket'
     *
     *   server = TCPServer.new 2000
     *   loop do
     *     Thread.start(server.accept) do |client|
     *       client.puts "Hello !"
     *       client.puts "Time is #{Time.now}"
     *       client.close
     *     end
     *   end
     *
     */
    rb_cTCPServer = rb_define_class("TCPServer", rb_cTCPSocket);
    rb_define_method(rb_cTCPServer, "accept", tcp_accept, 0);
    rb_define_private_method(rb_cTCPServer,
                             "__accept_nonblock", tcp_accept_nonblock, 1);
    rb_define_method(rb_cTCPServer, "sysaccept", tcp_sysaccept, 0);
    rb_define_method(rb_cTCPServer, "initialize", tcp_svr_init, -1);
    rb_define_method(rb_cTCPServer, "listen", rsock_sock_listen, 1); /* in socket.c */
}
