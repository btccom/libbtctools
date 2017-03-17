#pragma once

#include <map>
#include <sstream>
#include <string>

#include "all.hpp"
#include "../lua/oolua/oolua.h"

using namespace std;
using namespace btctools::miner;

OOLUA_PROXY(Pool)
	OOLUA_MFUNC_CONST(getUrl)
	OOLUA_MFUNC_CONST(getWorker)
	OOLUA_MFUNC_CONST(getPasswd)
	OOLUA_MFUNC(setUrl)
	OOLUA_MFUNC(setWorker)
	OOLUA_MFUNC(setPasswd)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(Pool, setUrl, setWorker, setPasswd)
OOLUA_EXPORT_FUNCTIONS_CONST(Pool, getUrl, getWorker, getPasswd)

OOLUA_PROXY(Miner)
	OOLUA_MFUNC_CONST(getIp)
	OOLUA_MFUNC_CONST(getType)
	OOLUA_MFUNC_CONST(getFullTypeStr)
	OOLUA_MFUNC_CONST(getPool1)
	OOLUA_MFUNC_CONST(getPool2)
	OOLUA_MFUNC_CONST(getPool3)
	OOLUA_MFUNC(setIp)
	OOLUA_MFUNC(setType)
	OOLUA_MFUNC(setFullTypeStr)
	OOLUA_MFUNC(setPool1)
	OOLUA_MFUNC(setPool2)
	OOLUA_MFUNC(setPool3)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(Miner, setIp, setType, setFullTypeStr, setPool1, setPool2, setPool3)
OOLUA_EXPORT_FUNCTIONS_CONST(Miner, getIp, getType, getFullTypeStr, getPool1, getPool2, getPool3)

namespace btctools
{
	namespace miner
	{
		class DataParser
		{
		public:
			DataParser()
			{
				script_.register_class<Pool>();
				script_.register_class<Miner>();

				bool success = script_.run_file("./lua/scripts/DataParserHelper.lua");

				if (!success)
				{
					throw runtime_error(OOLUA::get_last_error(script_));
				}
			}

			void parseMinerStat(string jsonStr, Miner &miner)
			{
				script_.call("parseMinerStat", jsonStr, &miner);

				cout << miner.type_ << " / " << miner.fullTypeStr_ << endl;
			}

			void parseMinerPools(string jsonStr, Miner &miner)
			{
				script_.call("parseMinerStat", jsonStr, &miner);

				cout << miner.type_ << " / " << miner.fullTypeStr_ << endl;
			}

		private:
			OOLUA::Script script_;
		};

	} // namespace tcpclient
} // namespace btctools