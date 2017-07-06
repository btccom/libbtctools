#pragma once

#include "ScriptLoader.h"
#include "../utils/OOLuaHelper.h"

using namespace std;
using namespace btctools::miner;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		ScriptLoader::ScriptLoader(string scriptName)
		{
			OOLuaHelper::exportAll(script_);

			bool success = OOLuaHelper::runFile(script_, scriptName);

			if (!success)
			{
				throw runtime_error(OOLUA::get_last_error(script_));
			}
		}

		void ScriptLoader::makeRequest(WorkContext *context)
		{
			script_.call("makeRequest", context);
		}

		void ScriptLoader::makeResult(WorkContext *context, btctools::tcpclient::Response *response)
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