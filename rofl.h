/******
 * runrofl.h
 ******/

#ifndef ROFL_H
#define ROFL_H

#include <fstream>
#include <iostream>
#include <sstream>
#include <zlib.h>

#include "common.h"
#include "camperror.h"

#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

// in runrofl.in, add function nullSocket (see builtin.cc)

#define BUFSIZE 1024

namespace camp {

    class TcpServer : public gc {
        public:
            int fd;

            struct sockaddr_in addr;
    };
    class TcpSocket : public gc {
        public:
            int fd;
            char buf[BUFSIZE + 1 /*for null terminator*/] = {0};
            int nread = 0;
            struct sockaddr_in addr;
    };

    void print(string s);
    TcpSocket *server_accept(TcpServer *s);
    int server_close(TcpServer *s);
    string socket_read(TcpSocket *s);
    int socket_write(TcpSocket *s, string d);
    int socket_close(TcpSocket *s);
    TcpServer *create_server(string host, Int port);

    inline TcpServer *create_server(string host, Int port) {
        int opt = 1;
        TcpServer *server = new TcpServer();
        server->addr.sin_family = AF_INET;
        // server->addr.sin_addr.s_addr = INADDR_ANY;
        server->addr.sin_addr.s_addr = inet_addr(host.c_str());
        server->addr.sin_port = htons(port);

        if ((server->fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
            perror("socket failed");
            exit(EXIT_FAILURE);
        }

        if (setsockopt(server->fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt,
                    sizeof(opt))) {
            perror("setsockopt");
            exit(EXIT_FAILURE);
        }

        if (bind(server->fd, (struct sockaddr *)&server->addr, sizeof(server->addr)) < 0) {
            perror("bind failed");
            exit(EXIT_FAILURE);
        }
        if (listen(server->fd, 3) < 0) {
            perror("listen");
            exit(EXIT_FAILURE);
        }
        return server;
    }

    inline TcpSocket *server_accept(TcpServer *s) {
        TcpSocket *client_socket = new TcpSocket();
        socklen_t addr_len = sizeof(s->addr);

        if ((client_socket->fd = accept(s->fd, (struct sockaddr *)&client_socket->addr, &addr_len)) < 0) {
            perror("accept");
            exit(EXIT_FAILURE);
        }
        return client_socket;
    }
    inline int server_close(TcpServer *s) { 
        if (s && s->fd >= 0) close(s->fd);
        s->fd = -1;
        return 0;
    }

    inline string socket_read(TcpSocket *s) {
        string request = "";
        char buf[BUFSIZE + 1];
        int n = read(s->fd, buf, BUFSIZE - 1);
        if (n > 0) {
            buf[n] = '\0';
            string data(buf, n);
            request.append(data);
        } else if (n == 0) {
            // eof
        } else  if (n < 0) {
            // error
        }
        return request;

        // int ntotal = 0;
        // while ((s->nread = read(s->client_socket_fd, s->buf, BUFSIZE - 1)) > 0) {
        //   ntotal += s->nread;
        //   s->buf[s->nread] = '\0';
        //   string req(s->buf, s->nread);
        //   printf("%s\n", s->buf);
        //   s->request.append(req);
        //   printf("echo\n");
        //   write_socket(s, req);
        // }
        // close(s->client_socket_fd);
        // s->client_socket_fd = 0;
        // return s->request;
    }

    inline int socket_write(TcpSocket *s, string data) {
        return send(s->fd, data.c_str(), data.length(), 0);
    }

    inline int socket_close(TcpSocket *s) { 
        if (s && s->fd >= 0) close(s->fd);
        s->fd = -1;
        return 0;
    }

} // namespace camp
#endif
