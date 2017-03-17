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

			ScanContext *newContext(string ip)
			{
				ScanContext *context = new ScanContext;
				context->stepName_ = "begin";
				context->miner_.ip_ = std::move(ip);
				context->canYield_ = false;
				context->request_.usrdata_ = context;

				return context;
			}

			void run(MinerProductor &yield, int sessionTimeout)
			{
				yield_ = &yield;

				btctools::tcpclient::RequestConsumer requestConsumer(
					[this](btctools::tcpclient::RequestProductor &requestProductor)
				{
					StringConsumer ipSource = ips_.genIpRange(stepSize_);

					for (auto ip : ipSource)
					{
						ScanContext *context = newContext(ip);
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
						delete context;
						doNextWork();
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

			void doNextWork()
			{
				if (ips_.hasNext())
				{
					ScanContext *context = newContext(ips_.next());
					scannerHelper_.makeRequest(context);

					client_->addWork(&context->request_);
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