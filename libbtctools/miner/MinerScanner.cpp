#pragma once

#include "MinerScanner.h"
#include "../utils/IpGenerator.h"

using namespace std;
using namespace btctools::utils;

namespace btctools
{
	namespace miner
	{

		MinerScanner::MinerScanner(IpStrSource &ipSource, int stepSize) :
			ipSource_(ipSource), stepSize_(stepSize),
			yield_(nullptr), client_(nullptr),
			sessionTimeout_(0)
		{}

		WorkContext *MinerScanner::newContext(string ip)
		{
			WorkContext *context = new WorkContext;
			context->stepName_ = "begin";
			context->miner_.ip_ = std::move(ip);
			context->canYield_ = false;
			context->request_.usrdata_ = context;

			context->request_.session_timeout_ = sessionTimeout_;
			context->request_.delay_timeout_ = 0;

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
			sessionTimeout_ = sessionTimeout;

			btctools::tcpclient::RequestSource requestSource(
				[this](btctools::tcpclient::RequestYield &requestYield)
			{
				for (int i=0; i<stepSize_ && ipSource_; i++)
				{
					auto ip = ipSource_.get();
					WorkContext *context = newContext(std::move(ip));
					scannerHelper_.makeRequest(context);

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

					ipSource_();
				}
			});

			client_ = new btctools::tcpclient::Client();
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

					if (context->canYield_)
					{
						this->yield(context->miner_);
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


		void MinerScanner::doNextWork()
		{
			if (ipSource_)
			{
				auto ip = ipSource_.get();
				WorkContext *context = newContext(std::move(ip));
				scannerHelper_.makeRequest(context);

				if (context->canYield_)
				{
					this->yield(context->miner_);
				}

				if (context->stepName_ == string("end"))
				{
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