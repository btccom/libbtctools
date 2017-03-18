#pragma once

#include <map>
#include <sstream>
#include <string>

#include "all.hpp"
#include "../utils/Crypto.hpp"
#include "../lua/oolua/oolua.h"

using namespace std;
using namespace btctools::miner;
using namespace btctools::utils;

/** struct Pool */
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

/** struct Miner */
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

/** struct WorkContext */
OOLUA_PROXY(WorkContext)
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
OOLUA_EXPORT_FUNCTIONS(WorkContext, stepName, miner, canYield, requestHost, requestPort, requestContent,
	setStepName, setMiner, setCanYield, setRequestHost, setRequestPort, setRequestContent)
OOLUA_EXPORT_FUNCTIONS_CONST(WorkContext)

/** class Crypto */
OOLUA_PROXY(Crypto)
	OOLUA_TAGS(No_public_constructors)
	OOLUA_SFUNC(md5)
OOLUA_PROXY_END
OOLUA_EXPORT_FUNCTIONS(Crypto)
OOLUA_EXPORT_FUNCTIONS_CONST(Crypto)
