#include "Session.h"

using namespace std;
using boost::asio::ip::tcp;

namespace btctools
{
    namespace tcpclient
    {
        
		Session::Session(boost::asio::io_service &io_service, ResponseYield &responseYield)
			:socket_(nullptr), request_(nullptr), response_(nullptr),
			running_(false), buffer_(nullptr),
			session_timer_(nullptr), delay_timer_(nullptr),
			io_service_(io_service), responseYield_(responseYield)
		{
			buffer_ = new char[BUFFER_SIZE];
		}

		Session::~Session()
		{
			// release them at the end
			// avoid access error from ASIO proactor.

			if (session_timer_ != nullptr)
			{
				delete session_timer_;
				session_timer_ = nullptr;
			}

			if (delay_timer_ != nullptr)
			{
				delete delay_timer_;
				delay_timer_ = nullptr;
			}

			if (socket_ != nullptr)
			{
				delete socket_;
				socket_ = nullptr;
			}

			if (buffer_ != nullptr)
			{
				delete buffer_;
				buffer_ = nullptr;
			}
		}

		void Session::run(Request * request)
		{
			run(request, request->session_timeout_, request->delay_timeout_);
		}

		void Session::run(Request *request, int session_timeout)
		{
			auto self(shared_from_this());

			running_ = true;

			request_ = request;
			response_ = new Response;
			response_->usrdata_ = request->usrdata_;

			tcp::resolver resolver(io_service_);
			auto endpoint_iterator = resolver.resolve({ request->host_, request->port_ });

			socket_ = new tcp::socket(io_service_);

			setTimeout(session_timeout);

			boost::asio::async_connect(*socket_, endpoint_iterator, [this, self](
				const boost::system::error_code& ec,
				tcp::resolver::iterator)
			{
				if (!running_ || ec == boost::asio::error::operation_aborted)
				{
					return;
				}

				if (!ec)
				{
					writeContent();
				}
				else
				{
					yield(ec);
				}
			});
		}

		void Session::run(Request *request, int session_timeout, int delay_timeout)
		{
			if (delay_timeout > 0)
			{
				auto self(shared_from_this());

				delay_timer_ = new boost::asio::deadline_timer(io_service_, boost::posix_time::seconds(delay_timeout));
				delay_timer_->async_wait([this, self, request, session_timeout](const boost::system::error_code &ec)
				{
					if (ec == boost::asio::error::operation_aborted)
					{
						return;
					}

					run(request, session_timeout);
				});
			}
			else
			{
				run(request, session_timeout);
			}
		}

		void Session::setTimeout(int timeout)
		{
			if (timeout > 0)
			{
				auto self(shared_from_this());

				session_timer_ = new boost::asio::deadline_timer(io_service_, boost::posix_time::seconds(timeout));
				session_timer_->async_wait([this, self](const boost::system::error_code &ec)
				{
					if (!running_ || ec == boost::asio::error::operation_aborted)
					{
						return;
					}

					yield(boost::asio::error::timed_out);
				});
			}
		}

		void Session::writeContent()
		{
			auto self(shared_from_this());

			boost::asio::async_write(*socket_, boost::asio::buffer(request_->content_),
				[this, self](const boost::system::error_code& ec,
				    std::size_t bytes_transferred)
			{
				if (!running_ || ec == boost::asio::error::operation_aborted)
				{
					return;
				}

				if (!ec)
				{
					readContent();
				}
				else // the end of stream becomes an error code `boost::asio::error::eof`
				{
					yield(ec);
				}
			});
		}

		void Session::readContent()
		{
			auto self(shared_from_this());

			socket_->async_read_some(boost::asio::buffer(buffer_, BUFFER_SIZE),
				[this, self](const boost::system::error_code& ec,
					std::size_t bytes_transferred)
			{
				if (!running_ || ec == boost::asio::error::operation_aborted)
				{
					return;
				}

				if (!ec)
				{
					response_->content_ += string(buffer_, bytes_transferred);
					readContent();
				}
				else // the end of stream becomes an error code `boost::asio::error::eof`
				{
					yield(ec);
				}
			});
		}

		void Session::clean()
		{
			running_ = false;

			if (session_timer_ != nullptr)
			{
				session_timer_->cancel();
			}

			if (socket_ != nullptr && socket_->is_open())
			{
				socket_->close();
			}
		}

		void Session::yield(boost::system::error_code ec)
		{
			clean();
			response_->error_code_ = ec;
			responseYield_(response_);
		}

    } // namespace tcpclient
} // namespace btctools
