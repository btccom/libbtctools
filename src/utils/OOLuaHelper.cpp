#include "../miner/common.h"
#include "Crypto.h"
#include "OOLuaHelper.h"

using namespace btctools::miner;
using namespace btctools::utils;

OOLUA_EXPORT_FUNCTIONS(Pool, url, worker, passwd, setUrl, setWorker, setPasswd)
OOLUA_EXPORT_FUNCTIONS_CONST(Pool)


OOLUA_EXPORT_FUNCTIONS(Miner, ip, stat, typeStr, fullTypeStr, pool1, pool2, pool3,
			setIp, setStat, setTypeStr, setFullTypeStr, setPool1, setPool2, setPool3, setOpt)
OOLUA_EXPORT_FUNCTIONS_CONST(Miner, opt)


OOLUA_EXPORT_FUNCTIONS(WorkContext, stepName, miner, canYield,
	requestHost, requestPort, requestContent,
	requestSessionTimeout, requestDelayTimeout,
	setStepName, setMiner, setCanYield,
	setRequestHost, setRequestPort, setRequestContent,
	setRequestSessionTimeout, setRequestDelayTimeout)
OOLUA_EXPORT_FUNCTIONS_CONST(WorkContext)


OOLUA_EXPORT_FUNCTIONS(Crypto)
OOLUA_EXPORT_FUNCTIONS_CONST(Crypto)

OOLUA_EXPORT_FUNCTIONS(OOLuaHelper)
OOLUA_EXPORT_FUNCTIONS_CONST(OOLuaHelper)

namespace btctools
{
	namespace utils
	{
		string OOLuaHelper::packagePath_ = ".";
		ScriptLoader *OOLuaHelper::scriptLoader_ = nullptr;

		void OOLuaHelper::setPackagePath(const string &packagePath)
		{
			packagePath_ = packagePath;
		}

		void OOLuaHelper::setScriptLoader(ScriptLoader & loader)
		{
			scriptLoader_ = &loader;
		}

		void OOLuaHelper::exportAll(OOLUA::Script &script)
		{
			script.register_class<Pool>();
			script.register_class<Miner>();
			script.register_class<WorkContext>();
			script.register_class<Crypto>();
			script.register_class_static<Crypto>("md5", &OOLUA::Proxy_class<Crypto>::md5);
			script.register_class_static<Crypto>("sha1", &OOLUA::Proxy_class<Crypto>::sha1);
			script.register_class_static<Crypto>("sha256", &OOLUA::Proxy_class<Crypto>::sha256);
			script.register_class_static<Crypto>("base64Encode", &OOLUA::Proxy_class<Crypto>::base64Encode);
			script.register_class_static<Crypto>("base64Decode", &OOLUA::Proxy_class<Crypto>::base64Decode);

			OOLUA::Table package;
			OOLUA::get_global(script, "package", package);

			// set package.path
			package.set("path", packagePath_ + "/?.lua");

			if (scriptLoader_ != nullptr)
			{
				script.register_class<OOLuaHelper>();
				script.register_class_static<OOLuaHelper>("loadScript", &OOLUA::Proxy_class<OOLuaHelper>::loadScript);

				script.run_chunk(
					"package.loaders = {\n"
					"	function (name)\n"
					"		local result = {}\n"
					"		OOLuaHelper.loadScript(name, result)\n"
					"		if (result.errmsg == nil) then\n"
					"			return assert(loadstring(result.content, name))\n"
					"		else\n"
					"			return result.errmsg\n"
					"		end\n"
					"	end\n"
					"}\n"
				);
			}
		}

		bool OOLuaHelper::runFile(OOLUA::Script &script, const string &name)
		{
			if (scriptLoader_ != nullptr)
			{
				string content;
				string errmsg;

				bool success = (*scriptLoader_)(name, content, errmsg);

				if (success)
				{
					return script.run_chunk(content);
				}
				else
				{
					throw std::runtime_error(errmsg);
				}
			}
			else
			{
				return script.run_file(packagePath_ + '/' + name + ".lua");
			}
		}

		void OOLuaHelper::loadScript(const string &name, OOLUA::Table &result)
		{
			if (scriptLoader_ != nullptr)
			{
				/*
				* define of *scriptLoader_:
				* using ScriptLoader = std::function<bool(const string &name, string &content, string &errmsg)>;
				*/

				string content;
				string errmsg;

				bool success = (*scriptLoader_)(name, content, errmsg);

				if (success)
				{
					result.set("content", content);
				}
				else
				{
					result.set("errmsg", errmsg);
				}
			}
			else
			{
				result.set("errmsg", " script loader is empty!");
			}
		}

	} // namespace utils
} // namespace btctools
