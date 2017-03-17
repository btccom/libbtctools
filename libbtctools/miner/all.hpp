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

			string getUrl() const
			{
				return url_;
			}
			string getWorker() const
			{
				return worker_;
			}
			string getPasswd() const
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
			string type_;
			string fullTypeStr_;

			Pool pool1_;
			Pool pool2_;
			Pool pool3_;

			//-------------- used by lua scripts --------------

			string getIp() const
			{
				return ip_;
			}
			string getType() const
			{
				return type_;
			}
			string getFullTypeStr() const
			{
				return fullTypeStr_;
			}
			Pool getPool1() const
			{
				return pool1_;
			}
			Pool getPool2() const
			{
				return pool2_;
			}
			Pool getPool3() const
			{
				return pool3_;
			}

			void setIp(string ip)
			{
				ip_ = std::move(ip);
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

		enum class ScanAction
		{
			UNKNOWN_ERROR,
			CONN_TIMEOUT,
			CONN_REFUSED,
			FOUND_TYPE,
			FOUND_POOLS,
		};

		struct ScanResult
		{
			ScanAction action_;
			Miner miner_;
		};

		enum class ScanRequestType
		{
			FIND_TYPE,
			FIND_POOLS,
		};

		struct ScanRequestData
		{
			ScanRequestType type_;
			btctools::tcpclient::Request *request_;
			ScanResult *result_;
		};

		typedef boost::coroutines2::coroutine<const ScanResult *> coro_scanresult_t;

		typedef coro_scanresult_t::push_type ScanResultProductor;
		typedef coro_scanresult_t::pull_type ScanResultConsumer;

	} // namespace tcpclient
} // namespace btctools

#include "DataParser.hpp"
#include "MinerScanner.hpp"
