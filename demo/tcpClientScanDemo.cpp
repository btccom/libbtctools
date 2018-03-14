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

void setNextWork(IpGenerator &ips, Request *req, Client &client)
{
	static int counter = 0;

	if (ips.hasNext())
	{
		req->host_ = ips.next();

		//cout << "New Work: " << req->host_ << endl;

		client.addWork(req);

		if (counter++ % 100 == 0)
		{
			cout << counter << ": " << req->host_ << endl;
		}
	}
	else
	{
		delete req;
	}
}

void run(IpGenerator &ips, int sessionTimeout, int stepSize)
{
	RequestSource requestSource([&ips, &stepSize](RequestYield &requestYield)
	{
		IpStrSource ipSource = ips.genIpRange(stepSize);

		for (auto ip : ipSource)
		{
			//cout << ip << endl;

			// use CGMiner RPC: https://github.com/ckolivas/cgminer/blob/master/API-README
			// the response of JSON styled calling {"command":"stats"} will responsed
			// a invalid JSON string from Antminer S9, so call with plain text style.
			Request *req = new Request;
			req->host_ = ip;
			req->port_ = "4028";
			req->content_ = "stats|";
			req->usrdata_ = req;
			req->session_timeout_ = 3;
			req->delay_timeout_ = 0;

			requestYield(req);
		}
	});

	Client client;
	ResponseSource responseSource = client.run(requestSource);

	for (auto response : responseSource)
	{
		Request *request = (Request *)response->usrdata_;

		if (response->error_code_ == boost::asio::error::eof)
		{
			//cout << "Response: " << response->content_ << endl;

			string minerType = "Unknown";

			// Only Antminer has the field.
			boost::regex expression(",Type=([^\\|]+)\\|");
			boost::smatch what;

			if (boost::regex_search(response->content_, what, expression))
			{
				minerType = what[1];

				cout << request->host_ << ": " << minerType << endl;

				request->content_ = "pools|";
				client.addWork(request);
			}
			else
			{
				cout << request->host_ << ": " << minerType << endl;

				setNextWork(ips, request, client);
			}
		}
		else
		{
			//cout << request->host_ << ": " << boost::system::system_error(response->error_code_).what() << endl;

			setNextWork(ips, request, client);
		}

		delete response;
	}
}

int main(int argc, char* argv[])
{
	try
	{
		IpGenerator ips("192.168.200.0-192.168.255.255");
		run(ips, 1, 50);
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
