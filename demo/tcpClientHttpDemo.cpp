//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include "tcpclient/Session.h"
#include "tcpclient/Client.h"
#include "utils/IpGenerator.h"
#include <boost/regex.hpp>
#include <windows.h>

using namespace std;
using namespace btctools::tcpclient;
using namespace btctools::utils;


int main(int argc, char* argv[])
{
	try
	{
		Client c;
		
		auto responseSource = c.run(RequestSource([](RequestYield &requestYield)
		{
			{
				Request *req = new Request;
				req->host_ = "tls://chain.api.btc.com";
				req->port_ = "443";
				req->content_ = "GET /v3/block/latest HTTP/1.0\r\nHost: chain.api.btc.com\r\n\r\n";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}

			{
				Request *req = new Request;
				req->host_ = "ssl://chain.api.btc.com";
				req->port_ = "443";
				req->content_ = "GET /v3/block/latest HTTP/1.0\r\nHost: chain.api.btc.com\r\n\r\n";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}

			{
				Request *req = new Request;
				req->host_ = "tcp://chain.api.btc.com";
				req->port_ = "80";
				req->content_ = "GET /v3/block/latest HTTP/1.0\r\nHost: chain.api.btc.com\r\n\r\n";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}

			{
				Request *req = new Request;
				req->host_ = "chain.api.btc.com";
				req->port_ = "80";
				req->content_ = "GET /v3/block/latest HTTP/1.0\r\nHost: chain.api.btc.com\r\n\r\n";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}
		}));

		for (auto response : responseSource)
		{
			Request *request = (Request *)response->usrdata_;

			if (response->error_code_ == boost::asio::error::eof)
			{
				cout << "Host: " << request->host_ << endl;
				cout << "---------" << endl;
				cout << "Request:" << endl;
				cout << "---------" << endl;
				cout << request->content_ << endl;
				cout << "---------" << endl;
				cout << "Response: " << endl;
				cout << "---------" << endl; 
				cout << response->content_ << endl;
				cout << endl << "---------------------------------------------------------------" << endl << endl;
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
