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

		struct Session
		{
			Session(tcp::socket *socket, Request *request, Response *response, ResponseProductor &responseProductor)
				:socket_(socket), request_(request), response_(response),
				responseProductor_(responseProductor)
			{}

			void run()
			{
				buffer_ = new char[BUFFER_SIZE];
				writeContent();
			}

			void writeContent()
			{
				boost::asio::async_write(*socket_, boost::asio::buffer(request_->content_), [this](const boost::system::error_code& ec,
					std::size_t bytes_transferred)
				{
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
				socket_->async_read_some(boost::asio::buffer(buffer_, BUFFER_SIZE),
					[&](const boost::system::error_code& ec,
						std::size_t bytes_transferred)
				{
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
				delete buffer_;
				delete socket_;
			}

			void yield(boost::system::error_code ec)
			{
				clean();
				response_->error_code_ = ec;
				responseProductor_(response_);
				delete this;
			}

			const int BUFFER_SIZE = 8192;

			tcp::socket *socket_;
			Request *request_;
			Response *response_;

			char *buffer_;

			ResponseProductor &responseProductor_;
		};

        class Client
        {
        public:
            Client()
            {}

            void run(RequestConsumer &source, ResponseProductor &yield)
            {
                while (source)
                {
                    Request *request = source.get();

                    tcp::resolver resolver(io_service_);
                    auto endpoint_iterator = resolver.resolve({ request->host_, request->port_ });

                    boost::system::error_code ec;
                    tcp::socket *socket = new tcp::socket(io_service_);

					boost::asio::async_connect(*socket, endpoint_iterator, [socket, request, &yield](
						const boost::system::error_code& ec,
						tcp::resolver::iterator)
					{
						Response *response = new Response;
						response->usrdata_ = request->usrdata_;

						if (!ec)
						{
							(new Session(socket, request, response, yield))->run();
						}
						else
						{
							delete socket;
							response->error_code_ = ec;

							yield(response);
						}
					});

					source();
                }

                io_service_.run();
            }

        private:
            boost::asio::io_service io_service_;
        };

    } // namespace tcpclient
} // namespace btctools