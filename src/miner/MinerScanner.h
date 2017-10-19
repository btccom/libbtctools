#pragma once

#include "common.h"
#include "ScriptLoader.h"
#include "../tcpclient/Client.h"
#include "../utils/IpGenerator.h"

namespace btctools
{
	namespace miner
	{
		class MinerScanner
		{
		public:
			MinerScanner(btctools::utils::IpStrSource &ipSource, int stepSize,
				string scriptName = "ScannerHelper");
			WorkContext *newContext(string ip);
			MinerSource run(int sessionTimeout);
			void run(MinerYield &yield, int sessionTimeout);
			void stop();

		protected:
			void doNextWork();
			void yield(const Miner &miner);

		private:
			btctools::tcpclient::Client *client_;
			btctools::utils::IpStrSource &ipSource_;
			int stepSize_;
			MinerYield *yield_;
			ScriptLoader scannerHelper_;

			int sessionTimeout_;
		};

	} // namespace tcpclient
} // namespace btctools
