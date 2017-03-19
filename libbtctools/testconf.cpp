//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include <cryptopp/md5.h>
#include "miner/all.hpp"

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

			auto source = config.run(1);

			for (auto miner : source)
			{
				cout << miner.ip_ << "\t\t" << miner.stat_ << "\t\t" << miner.fullTypeStr_ << "\t\t" << miner.pool1_.url_ << "\t\t" << miner.pool1_.worker_ << endl;
			}
		});

		for (int i = 0; i < 10; i++)
		{
			Miner *miner = new Miner;
			miner->ip_ = "127.0.0.1";
			miner->fullTypeStr_ = "test";
			miner->typeStr_ = "test";
			miner->pool1_.url_ = "127.0.0.1:3333";
			miner->pool1_.worker_ = "test.t1";

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
