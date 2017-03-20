#include "Session.h"
#include "Client.h"

using namespace std;
using boost::asio::ip::tcp;

namespace btctools
{
    namespace tcpclient
    {

        Client::Client(int session_timeout)
			:session_timeout_(session_timeout),
			yield_(nullptr)
        {}

		void Client::addWork(Request *request, ResponseYield &yield)
		{
			std::make_shared<Session>(io_service_, yield)->run(request, session_timeout_);

			yield_ = &yield;
		}

		void Client::addWork(Request *request)
		{
			assert(yield_ != nullptr);

			addWork(request, *yield_);
		}

		void Client::run()
		{
			io_service_.run();
		}

        void Client::run(RequestSource &source, ResponseYield &yield)
        {
            while (source)
            {
                Request *request = source.get();

				addWork(request, yield);

				source();
            }

			run();
        }

		ResponseSource Client::run(RequestSource &source)
		{
			return ResponseSource([this, &source](ResponseYield &yield)
			{
				run(source, yield);
			});
		}

		void Client::stop()
		{
			io_service_.stop();
		}

		bool Client::stopped()
		{
			return io_service_.stopped();
		}

    } // namespace tcpclient
} // namespace btctools
