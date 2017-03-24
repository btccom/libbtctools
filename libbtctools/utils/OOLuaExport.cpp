#include "../miner/common.h"
#include "Crypto.h"
#include "OOLuaExport.h"

using namespace btctools::miner;
using namespace btctools::utils;

OOLUA_EXPORT_FUNCTIONS(Pool, url, worker, passwd, setUrl, setWorker, setPasswd)
OOLUA_EXPORT_FUNCTIONS_CONST(Pool)


OOLUA_EXPORT_FUNCTIONS(Miner, ip, stat, typeStr, fullTypeStr, pool1, pool2, pool3, opt,
			setIp, setStat, setTypeStr, setFullTypeStr, setPool1, setPool2, setPool3, setOpt)
OOLUA_EXPORT_FUNCTIONS_CONST(Miner)


OOLUA_EXPORT_FUNCTIONS(WorkContext, stepName, miner, canYield, requestHost, requestPort, requestContent,
			setStepName, setMiner, setCanYield, setRequestHost, setRequestPort, setRequestContent)
OOLUA_EXPORT_FUNCTIONS_CONST(WorkContext)


OOLUA_EXPORT_FUNCTIONS(Crypto)
OOLUA_EXPORT_FUNCTIONS_CONST(Crypto)

namespace btctools
{
	namespace utils
	{

		void OOLuaExport::exportAll(OOLUA::Script &script)
		{
			script.register_class<Pool>();
			script.register_class<Miner>();
			script.register_class<WorkContext>();
			script.register_class<Crypto>();
			script.register_class_static<Crypto>("md5", &OOLUA::Proxy_class<Crypto>::md5);
			script.register_class_static<Crypto>("base64Encode", &OOLUA::Proxy_class<Crypto>::base64Encode);
			script.register_class_static<Crypto>("base64Decode", &OOLUA::Proxy_class<Crypto>::base64Decode);
		}

	} // namespace utils
} // namespace btctools
