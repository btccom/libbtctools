//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include <string>

#include "utils/OOLuaHelper.h"
#include "miner/MinerConfigurator.h"
#include "utils/IpGenerator.h"

using namespace std;
using namespace btctools::miner;
using namespace btctools::utils;

int main(int argc, char* argv[])
{
    try
    {
		MinerSource minerSource([](MinerYield &minerYield)
		{
			for (int i = 35; i < 60; i++)
			{
				string iStr = std::to_string(i);

				Miner *miner = new Miner;

				// The following information can be obtained through the scanning process.
				// Manually filled here as a demo.
				miner->ip_ = string("192.168.21.") + iStr;
				miner->fullTypeStr_ = "Antminer S9";
				miner->typeStr_ = "antminer-http-cgi";

				// The following information is customized by you.
				// If you do not want to change a value, copy the value from
				// the scan result, otherwise the value will be empty.
				miner->pool1_.url_ = "eu.ss.btc.com:3333";
				miner->pool1_.worker_ = string("eu001.21x") + iStr;
				miner->pool1_.passwd_ = "123";

				miner->pool2_.url_ = "eu.ss.btc.com:443";
				miner->pool2_.worker_ = "test2";
				miner->pool2_.passwd_ = "123";

				miner->pool3_.url_ = "us.ss.btc.com:1800";
				miner->pool3_.worker_ = "test3";
				miner->pool3_.passwd_ = "123";

				minerYield(*miner);
			}
			
		});

		OOLuaHelper::setPackagePath("./lua/scripts");
		MinerConfigurator config(minerSource, 10); // configure 10 miners at the same time

		auto source = config.run(3);

		for (auto miner : source)
		{
			cout << miner.ip_ << "\t\t|" << miner.stat_ << "|\t\t" << miner.fullTypeStr_ << "\t\t" << miner.pool1_.url_ << "\t\t" << miner.pool1_.worker_ << endl;
		}

    }
    catch (std::exception& e)
    {
        std::cerr << "Exception: " << e.what() << "\n";
    }
	catch (...)
	{
		cerr << "Unknown error!" << endl;
	}

    std::cout << "\nDone" << std::endl;

#ifdef _WIN32
	::system("pause");
#endif

    return 0;
}
