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

#include "all.hpp"

using namespace std;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{
		class MinerScanner
		{
		public:
			MinerScanner(string ipRange, int stepSize)
				:ips_(ipRange), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
			{}

			void run(ScanResultProductor &yield, int sessionTimeout)
			{
				yield_ = &yield;

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

		protected:
			static void setRequestFindType(btctools::tcpclient::Request *req, const string &ip)
			{
				req->host_ = ip;
				req->port_ = "4028";

				// use CGMiner RPC: https://github.com/ckolivas/cgminer/blob/master/API-README
				// the response of JSON styled calling {"command":"stats"} will responsed
				// a invalid JSON string from Antminer S9, so call with plain text style.
				req->content_ = "{\"command\":\"stats\"}";
			}

			static void setRequestFindPools(btctools::tcpclient::Request *req, const string &ip)
			{
				req->host_ = ip;
				req->port_ = "4028";
				req->content_ = "{\"command\":\"pools\"}";
			}

			void doFindType(ScanRequestData *reqData, btctools::tcpclient::Response *response)
			{
				if (response->error_code_ == boost::asio::error::eof)
				{

					ScanResult *result = new ScanResult;

					result->action_ = ScanAction::FOUND_TYPE;
					result->miner_.ip_ = reqData->request_->host_;
					
					dataParser_.parseMinerPools(response->content_, result->miner_);

					yield(result);

					// step 2: find pools
					setRequestFindPools(reqData->request_, reqData->request_->host_);
					reqData->type_ = ScanRequestType::FIND_POOLS;
					reqData->result_ = result;

					ScanRequestData *data = (ScanRequestData *)reqData->request_->usrdata_;
					
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
				assert(reqData->result_ != nullptr);

				ScanResult *result = reqData->result_;

				if (response->error_code_ == boost::asio::error::eof)
				{
					dataParser_.parseMinerStat(response->content_, reqData->result_->miner_);

					result->action_ = ScanAction::FOUND_POOLS;
					yield(result);
				}
				else
				{
					yieldError(*result, reqData->request_->host_, response->error_code_);
				}

				//delete result;
				doNextWork(reqData);
			}

			void doNextWork(ScanRequestData *reqData)
			{
				auto request = reqData->request_;

				if (ips_.hasNext())
				{
					setRequestFindType(request, ips_.next());
					reqData->type_ = ScanRequestType::FIND_TYPE;
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
			ScanResultProductor *yield_;
			DataParser dataParser_;
		};

	} // namespace tcpclient
} // namespace btctools