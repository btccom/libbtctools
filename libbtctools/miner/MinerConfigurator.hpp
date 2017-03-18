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
		class MinerConfigurator
		{
		public:
			MinerConfigurator(MinerSource &minerSource, int stepSize)
				:minerSource_(minerSource), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
			{}

			WorkContext *newContext(Miner miner)
			{
				WorkContext *context = new WorkContext;
				context->stepName_ = "begin";
				context->miner_ = std::move(miner);
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

					for (int i = 0; i<stepSize_ && minerSource_; i++)
					{
						auto miner = minerSource_.get();
						WorkContext *context = newContext(std::move(miner));
						configuratorHelper_.makeRequest(context);

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

						minerSource_();
					}
				});

				client_ = new btctools::tcpclient::Client(sessionTimeout);
				auto responseSource = client_->run(requestSource);

				for (auto response : responseSource)
				{
					WorkContext *context = (WorkContext *)response->usrdata_;

					configuratorHelper_.makeResult(context, response);

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
						configuratorHelper_.makeRequest(context);
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
				if (minerSource_)
				{
					auto miner = minerSource_.get();
					WorkContext *context = newContext(std::move(miner));
					configuratorHelper_.makeRequest(context);

					if (context->stepName_ == string("end"))
					{
						if (context->canYield_)
						{
							this->yield(context->miner_);
						}

						delete context;
						minerSource_();
						doNextWork();
					}
					else
					{
						client_->addWork(&context->request_);
						minerSource_();
					}
				}
			}

			void yield(const Miner &miner)
			{
				(*yield_)(miner);
			}

		private:
			btctools::tcpclient::Client *client_;
			int stepSize_;
			MinerSource &minerSource_;
			MinerYield *yield_;
			ConfiguratorHelper configuratorHelper_;
		};

	} // namespace tcpclient
} // namespace btctools