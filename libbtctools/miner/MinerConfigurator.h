#pragma once

#include "common.h"
#include "ConfiguratorHelper.h"
#include "../tcpclient/Client.h"

namespace btctools
{
	namespace miner
	{
		class MinerConfigurator
		{
		public:
			MinerConfigurator(MinerSource &minerSource, int stepSize);
			WorkContext *newContext(Miner miner);
			MinerSource run(int sessionTimeout);
			void run(MinerYield &yield, int sessionTimeout);

		protected:
			void doNextWork();
			void yield(const Miner &miner);

		private:
			btctools::tcpclient::Client *client_;
			int stepSize_;
			MinerSource &minerSource_;
			MinerYield *yield_;
			ConfiguratorHelper configuratorHelper_;
		};

	} // namespace tcpclient
} // namespace btctools
