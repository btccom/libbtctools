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

		typedef boost::coroutines2::coroutine<in_addr> coro_in_addr_t;

		typedef coro_in_addr_t::push_type InAddrProductor;
		typedef coro_in_addr_t::pull_type InAddrConsumer;

		typedef boost::coroutines2::coroutine<string> coro_string_t;

		typedef coro_string_t::push_type StringProductor;
		typedef coro_string_t::pull_type StringConsumer;

		class IpGenerator
		{
		public:
			static void genIpRange(struct in_addr begin, struct in_addr end, InAddrProductor &yield)
			{
				struct in_addr currentIp;

				// to host endian
				begin.S_un.S_addr = ntohl(begin.S_un.S_addr);
				end.S_un.S_addr = ntohl(end.S_un.S_addr);

				if (begin.S_un.S_addr > end.S_un.S_addr)
				{
					boost::swap(begin, end);
				}

				for (auto i = begin.S_un.S_addr; i <= end.S_un.S_addr; i++)
				{
					// to network endian
					currentIp.S_un.S_addr = htonl(i);
					yield(std::move(currentIp));
				}
			}

			static void genIpRange(string begin, string end, StringProductor &yield)
			{
				struct in_addr beginInAddr;
				struct in_addr endInAddr;

				// use inet_addr() for XP compatibility
				beginInAddr.S_un.S_addr = inet_addr(begin.c_str());
				endInAddr.S_un.S_addr = inet_addr(end.c_str());

				InAddrConsumer source(
					[&](InAddrProductor &inAddrYield)
				{
					genIpRange(std::move(beginInAddr), std::move(endInAddr), inAddrYield);
				});

				for (auto inAddr : source)
				{
					// use inet_ntoa() for XP compatibility
					yield(string(inet_ntoa(inAddr)));
				}
			}
		};

    } // namespace utils
} // namespace btctools