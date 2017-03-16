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
			static void parseMinerStat(string jsonStr, Miner &miner)
			{
				OOLUA::Script script;
				assert(script.run_file("./lua/scripts/parseMinerStat.lua"));
				script.call("parseMinerStat", jsonStr);

				/*miner.fullTypeStr_ = "Unknown";

				// Fix the invalid JSON struct from Antminer S9
				boost::replace_all(jsonStr, "\"}{\"", "\"},{\"");
				// Remove blanks at top and bottom, or read_json() will throw an exception.
				int pos = jsonStr.find_first_of('{');
				int len = jsonStr.find_last_of('}') - pos + 1;
				jsonStr = jsonStr.substr(pos, len);

				stringstream jsonStream;
				jsonStream << jsonStr;

				ptree json;
				read_json(jsonStream, json);
				
				if (json.count("STATS"))
				{
					ptree jsonStats = json.get_child("STATS");
					
					for (auto item : jsonStats)
					{
						if (item.second.count("Type"))
						{
							miner.fullTypeStr_ = item.second.get<string>("Type");
						}
					}
				}*/
			}
		};

	} // namespace tcpclient
} // namespace btctools