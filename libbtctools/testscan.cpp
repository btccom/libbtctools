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
#include "utils/IpGenerator.hpp"
#include <windows.h>

using namespace std;
using namespace btctools::tcpclient;
using namespace btctools::utils;

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

			StringConsumer ipSource(
				[](StringProductor &ipYield)
			{
				IpGenerator::genIpRange("192.168.21.1", "192.168.21.254", ipYield);
			});

			for (auto ip : ipSource)
			{
				cout << ip << endl;

				Request *req = new Request(ip, "4028", "{\"command\":\"summary\"}");
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
