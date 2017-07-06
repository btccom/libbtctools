#pragma once

#include "common.h"

namespace btctools
{
    namespace tcpclient
    {
		class Session : public std::enable_shared_from_this<Session>
		{
		public:
			Session(boost::asio::io_service &io_service, ResponseYield &responseYield);
			~Session();
			void run(Request *request);

		protected:
			void run(Request *request, int session_timeout);
			void run(Request * request, int session_timeout, int delay_timeout);
			void setTimeout(int timeout);
			void writeContent();
			void readContent();
			void clean();
			void yield(boost::system::error_code ec);

		private:
			const int BUFFER_SIZE = 8192;

			bool running_;

			boost::asio::ip::tcp::socket *socket_;
			Request *request_;
			Response *response_;

			char *buffer_;
			boost::asio::deadline_timer *session_timer_;
			boost::asio::deadline_timer *delay_timer_;

			boost::asio::io_service &io_service_;
			ResponseYield &responseYield_;
		};

    } // namespace tcpclient
} // namespace btctools