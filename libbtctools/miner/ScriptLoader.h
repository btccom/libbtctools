#pragma once

#include "common.h"
#include "../lua/oolua/oolua.h"

namespace btctools
{
	namespace miner
	{
		class ScriptLoader
		{
		public:
			ScriptLoader(string scriptName);
			void makeRequest(WorkContext *context);
			void makeResult(WorkContext *context, btctools::tcpclient::Response *response);

		private:
			OOLUA::Script script_;
		};

	} // namespace tcpclient
} // namespace btctools