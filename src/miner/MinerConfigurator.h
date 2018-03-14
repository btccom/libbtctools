#ifndef BTCTOOLS_MINER_MINERCONFIGURATOR
#define BTCTOOLS_MINER_MINERCONFIGURATOR

#include "common.h"
#include "ScriptLoader.h"
#include "../tcpclient/Client.h"

namespace btctools
{
	namespace miner
	{
		class MinerConfigurator
		{
		public:
			MinerConfigurator(MinerSource &minerSource, int stepSize,
				string scriptName = "ConfiguratorHelper");
			WorkContext *newContext(Miner miner);
			MinerSource run(int sessionTimeout);
			void run(MinerYield &yield, int sessionTimeout);
			void stop();

		protected:
			void doNextWork();
			void yield(const Miner &miner);

		private:
			btctools::tcpclient::Client *client_;
			int stepSize_;
			MinerSource &minerSource_;
			MinerYield *yield_;
			ScriptLoader configuratorHelper_;

			int sessionTimeout_;
		};

	} // namespace tcpclient
} // namespace btctools

#endif //BTCTOOLS_MINER_MINERCONFIGURATOR
