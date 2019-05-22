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
#include "utils/Crypto.h"

using namespace std;
using namespace btctools::miner;
using namespace btctools::utils;

int main(int argc, char* argv[])
{
    try
    {
		// Set miner passwords
		// Format:
		// "<miner-model-base64>:<user-base64>:<pwd-base64>&<miner-model-base64>:<user-base64>:<pwd-base64>&..."
        btctools::utils::OOLuaHelper::setOpt("login.minerPasswords", Crypto::base64Encode("Antminer S9") + ":" +
                                                                     Crypto::base64Encode("root") + ":" +
                                                                     Crypto::base64Encode("root"));

        // set miner model
        btctools::utils::OOLuaHelper::setOpt("upgrader.minerModel", "Antminer S9");

        // set firmware
        btctools::utils::OOLuaHelper::setOpt("upgrader.firmwareName", "./firmware.tar.gz");

        // set keep settings
        // "1" or "0"
        btctools::utils::OOLuaHelper::setOpt("upgrader.keepSettings", "1");

		MinerSource minerSource([](MinerYield &minerYield)
		{
			for (int i = 3; i < 5; i++)
			{
				string iStr = std::to_string(i);

				Miner *miner = new Miner;

				// The following information can be obtained through the scanning process.
				// Manually filled here as a demo.
				miner->ip_ = string("10.0.1.") + iStr;
				miner->fullTypeStr_ = "Antminer S9";
				miner->typeStr_ = "antminer-http-cgi";

				minerYield(*miner);
			}
			
		});

		OOLuaHelper::setPackagePath("./lua/scripts");

		// We implement upgrading miners as another type of configuring miners.
		// It is the same as configuring miners, except that RebooterHelper.lua is loaded
		// instead of the default ConfiguratorHelper.lua
		MinerConfigurator config(minerSource, 10, "UpgraderHelper");

		auto source = config.run(3);

		for (auto miner : source)
		{
			cout << miner.ip_ << "\t\t|" << miner.stat_ << endl;
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
