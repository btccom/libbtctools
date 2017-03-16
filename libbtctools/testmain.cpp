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
		MinerScanner scanner("192.168.21.35-192.168.21.35", 256);

		ScanResultConsumer source([&](ScanResultProductor &yield)
		{
			scanner.run(yield, 1);
		});

		for (auto result : source)
		{
			cout << result->miner_.ip_ << ": ok" << endl;
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
