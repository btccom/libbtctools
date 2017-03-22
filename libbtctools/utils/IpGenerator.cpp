#include "IpGenerator.h"

using namespace std;

namespace btctools
{
    namespace utils
    {
        
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

		int IpGenerator::getIpNumber()
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

		void IpGenerator::splitIpRange(const string &ipRangeString, string &begin, string &end)
		{
			size_t pos;

			// TODO: replace ~ -> -
			// TODO: reg replace [^0-9.-] -> ''

			pos = ipRangeString.find('-');

			if (pos != string::npos)
			{
				begin = ipRangeString.substr(0, pos);
				end = ipRangeString.substr(pos + 1);
				return;
			}

			pos = ipRangeString.find('*');

			if (pos != string::npos)
			{
				// TODO: reg replace: begin: \*+ -> 0
				// TODO: reg replace: end: \*+ ->255
				return;
			}

			// just a single IP
			{
				begin = ipRangeString;
				end = ipRangeString;
				return;
			}
		}

    } // namespace utils
} // namespace btctools
