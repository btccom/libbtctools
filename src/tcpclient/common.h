#ifndef BTCTOOLS_TCPCLIENT_COMMON
#define BTCTOOLS_TCPCLIENT_COMMON

#include <iostream>
#include <string>

#include <boost/system/system_error.hpp>
#include <boost/coroutine2/all.hpp>
/*
#include <boost/asio.hpp>
#include <boost/asio/io_service.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include <boost/asio/steady_timer.hpp>
#include <boost/asio/write.hpp>

#include <boost/coroutine2/all.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/algorithm/string.hpp>
*/

namespace btctools
{
    namespace tcpclient
    {
        using std::string;

		class Client;
		class Session;

        struct Request
        {
            string host_;
            string port_;
            string content_;
			int session_timeout_;
			int delay_timeout_;
            const void *usrdata_; // 用户自定义数据
			bool is_final_; // 是否为该Session的最后一个请求（请求完成后即销毁Session）
        };

		struct Response
        {
            boost::system::error_code error_code_;
            string content_;
			std::shared_ptr<Session> session_; //Response对应的Session
            const void *usrdata_; // Request中的usrdata_会被复制到对应的Response中
			bool is_final_; // 是否为该Session的最后一个响应（此时Session已被销毁）
        };

        using coro_request_t = boost::coroutines2::coroutine<Request*>;
        using coro_response_t = boost::coroutines2::coroutine<Response*>;

        using RequestYield = coro_request_t::push_type;
        using RequestSource = coro_request_t::pull_type;

        using ResponseYield = coro_response_t::push_type;
        using ResponseSource = coro_response_t::pull_type;

    } // namespace tcpclient
} // namespace btctools

#endif //BTCTOOLS_TCPCLIENT_COMMON
