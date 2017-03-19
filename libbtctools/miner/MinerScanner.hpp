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
			MinerScanner(IpStrSource &ipSource, int stepSize)
				:ipSource_(ipSource), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
			{}

			WorkContext *newContext(string ip)
			{
				WorkContext *context = new WorkContext;
				context->stepName_ = "begin";
				context->miner_.ip_ = std::move(ip);
				context->canYield_ = false;
				context->request_.usrdata_ = context;

				return context;
			}

			MinerSource run(int sessionTimeout)
			{
				return MinerSource([this, sessionTimeout](MinerYield &yield)
				{
					run(yield, sessionTimeout);
				});
			}

			void run(MinerYield &yield, int sessionTimeout)
			{
				yield_ = &yield;

				btctools::tcpclient::RequestSource requestSource(
					[this](btctools::tcpclient::RequestYield &requestYield)
				{
					for (int i=0; i<stepSize_ && ipSource_; i++)
					{
						auto ip = ipSource_.get();
						WorkContext *context = newContext(std::move(ip));
						scannerHelper_.makeRequest(context);

						if (context->stepName_ == string("end"))
						{
							if (context->canYield_)
							{
								this->yield(context->miner_);
							}

							delete context;
							i--;
						}
						else
						{
							requestYield(&context->request_);
						}

						ipSource_();
					}
				});

				client_ = new btctools::tcpclient::Client(sessionTimeout);
				auto responseSource = client_->run(requestSource);

				for (auto response : responseSource)
				{
					WorkContext *context = (WorkContext *)response->usrdata_;

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
				if (ipSource_)
				{
					auto ip = ipSource_.get();
					WorkContext *context = newContext(std::move(ip));
					scannerHelper_.makeRequest(context);

					if (context->stepName_ == string("end"))
					{
						if (context->canYield_)
						{
							this->yield(context->miner_);
						}

						delete context;
						ipSource_();
						doNextWork();
					}
					else
					{
						client_->addWork(&context->request_);
						ipSource_();
					}
				}
			}

			void yield(const Miner &miner)
			{
				(*yield_)(miner);
			}

		private:
			btctools::tcpclient::Client *client_;
			IpStrSource &ipSource_;
			int stepSize_;
			MinerYield *yield_;
			ScannerHelper scannerHelper_;
		};

	} // namespace tcpclient
} // namespace btctools