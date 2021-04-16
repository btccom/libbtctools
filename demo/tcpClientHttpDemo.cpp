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

#ifdef _WIN32
 #include <windows.h>
#endif

using namespace std;
using namespace btctools::tcpclient;
using namespace btctools::utils;


int main(int argc, char* argv[])
{
	try
	{
		RequestSource requestSource([](RequestYield &requestYield)
		{
			{
				Request *req = new Request;
				req->host_ = "tls://www.baidu.com";
				req->port_ = "443";
				req->content_ = "GET / HTTP/1.0\r\nHost: www.baidu.com\r\n\r\n";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}

			{
				Request *req = new Request;
				req->host_ = "ssl://www.bing.com";
				req->port_ = "443";
				req->content_ = "GET / HTTP/1.0\r\nHost: www.bing.com\r\n\r\n";
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

			{
				Request* req = new Request;
				req->host_ = "www.google.cn";
				req->port_ = "80";
				req->content_ = "POST / HTTP/1.0\r\nHost: www.google.cn\r\n\r\n123456789{file}987654321";
				req->fileUpload_ = true;
				req->replaceTag_ = "{file}";
				req->filePath_ = "./test.txt";
				req->usrdata_ = req;
				req->session_timeout_ = 15;
				req->delay_timeout_ = 0;

				requestYield(req);
			}
		});

		Client c;
		auto responseSource = c.run(requestSource);

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

#ifdef _WIN32
	::system("pause");
#endif

	return 0;
}
