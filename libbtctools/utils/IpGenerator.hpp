#pragma once

#include <iostream>
#include <sstream>
#include <memory>
#include <string>
#include <vector>

#include <boost/swap.hpp>
#include <boost/coroutine2/all.hpp>
#include <boost/asio/detail/socket_ops.hpp>

#ifdef _WIN32
 #include <winsock2.h>
#else
 #include <sys/socket.h>
 #include <netinet/in.h>
 #include <arpa/inet.h>
#endif

using namespace std;

namespace btctools
{
    namespace utils
    {

		typedef boost::coroutines2::coroutine<uint32_t> coro_ip_long_t;

		typedef coro_ip_long_t::push_type IpLongProductor;
		typedef coro_ip_long_t::pull_type IpLongConsumer;

		typedef boost::coroutines2::coroutine<string> coro_string_t;

		typedef coro_string_t::push_type StringProductor;
		typedef coro_string_t::pull_type StringConsumer;

		class IpGenerator
		{
		public:
			IpGenerator(const string &ipRange, int stepSize)
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

				stepSize_ = stepSize;
			}

			void genIpRange(StringProductor &yield)
			{
				int i = 0;

				assert(ipLongEnd_ < 0xffffffff);

				while (i < stepSize_ && ipLongBegin_ <= ipLongEnd_)
				{
					yield(long2ip(ipLongBegin_));

					i++;
					ipLongBegin_++;
				}
			}

			bool hasNext()
			{
				return ipLongBegin_ <= ipLongEnd_;
			}

			string getLastIp()
			{
				return long2ip(ipLongBegin_ - 1);
			}

			string getNextIp()
			{
				return long2ip(ipLongBegin_);
			}

			string getEndIp()
			{
				return long2ip(ipLongEnd_);
			}

		private:
			uint32_t ipLongBegin_;
			uint32_t ipLongEnd_;
			int stepSize_;

			/********************** static functions at below **********************/
		public:

			static uint32_t ip2long(const string &ipString)
			{
				// use inet_addr() instead of inet_pton() for XP compatibility
				return ntohl(inet_addr(ipString.c_str()));
			}

			static string long2ip(const uint32_t &ipLong)
			{
				struct in_addr addr;
				addr.s_addr = htonl(ipLong);

				// use inet_ntoa() instead of inet_ntop() for XP compatibility
				return string(inet_ntoa(std::move(addr)));
			}

			static void splitIpRange(const string &ipRangeString, string &begin, string &end)
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
		}; // end of class

    } // namespace utils
} // namespace btctools