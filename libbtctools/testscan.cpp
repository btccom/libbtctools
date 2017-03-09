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

			char ipBuffer[16];

			for (int i = 1; i < 255; i++)
			{
				sprintf(ipBuffer, "192.168.21.%d", i);
				Request *req = new Request(ipBuffer, "4028", "{\"command\":\"summary\"}");
				req->usrdata_ = req;

				requestProductor(req);
			}
		});

		for (auto response : responseConsumer)
		{
			Request *request = (Request *)response->usrdata_;

			if (response->error_code_ == boost::asio::error::eof)
			{
				cout << request->host_ << ": OK" /*<<  response->content_*/ << endl;
			}
			else
			{
				cout << request->host_ << ": " << boost::system::system_error(response->error_code_).what() << endl;
			}

			delete request;
			delete response;
		}

	}
	catch (std::exception& e)
	{
		std::cerr << "Exception: " << e.what() << "\n";
	}

	std::cout << "\nDone" << std::endl;

	::system("pause");

	return 0;
}
