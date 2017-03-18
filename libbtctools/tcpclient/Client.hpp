#pragma once

#include <iostream>
#include <sstream>
#include <memory>
#include <string>
#include <vector>

#include <boost/asio.hpp>
#include <boost/asio/io_service.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/steady_timer.hpp>
#include <boost/asio/write.hpp>

#include <boost/coroutine2/all.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>

#include "all.hpp"

using namespace std;
using boost::asio::ip::tcp;

namespace btctools
{
    namespace tcpclient
    {
        class Client
        {
        public:
            Client(int session_timeout = 0)
				:session_timeout_(session_timeout),
				yield_(nullptr)
            {}

			void addWork(Request *request, ResponseYield &yield)
			{
				std::make_shared<Session>(io_service_, yield)->run(request, session_timeout_);

				yield_ = &yield;
			}

			void addWork(Request *request)
			{
				assert(yield_ != nullptr);

				addWork(request, *yield_);
			}

			void run()
			{
				io_service_.run();
			}

            void run(RequestSource &source, ResponseYield &yield)
            {
                while (source)
                {
                    Request *request = source.get();

					addWork(request, yield);

					source();
                }

				run();
            }

			ResponseSource run(RequestSource &source)
			{
				return ResponseSource([this, &source](ResponseYield &yield)
				{
					run(source, yield);
				});
			}

			void stop()
			{
				io_service_.stop();
			}

			bool stopped()
			{
				return io_service_.stopped();
			}

        private:
            boost::asio::io_service io_service_;
			int session_timeout_;
			ResponseYield *yield_;
        };

    } // namespace tcpclient
} // namespace btctools