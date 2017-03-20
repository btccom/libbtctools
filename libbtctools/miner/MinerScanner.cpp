#pragma once

#include "MinerScanner.h"
#include "../utils/IpGenerator.h"

using namespace std;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		MinerScanner::MinerScanner(IpStrSource &ipSource, int stepSize)
			:ipSource_(ipSource), stepSize_(stepSize), yield_(nullptr), client_(nullptr)
		{}

		WorkContext *MinerScanner::newContext(string ip)
		{
			WorkContext *context = new WorkContext;
			context->stepName_ = "begin";
			context->miner_.ip_ = std::move(ip);
			context->canYield_ = false;
			context->request_.usrdata_ = context;

			return context;
		}

		MinerSource MinerScanner::run(int sessionTimeout)
		{
			return MinerSource([this, sessionTimeout](MinerYield &yield)
			{
				run(yield, sessionTimeout);
			});
		}

		void MinerScanner::run(MinerYield &yield, int sessionTimeout)
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


		void MinerScanner::doNextWork()
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

		void MinerScanner::yield(const Miner &miner)
		{
			(*yield_)(miner);
		}

	} // namespace tcpclient
} // namespace btctools