#pragma once

#include <map>
#include <sstream>
#include <string>

#include "all.hpp"
#include "../lua/oolua/oolua.h"

using namespace std;
using namespace btctools::miner;

OOLUA_PROXY(Pool)
	OOLUA_MFUNC(url)
	OOLUA_MFUNC(worker)
	OOLUA_MFUNC(passwd)
	OOLUA_MFUNC(setUrl)
	OOLUA_MFUNC(setWorker)
	OOLUA_MFUNC(setPasswd)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(Pool, url, worker, passwd, setUrl, setWorker, setPasswd)
OOLUA_EXPORT_FUNCTIONS_CONST(Pool)

OOLUA_PROXY(Miner)
	OOLUA_MFUNC(ip)
	OOLUA_MFUNC(stat)
	OOLUA_MFUNC(type)
	OOLUA_MFUNC(fullTypeStr)
	OOLUA_MFUNC(pool1)
	OOLUA_MFUNC(pool2)
	OOLUA_MFUNC(pool3)
	OOLUA_MFUNC(setIp)
	OOLUA_MFUNC(setStat)
	OOLUA_MFUNC(setType)
	OOLUA_MFUNC(setFullTypeStr)
	OOLUA_MFUNC(setPool1)
	OOLUA_MFUNC(setPool2)
	OOLUA_MFUNC(setPool3)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(Miner, ip, stat, type, fullTypeStr, pool1, pool2, pool3,
			setIp, setStat, setType, setFullTypeStr, setPool1, setPool2, setPool3)
OOLUA_EXPORT_FUNCTIONS_CONST(Miner)

OOLUA_PROXY(ScanContext)
	OOLUA_MFUNC(stepName)
	OOLUA_MFUNC(miner)
	OOLUA_MFUNC(canYield)
	OOLUA_MFUNC(requestHost)
	OOLUA_MFUNC(requestPort)
	OOLUA_MFUNC(requestContent)
	OOLUA_MFUNC(setStepName)
	OOLUA_MFUNC(setMiner)
	OOLUA_MFUNC(setCanYield)
	OOLUA_MFUNC(setRequestHost)
	OOLUA_MFUNC(setRequestPort)
	OOLUA_MFUNC(setRequestContent)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(ScanContext, stepName, miner, canYield, requestHost, requestPort, requestContent,
	setStepName, setMiner, setCanYield, setRequestHost, setRequestPort, setRequestContent)
OOLUA_EXPORT_FUNCTIONS_CONST(ScanContext)

namespace btctools
{
	namespace miner
	{
		class ScannerHelper
		{
		public:
			ScannerHelper()
			{
				script_.register_class<Pool>();
				script_.register_class<Miner>();
				script_.register_class<ScanContext>();

				bool success = script_.run_file("./lua/scripts/ScannerHelper.lua");

				if (!success)
				{
					throw runtime_error(OOLUA::get_last_error(script_));
				}
			}

			void makeRequest(ScanContext *context)
			{
				script_.call("makeRequest", context);
			}

			void makeResult(ScanContext *context, btctools::tcpclient::Response *response)
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

		private:
			OOLUA::Script script_;
		};

	} // namespace tcpclient
} // namespace btctools