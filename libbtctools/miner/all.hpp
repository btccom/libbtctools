#pragma once

#include <iostream>
#include <sstream>
#include <memory>
#include <string>
#include <vector>

#include <boost/coroutine2/all.hpp>
#include <boost/regex.hpp>

#include "../tcpclient/all.hpp"
#include "../utils/IpGenerator.hpp"

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

		typedef boost::coroutines2::coroutine<const ScanResult *> coro_scanrequest_t;

		typedef coro_scanrequest_t::push_type ScanRequestProductor;
		typedef coro_scanrequest_t::pull_type ScanRequestConsumer;

		class MinerScanner
		{
		public:
			MinerScanner(string ipRange, int stepSize)
				:ips_(ipRange), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
			{}

			void setRequestFindType(btctools::tcpclient::Request *req, const string &ip)
			{
				req->host_ = ip;
				req->port_ = 4028;

				// use CGMiner RPC: https://github.com/ckolivas/cgminer/blob/master/API-README
				// the response of JSON styled calling {"command":"stats"} will responsed
				// a invalid JSON string from Antminer S9, so call with plain text style.
				req->content_ = "stat|";
			}

			void setRequestFindPools(btctools::tcpclient::Request *req, const string &ip)
			{
				req->host_ = ip;
				req->port_ = 4028;
				req->content_ = "pools|";
			}

			void run(ScanRequestProductor &yield, int sessionTimeout)
			{
				btctools::tcpclient::RequestConsumer requestConsumer(
					[this](btctools::tcpclient::RequestProductor &requestProductor)
				{
					StringConsumer ipSource = ips_.genIpRange(stepSize_);

					for (auto ip : ipSource)
					{
						auto *req = new btctools::tcpclient::Request;
						auto *reqData = new ScanRequestData;

						setRequestFindType(req, ip);

						reqData->type_ = ScanRequestType::FIND_TYPE;
						reqData->request_ = req;
						reqData->result_ = nullptr;

						req->usrdata_ = reqData;

						requestProductor(req);
					}
				});

				client_ = new btctools::tcpclient::Client(sessionTimeout);
				auto responseConsumer = client_->run(requestConsumer);

				for (auto response : responseConsumer)
				{
					ScanRequestData *reqData = (ScanRequestData *)response->usrdata_;

					switch (reqData->type_)
					{
					case ScanRequestType::FIND_TYPE:
						doFindType(reqData, response);
						break;
					case ScanRequestType::FIND_POOLS:
						doFindPools(reqData, response);
						break;
					}

					delete response;
				}

				delete client_;
				client_ = nullptr;
			}

			void doFindType(ScanRequestData *reqData, btctools::tcpclient::Response *response)
			{
				if (response->error_code_ == boost::asio::error::eof)
				{

					string minerTypeStr = "Unknown";
					MinerType minerType = MinerType::UNKNOWN;

					// Only Antminer has the field.
					boost::regex expression(",Type=([^\\|]+)\\|");
					boost::smatch what;

					if (boost::regex_search(response->content_, what, expression))
					{
						minerTypeStr = what[1];
					}

					auto *result = new ScanResult;

					result->action_ = ScanAction::FOUND_TYPE;
					result->miner_.ip_ = reqData->request_->host_;
					result->miner_.type_ = minerType;
					result->miner_.typestr_ = minerTypeStr;

					results_.insert(result);
					yield(result);

					// step 2: find pools
					setRequestFindPools(reqData->request_, reqData->request_->host_);
					reqData->type_ = ScanRequestType::FIND_POOLS;
					reqData->result_ = result;
					
					client_->addWork(reqData->request_);
				}
				else
				{
					yieldError(ScanResult(), reqData->request_->host_, response->error_code_);
					doNextWork(reqData);
				}
			}

			void doFindPools(ScanRequestData *reqData, btctools::tcpclient::Response *response)
			{
				assert(reqData->request_ != nullptr);

				if (response->error_code_ == boost::asio::error::eof)
				{
				}
				else
				{
					yieldError(*reqData->result_, reqData->request_->host_, response->error_code_);
				}

				doNextWork(reqData);
			}

			void doNextWork(ScanRequestData *reqData)
			{
				auto request = reqData->request_;

				if (ips_.hasNext())
				{
					setRequestFindType(request, ips_.next());
					reqData->result_ = nullptr;
					client_->addWork(request);
				}
				else
				{
					delete request;
					delete reqData;
				}
			}

			void yieldError(ScanResult &scanRes, const string &ip, boost::system::error_code ec)
			{
				scanRes.miner_.ip_ = ip;

				switch (ec.value())
				{
				case boost::asio::error::timed_out:
					scanRes.action_ = ScanAction::CONN_TIMEOUT;
					break;

				case boost::asio::error::connection_refused:
					scanRes.action_ = ScanAction::CONN_REFUSED;
					break;

				default:
					scanRes.action_ = ScanAction::UNKNOWN_ERROR;
					break;
				}

				yield(&scanRes);
			}

			void yield(const ScanResult *scanRes)
			{
				(*yield_)(scanRes);
			}

		private:
			btctools::tcpclient::Client *client_;
			IpGenerator ips_;
			int stepSize_;
			ScanRequestProductor *yield_;
			vector<ScanResult *> results_;
		};

	} // namespace tcpclient
} // namespace btctools