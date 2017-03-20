#pragma once

#include <iostream>
#include <string>

#include <boost/asio.hpp>
#include <boost/asio/io_service.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/steady_timer.hpp>
#include <boost/asio/write.hpp>

#include <boost/coroutine2/all.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>

namespace btctools
{
    namespace tcpclient
    {
        using string = std::string;

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

        using coro_request_t = boost::coroutines2::coroutine<Request*>;
        using coro_response_t = boost::coroutines2::coroutine<Response*>;

        using RequestYield = coro_request_t::push_type;
        using RequestSource = coro_request_t::pull_type;

        using ResponseYield = coro_response_t::push_type;
        using ResponseSource = coro_response_t::pull_type;

    } // namespace tcpclient
} // namespace btctools
