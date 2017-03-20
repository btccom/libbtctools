#pragma once

#include "ConfiguratorHelper.h"
#include "../utils/OOLuaExport.h"

using namespace std;
using namespace btctools::miner;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		ConfiguratorHelper::ConfiguratorHelper()
		{
			OOLuaExport::exportAll(script_);

			bool success = script_.run_file("./lua/scripts/ConfiguratorHelper.lua");

			if (!success)
			{
				throw runtime_error(OOLUA::get_last_error(script_));
			}
		}

		void ConfiguratorHelper::makeRequest(WorkContext *context)
		{
			script_.call("makeRequest", context);
		}

		void ConfiguratorHelper::makeResult(WorkContext *context, btctools::tcpclient::Response *response)
		{
			string stat;

			switch (response->error_code_.value())
			{
			case boost::asio::error::timed_out:
				stat = "timeout";
				break;
			case boost::asio::error::connection_refused:
				stat = "refused";
				break;
			case boost::asio::error::eof:
				stat = "success";
				break;
			default:
				stat = "unknown";
				break;
			}

			script_.call("makeResult", context, response->content_, stat);
		}

	} // namespace tcpclient
} // namespace btctools