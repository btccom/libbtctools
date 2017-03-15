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

using namespace std;
using boost::asio::ip::tcp;

namespace btctools
{
    namespace tcpclient
    {

        struct Request
        {
            Request()
            {}
            Request(const string &host, const string &port, const string &content, const void *usrdata = nullptr)
                :host_(host), port_(port), content_(content), usrdata_(usrdata)
            {}

            string host_;
            string port_;
            string content_;
            const void *usrdata_;
        };

		struct Response
        {
            Response()
            {}
            Response(const boost::system::error_code &error_code, const string &content, const void *usrdata = nullptr)
                :error_code_(error_code), content_(content), usrdata_(usrdata)
            {}

            boost::system::error_code error_code_;
            string content_;
            const void *usrdata_;
        };

        typedef boost::coroutines2::coroutine<Request*> coro_request_t;
        typedef boost::coroutines2::coroutine<Response*> coro_response_t;

        typedef coro_request_t::push_type RequestProductor;
        typedef coro_request_t::pull_type RequestConsumer;

        typedef coro_response_t::push_type ResponseProductor;
        typedef coro_response_t::pull_type ResponseConsumer;

		struct Session : public std::enable_shared_from_this<Session>
		{
			Session(boost::asio::io_service &io_service, ResponseProductor &responseProductor)
				:socket_(nullptr), request_(nullptr), response_(nullptr),
				running_(false), session_timer_(nullptr), buffer_(nullptr),
				io_service_(io_service), responseProductor_(responseProductor)
			{}

			void run(Request *request, int session_timeout = 0)
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
						buffer_ = new char[BUFFER_SIZE];
						writeContent();
					}
					else
					{
						yield(ec);
					}
				});
			}

			void setTimeout(int timeout)
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

			void writeContent()
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

			void readContent()
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

			void clean()
			{
				running_ = false;

				if (session_timer_ != nullptr)
				{
					session_timer_->cancel();

					delete session_timer_;
					session_timer_ = nullptr;
				}

				if (socket_ != nullptr)
				{
					if (socket_->is_open())
					{
						socket_->close();
					}

					delete socket_;
					socket_ = nullptr;
				}

				if (buffer_ != nullptr)
				{
					delete buffer_;
					buffer_ = nullptr;
				}
			}

			void yield(boost::system::error_code ec)
			{
				clean();
				response_->error_code_ = ec;
				responseProductor_(response_);
			}

			const int BUFFER_SIZE = 8192;

			bool running_;

			tcp::socket *socket_;
			Request *request_;
			Response *response_;

			char *buffer_;
			boost::asio::deadline_timer *session_timer_;

			boost::asio::io_service &io_service_;
			ResponseProductor &responseProductor_;
		};

        class Client
        {
        public:
            Client(int session_timeout = 0)
				:session_timeout_(session_timeout),
				yield_(nullptr)
            {}

			void addWork(Request *request, ResponseProductor &yield)
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

            void run(RequestConsumer &source, ResponseProductor &yield)
            {
                while (source)
                {
                    Request *request = source.get();

					addWork(request, yield);

					source();
                }

				run();
            }

			ResponseConsumer run(RequestConsumer &source)
			{
				return ResponseConsumer([this, &source](ResponseProductor &yield)
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
			ResponseProductor *yield_;
        };

    } // namespace tcpclient
} // namespace btctools