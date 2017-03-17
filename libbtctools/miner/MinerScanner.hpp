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

			void run(MinerProductor &yield, int sessionTimeout)
			{
				yield_ = &yield;

				btctools::tcpclient::RequestConsumer requestConsumer(
					[this](btctools::tcpclient::RequestProductor &requestProductor)
				{
					StringConsumer ipSource = ips_.genIpRange(stepSize_);

					for (auto ip : ipSource)
					{
						ScanContext *context = new ScanContext;
						context->stepName_ = "begin";
						context->miner_.ip_ = ip;
						context->canYield_ = false;
						context->request_.usrdata_ = context;

						scannerHelper_.makeRequest(context);

						requestProductor(&context->request_);
					}
				});

				client_ = new btctools::tcpclient::Client(sessionTimeout);
				auto responseConsumer = client_->run(requestConsumer);

				for (auto response : responseConsumer)
				{
					ScanContext *context = (ScanContext *)response->usrdata_;

					scannerHelper_.makeResult(context, response);

					if (context->canYield_)
					{
						yield(context->miner_);
					}

					if (context->stepName_ == string("end"))
					{
						doNextWork(context);
					}
					else
					{
						scannerHelper_.makeRequest(context);
						client_->addWork(&context->request_);
					}

					delete response;
				}

				delete client_;
				client_ = nullptr;
			}

		protected:
			/*static void setRequestFindType(btctools::tcpclient::Request *req, const string &ip)
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
			}*/
			
			void doNextWork(ScanContext *context)
			{
				auto request = context->request_;

				if (ips_.hasNext())
				{
					context->stepName_ = "begin";
					context->miner_.ip_ = ips_.next();
					context->canYield_ = false;

					scannerHelper_.makeRequest(context);

					client_->addWork(&context->request_);
				}
				else
				{
					delete context;
				}
			}

			void yield(const Miner &miner)
			{
				(*yield_)(miner);
			}

		private:
			btctools::tcpclient::Client *client_;
			IpGenerator ips_;
			int stepSize_;
			MinerProductor *yield_;
			ScannerHelper scannerHelper_;
		};

	} // namespace tcpclient
} // namespace btctools