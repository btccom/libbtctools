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
		};

		enum class MinerType
		{
			UNKNOWN,
			Antminer_S9,
		};

		struct Miner
		{
			string ip_;
			MinerType type_;
			string typestr_;

			Pool pool1_;
			Pool pool2_;
			Pool pool3_;
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

#include "MinerScanner.hpp"
