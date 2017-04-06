#pragma once

#include <string>
#include <map>
#include "../tcpclient/common.h"
#include "../lua/oolua/oolua.h"

namespace btctools
{
	namespace miner
	{
        using string = std::string;
		using stringMap = std::map<string, string>;

		struct Pool
		{
			string url_;
			string worker_;
			string passwd_;

			//-------------- used by lua scripts --------------

			string& url();
			string& worker();
			string& passwd();

			void setUrl(string url);
			void setWorker(string worker);
			void setPasswd(string passwd);
		};

		struct Miner
		{
			string ip_;
			string stat_;
			string typeStr_;
			string fullTypeStr_;

			Pool pool1_;
			Pool pool2_;
			Pool pool3_;

			stringMap opts_;

			//-------------- used by lua scripts --------------

			string& ip();
			string& stat();
			string& typeStr();
			string& fullTypeStr();
			Pool& pool1();
			Pool& pool2();
			Pool& pool3();
			string opt(const string &key) const;

			void setIp(string ip);
			void setStat(string stat);
			void setTypeStr(string typeStr);
			void setFullTypeStr(string fullTypeStr);
			void setPool1(Pool pool1);
			void setPool2(Pool pool2);
			void setPool3(Pool pool3);
			void setOpt(const string &key, const string &value);
		};

		struct WorkContext
		{
			string stepName_;
			btctools::tcpclient::Request request_;
			Miner miner_;
			bool canYield_;

			//-------------- used by lua scripts --------------
			string& stepName();
			Miner& miner();
			bool& canYield();
			string& requestHost();
			string& requestPort();
			string& requestContent();

			void setStepName(string stepName);
			void setMiner(Miner miner);
			void setCanYield(bool canYield);
			void setRequestHost(string host);
			void setRequestPort(string port);
			void setRequestContent(string content);
		};

		using coro_miner_t = boost::coroutines2::coroutine<const Miner &>;

		using MinerYield = coro_miner_t::push_type;
		using MinerSource = coro_miner_t::pull_type;

	} // namespace tcpclient
} // namespace btctools
