#pragma once

#include <map>
#include <sstream>
#include <string>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <boost/algorithm/string.hpp>
#include <boost/regex.hpp>

#include "all.hpp"
#include "../lua/oolua/oolua.h"

using namespace std;
using boost::property_tree::ptree;
using boost::property_tree::read_json;
using boost::property_tree::write_json;

namespace btctools
{
	namespace miner
	{
		class DataParser
		{
		public:
			DataParser()
			{
				bool success = script_.run_file("./lua/scripts/DataParserHelper.lua");

				if (!success)
				{
					throw runtime_error(OOLUA::get_last_error(script_));
				}
			}

			void parseMinerStat(string jsonStr, Miner &miner)
			{
				OOLUA::Table minerTable;
				OOLUA::new_table(script_, minerTable);

				script_.call("parseMinerStat", jsonStr, minerTable);

				minerTable.at("typeStr", miner.type_);
				minerTable.at("fullTypeStr", miner.fullTypeStr_);

				cout << miner.type_ << " / " << miner.fullTypeStr_ << endl;
			}

			void parseMinerPools(string jsonStr, Miner &miner)
			{
				OOLUA::Table minerTable;
				OOLUA::new_table(script_, minerTable);

				script_.call("parseMinerStat", jsonStr, minerTable);

				minerTable.at("typeStr", miner.type_);
				minerTable.at("fullTypeStr", miner.fullTypeStr_);

				cout << miner.type_ << " / " << miner.fullTypeStr_ << endl;
			}

		private:
			OOLUA::Script script_;
		};

	} // namespace tcpclient
} // namespace btctools