#pragma once

#include "common.h"
#include "../lua/oolua/oolua.h"

namespace btctools
{
	namespace miner
	{
		class ConfiguratorHelper
		{
		public:
			ConfiguratorHelper();
			void makeRequest(WorkContext *context);
			void makeResult(WorkContext *context, btctools::tcpclient::Response *response);

		private:
			OOLUA::Script script_;
		};

	} // namespace tcpclient
} // namespace btctools