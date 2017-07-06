#include "IpGenerator.h"

using namespace std;

namespace btctools
{
    namespace utils
    {

		//************************ class IpGenerator ************************

		IpGenerator::IpGenerator(const string &ipRange)
		{
			string begin;
			string end;

			splitIpRange(ipRange, begin, end);

			ipLongBegin_ = ip2long(begin);
			ipLongEnd_ = ip2long(end);

			if (ipLongBegin_ > ipLongEnd_)
			{
				boost::swap(ipLongBegin_, ipLongEnd_);
			}

			// the loop at below will cannot end if ipLongEnd_ is "255.255.255.255"
			if (ipLongEnd_ == 0xffffffff)
			{
				// truncate it to "255.255.255.254" so the loop will end correctly
				ipLongEnd_ = 0xfffffffe;
			}
		}

		IpStrSource IpGenerator::genIpRange()
		{
			return IpStrSource([this](IpStrYield &yield)
			{
				int i = 0;

				assert(ipLongEnd_ < 0xffffffff);

				while (ipLongBegin_ <= ipLongEnd_)
				{
					yield(long2ip(ipLongBegin_));

					i++;
					ipLongBegin_++;
				}
			});
		}

		IpStrSource IpGenerator::genIpRange(int stepSize)
		{
			return IpStrSource([this, stepSize](IpStrYield &yield)
			{
				int i = 0;

				assert(ipLongEnd_ < 0xffffffff);

				while (i < stepSize && ipLongBegin_ <= ipLongEnd_)
				{
					yield(long2ip(ipLongBegin_));

					i++;
					ipLongBegin_++;
				}
			});
		}

		bool IpGenerator::hasNext()
		{
			return ipLongBegin_ <= ipLongEnd_;
		}

		string IpGenerator::next()
		{
			return long2ip(ipLongBegin_++);
		}

		string IpGenerator::getLastIp()
		{
			return long2ip(ipLongBegin_ - 1);
		}

		string IpGenerator::getNextIp()
		{
			return long2ip(ipLongBegin_);
		}

		string IpGenerator::getEndIp()
		{
			return long2ip(ipLongEnd_);
		}

		uint64_t IpGenerator::getIpNumber()
		{
			return ipLongEnd_ - ipLongBegin_ + 1;
		}

		uint32_t IpGenerator::ip2long(const string &ipString)
		{
			// use inet_addr() instead of inet_pton() for XP compatibility
			return ntohl(inet_addr(ipString.c_str()));
		}

		string IpGenerator::long2ip(const uint32_t &ipLong)
		{
			struct in_addr addr;
			addr.s_addr = htonl(ipLong);

			// use inet_ntoa() instead of inet_ntop() for XP compatibility
			return string(inet_ntoa(std::move(addr)));
		}

		void IpGenerator::splitIpRange(string ipRangeString, string &begin, string &end)
		{
			size_t pos;

			boost::replace_all(ipRangeString, "~", "-");
			replace_all_regex(ipRangeString, boost::regex("[^0-9*.-]"), string(""));

			pos = ipRangeString.find('-');

			if (pos != string::npos)
			{
				begin = ipRangeString.substr(0, pos);
				end = ipRangeString.substr(pos + 1);

				std::vector<std::string> beginSections;
				std::vector<std::string> endSections;

				boost::split(beginSections, begin, boost::is_any_of("."));
				boost::split(endSections, end, boost::is_any_of("."));

				if (endSections.size() < beginSections.size())
				{
					int i = beginSections.size() - endSections.size();

					endSections.insert(endSections.begin(), beginSections.begin(), beginSections.begin() + i);
					end = boost::join(endSections, ".");
				}

				return;
			}

			pos = ipRangeString.find('*');

			if (pos != string::npos)
			{
				begin = boost::replace_all_copy(ipRangeString, "*", "0");
				end = boost::replace_all_copy(ipRangeString, "*", "255");
				return;
			}

			// just a single IP
			{
				begin = ipRangeString;
				end = ipRangeString;
				return;
			}
		}


		//************************ class IpGeneratorGroup ************************

		IpGeneratorGroup::IpGeneratorGroup()
			: ipNumber_(0)
		{
		}

		void IpGeneratorGroup::addIpRange(const string & ipRange)
		{
			addIpRange(IpGenerator(ipRange));
		}

		void IpGeneratorGroup::addIpRange(IpGenerator ips)
		{
			if (ips.hasNext())
			{
				ipNumber_ += ips.getIpNumber();
				ipGenerators_.push_back(ips);
			}
		}

		void IpGeneratorGroup::clear()
		{
			ipNumber_ = 0;
			ipGenerators_.clear();
		}

		IpStrSource IpGeneratorGroup::genIpRange()
		{
			return IpStrSource([this](IpStrYield &yield)
			{
				while (!ipGenerators_.empty())
				{
					IpGenerator &ips = ipGenerators_.front();

					for (auto ip : ips.genIpRange())
					{
						yield(ip);
						ipNumber_--;
					}
					
					ipGenerators_.pop_front();
				}
			});
		}

		IpStrSource IpGeneratorGroup::genIpRange(int stepSize)
		{
			return IpStrSource([this, stepSize](IpStrYield &yield)
			{
				for (int i=0; i < stepSize && hasNext(); i++)
				{
					yield(next());
				}
			});
		}

		bool IpGeneratorGroup::hasNext()
		{
			return ipNumber_ > 0;
		}

		string IpGeneratorGroup::next()
		{
			IpGenerator &ips = ipGenerators_.front();
			auto ip = ips.next();
			ipNumber_--;

			if (!ips.hasNext())
			{
				ipGenerators_.pop_front();
			}

			return ip;
		}

		string IpGeneratorGroup::getLastIp()
		{
			return ipGenerators_.front().getLastIp();
		}

		string IpGeneratorGroup::getNextIp()
		{
			return ipGenerators_.front().getNextIp();
		}

		string IpGeneratorGroup::getEndIp()
		{
			return ipGenerators_.back().getEndIp();
		}

		uint64_t IpGeneratorGroup::getIpNumber()
		{
			return ipNumber_;
		}

} // namespace utils
} // namespace btctools
