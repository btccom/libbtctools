#pragma once

#include "../lua/oolua/oolua.h"
#include "../miner/common.h"
#include "Crypto.h"

/** struct Pool */
OOLUA_PROXY(btctools::miner::Pool)
OOLUA_MFUNC(url)
OOLUA_MFUNC(worker)
OOLUA_MFUNC(passwd)
OOLUA_MFUNC(setUrl)
OOLUA_MFUNC(setWorker)
OOLUA_MFUNC(setPasswd)
OOLUA_PROXY_END

/** struct Miner */
OOLUA_PROXY(btctools::miner::Miner)
OOLUA_MFUNC(ip)
OOLUA_MFUNC(stat)
OOLUA_MFUNC(typeStr)
OOLUA_MFUNC(fullTypeStr)
OOLUA_MFUNC(pool1)
OOLUA_MFUNC(pool2)
OOLUA_MFUNC(pool3)
OOLUA_MFUNC(setIp)
OOLUA_MFUNC(setStat)
OOLUA_MFUNC(setTypeStr)
OOLUA_MFUNC(setFullTypeStr)
OOLUA_MFUNC(setPool1)
OOLUA_MFUNC(setPool2)
OOLUA_MFUNC(setPool3)
OOLUA_PROXY_END

/** struct WorkContext */
OOLUA_PROXY(btctools::miner::WorkContext)
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

/** class Crypto */
OOLUA_PROXY(btctools::utils::Crypto)
OOLUA_TAGS(No_public_constructors)
OOLUA_SFUNC(md5)
OOLUA_SFUNC(base64Encode)
OOLUA_SFUNC(base64Decode)
OOLUA_PROXY_END


namespace btctools
{
	namespace utils
	{

		class OOLuaExport
		{
		public:
			static void exportAll(OOLUA::Script &script);
		}; // class end

	} // namespace utils
} // namespace btctools
