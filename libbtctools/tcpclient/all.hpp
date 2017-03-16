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
            string host_;
            string port_;
            string content_;
            const void *usrdata_;
        };

		struct Response
        {
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

    } // namespace tcpclient
} // namespace btctools

#include "Session.hpp"
#include "Client.hpp"
