//
// echo_server.cpp
// ~~~~~~~~~~~~~~~
//
// Copyright (c) 2003-2016 Christopher M. Kohlhoff (chris at kohlhoff dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//

#include <iostream>

#include "utils/OOLuaHelper.h"
#include "miner/MinerScanner.h"
#include "utils/IpGenerator.h"

using namespace std;

int main(int argc, char* argv[])
{
    try
    {
		// scan a network range
		// fetch results by while()
		{
			// set script loading dir
			btctools::utils::OOLuaHelper::setPackagePath("./lua/scripts");

			// Set miner passwords (optional if miner has default password)
			// Since the miner type cannot be determined before the scan, 
			// you need provide username and password per miner-type.
			// Format of the data:
			//     minerType1:username:password&minerType2:username:password&...
			// You can change the format at utils.parseLoginPasswords() in src/lua/scripts/utils.lua
        	btctools::utils::OOLuaHelper::setOpt("login.minerPasswords", "AntMiner:root:root&Avalon:root:");

			btctools::utils::IpGenerator ips("192.168.200.0-192.168.201.255");
			auto ipRange = ips.genIpRange();
			btctools::miner::MinerScanner scanner(ipRange, 200); // concurrent connections: 200

			auto source = scanner.run(1); // timeout: 1s

			// fetch results by while()
			while(source())
			{
				auto miner = source.get();

				// miner.opt("key") provides data defined by the scan script.
				// Lookup miner:setOpt() calling in src/lua/scripts/minerScanner/*.lua to find more datas.
				cout << miner.ip_ << "\t" << miner.stat_ << "\t" << miner.typeStr_ << "\t" << miner.fullTypeStr_ << "\t"
				     << miner.opt("hashrate_avg") << "\t" << miner.opt("temperature") << "\t"
					 << miner.pool1_.url_ << "\t" << miner.pool1_.worker_ << endl;
			}
		}

		// scan the other network range
		// fetch results by range-based for()
		{
			btctools::utils::OOLuaHelper::setPackagePath("./lua/scripts");

			btctools::utils::IpGenerator ips("192.168.0.100-192.168.1.200");
			auto ipRange = ips.genIpRange();
			btctools::miner::MinerScanner scanner(ipRange, 100); // concurrent connections: 100

			auto source = scanner.run(3); // timeout: 3s

			for (auto miner : source)
			{
				cout << miner.ip_ << "\t" << miner.opt("a") << "\t" << miner.stat_ << "\t" << miner.typeStr_ << "\t" << miner.fullTypeStr_ << "\t" << miner.pool1_.url_ << "\t" << miner.pool1_.worker_ << endl;
			}
		}

		// scan more than one network range
		{
			btctools::utils::OOLuaHelper::setPackagePath("./lua/scripts");

			btctools::utils::IpGeneratorGroup ips;
			ips.addIpRange("192.168.3.100"); // single IP
			ips.addIpRange("192.168.10.1-80"); // range type 1
			ips.addIpRange("10.0.0.1-1.3"); // range type 2
			ips.addIpRange("10.0.3.3-10.0.5.9"); // full ip range

			auto ipRange = ips.genIpRange();
			btctools::miner::MinerScanner scanner(ipRange, 250); // concurrent connections: 250

			auto source = scanner.run(3); // timeout: 3s

			for (auto miner : source)
			{
				cout << miner.ip_ << "\t" << miner.opt("a") << "\t" << miner.stat_ << "\t" << miner.typeStr_ << "\t" << miner.fullTypeStr_ << "\t" << miner.pool1_.url_ << "\t" << miner.pool1_.worker_ << endl;
			}
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
