//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include "miner/all.hpp"

using namespace std;
using namespace btctools::miner;

int main(int argc, char* argv[])
{
    try
    {
		auto ips = btctools::utils::IpGenerator("192.168.20.0-192.168.21.255");
		IpStrSource ipSource = ips.genIpRange();
		MinerScanner scanner(ipSource, 256);

		MinerSource source([&](MinerYield &yield)
		{
			scanner.run(yield, 1);
		});

		for (auto miner : source)
		{
			cout << miner.ip_ << "\t" << miner.stat_ << "\t" << miner.typeStr_ << "\t" << miner.fullTypeStr_ << "\t" << miner.pool1_.url_ << "\t" << miner.pool1_.worker_ << endl;
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
