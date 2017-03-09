//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include "tcpclient/all.hpp"
#include <windows.h>

using namespace std;
using namespace btctools::tcpclient;

int main(int argc, char* argv[])
{
    try
    {
        Client client;

        ResponseConsumer responseConsumer(
            [&](ResponseProductor & responseProductor)
        {
            RequestProductor requestProductor(
                [&](RequestConsumer &requestConsumer)
            {
                client.run(requestConsumer, responseProductor);
            });

            for (int i = 0; i < 5; i++)
            {
                Request *req = new Request("127.0.0.1", "80", "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUser-Agent: BTC Tools v0.0.1\r\nConnection: close\r\n\r\n");
				req->usrdata_ = req;

                requestProductor(req);
            }

			for (int i = 0; i < 50; i++)
			{
				Request *req = new Request("127.0.0.1", "81", "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nUser-Agent: BTC Tools v0.0.1\r\nConnection: close\r\n\r\n");
				req->usrdata_ = req;

				requestProductor(req);
			}
        });

        for (auto response : responseConsumer)
        {
            cout << "errc: " << response->error_code_.value() << endl;
			cout << "size: " << response->content_.size() << endl;

			Request *request = (Request *)response->usrdata_;
			delete request;
			delete response;
        }

    }
    catch (std::exception& e)
    {
        std::cerr << "Exception: " << e.what() << "\n";
    }

    std::cout << "\nDone" << std::endl;

    system("pause");

    return 0;
}
