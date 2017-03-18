#pragma once

#include "../tcpclient/all.hpp"
#include "../utils/IpGenerator.hpp"

#include <iostream>
#include <sstream>
#include <memory>
#include <string>
#include <vector>
#include <list>

#include <boost/coroutine2/all.hpp>
#include <boost/regex.hpp>

#include "../lua/oolua/oolua.h"

using namespace std;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		struct Pool
		{
			string url_;
			string worker_;
			string passwd_;

			//-------------- used by lua scripts --------------

			string& url()
			{
				return url_;
			}
			string& worker()
			{
				return worker_;
			}
			string& passwd()
			{
				return passwd_;
			}

			void setUrl(string url)
			{
				url_ = std::move(url);
			}
			void setWorker(string worker)
			{
				worker_ = std::move(worker);
			}
			void setPasswd(string passwd)
			{
				passwd_ = std::move(passwd);
			}
		};

		struct Miner
		{
			string ip_;
			string stat_;
			string type_;
			string fullTypeStr_;

			Pool pool1_;
			Pool pool2_;
			Pool pool3_;

			//-------------- used by lua scripts --------------

			string& ip()
			{
				return ip_;
			}
			string& stat()
			{
				return stat_;
			}
			string& type()
			{
				return type_;
			}
			string& fullTypeStr()
			{
				return fullTypeStr_;
			}
			Pool& pool1()
			{
				return pool1_;
			}
			Pool& pool2()
			{
				return pool2_;
			}
			Pool& pool3()
			{
				return pool3_;
			}

			void setIp(string ip)
			{
				ip_ = std::move(ip);
			}
			void setStat(string stat)
			{
				stat_ = std::move(stat);
			}
			void setType(string type)
			{
				type_ = std::move(type);
			}
			void setFullTypeStr(string fullTypeStr)
			{
				fullTypeStr_ = std::move(fullTypeStr);
			}
			void setPool1(Pool pool1)
			{
				pool1_ = std::move(pool1);
			}
			void setPool2(Pool pool2)
			{
				pool2_ = std::move(pool2);
			}
			void setPool3(Pool pool3)
			{
				pool3_ = std::move(pool3);
			}
		};

		struct WorkContext
		{
			string stepName_;
			btctools::tcpclient::Request request_;
			Miner miner_;
			bool canYield_;

			//-------------- used by lua scripts --------------
			string& stepName()
			{
				return stepName_;
			}
			Miner& miner()
			{
				return miner_;
			}
			bool& canYield()
			{
				return canYield_;
			}
			string& requestHost()
			{
				return request_.host_;
			}
			string& requestPort()
			{
				return request_.port_;
			}
			string& requestContent()
			{
				return request_.content_;
			}

			void setStepName(string stepName)
			{
				stepName_ = std::move(stepName);
			}
			void setMiner(Miner miner)
			{
				miner_ = std::move(miner);
			}
			void setCanYield(bool canYield)
			{
				canYield_ = std::move(canYield);
			}
			void setRequestHost(string host)
			{
				request_.host_ = std::move(host);
			}
			void setRequestPort(string port)
			{
				request_.port_ = std::move(port);
			}
			void setRequestContent(string content)
			{
				request_.content_ = std::move(content);
			}
		};

		typedef boost::coroutines2::coroutine<const Miner &> coro_miner_t;

		typedef coro_miner_t::push_type MinerYield;
		typedef coro_miner_t::pull_type MinerSource;

	} // namespace tcpclient
} // namespace btctools

#include "ooluaExport.hpp"
#include "ScannerHelper.hpp"
#include "ConfiguratorHelper.hpp"
#include "MinerScanner.hpp"
#include "MinerConfigurator.hpp"
