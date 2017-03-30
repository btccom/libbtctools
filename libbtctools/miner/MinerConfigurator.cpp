#pragma once

#include "MinerConfigurator.h"
#include "../utils/IpGenerator.h"

using namespace std;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		MinerConfigurator::MinerConfigurator(MinerSource &minerSource, int stepSize)
			:minerSource_(minerSource), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
		{}

		WorkContext *MinerConfigurator::newContext(Miner miner)
		{
			WorkContext *context = new WorkContext;
			context->stepName_ = "begin";
			context->miner_ = std::move(miner);
			context->canYield_ = false;
			context->request_.usrdata_ = context;

			return context;
		}

		MinerSource MinerConfigurator::run(int sessionTimeout)
		{
			return MinerSource([this, sessionTimeout](MinerYield &yield)
			{
				run(yield, sessionTimeout);
			});
		}

		void MinerConfigurator::run(MinerYield &yield, int sessionTimeout)
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

					if (context->canYield_)
					{
						this->yield(context->miner_);
					}

					if (context->stepName_ == string("end"))
					{
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
						client_->addWork(&context->request_);
					}
				}

				delete response;
			}

			delete client_;
			client_ = nullptr;
		}


		void MinerConfigurator::doNextWork()
		{
			if (minerSource_)
			{
				auto miner = minerSource_.get();
				WorkContext *context = newContext(std::move(miner));
				configuratorHelper_.makeRequest(context);

				if (context->canYield_)
				{
					this->yield(context->miner_);
				}

				if (context->stepName_ == string("end"))
				{
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

		void MinerConfigurator::yield(const Miner &miner)
		{
			(*yield_)(miner);
		}

	} // namespace tcpclient
} // namespace btctools