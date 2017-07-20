//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include <cryptopp/md5.h>
#include "miner/common.h"
#include "miner/MinerScanner.h"
#include "miner/MinerConfigurator.h"

using namespace std;
using namespace btctools::miner;
using namespace CryptoPP;

int main(int argc, char* argv[])
{
    try
    {
		MinerYield minerYield([](MinerSource &minerSource)
		{
			MinerConfigurator config(minerSource, 2);

			auto source = config.run(0);

			for (auto miner : source)
			{
				cout << miner.ip_ << "\t\t|" << miner.stat_ << "|\t\t" << miner.fullTypeStr_ << "\t\t" << miner.pool1_.url_ << "\t\t" << miner.pool1_.worker_ << endl;
			}
		});

		for (int i = 0; i < 1; i++)
		{
			Miner *miner = new Miner;
			miner->ip_ = "192.168.21.35";
			miner->fullTypeStr_ = "Antminer S9";
			miner->typeStr_ = "antminer-s9";
			miner->pool1_.url_ = "eu.ss.btc.com:3333";
			miner->pool1_.worker_ = "eu001.bj_office_s9";
			miner->pool1_.passwd_ = "p1";
			miner->pool2_.worker_ = "test2";

			minerYield(*miner);
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

    system("pause");

    return 0;
}
