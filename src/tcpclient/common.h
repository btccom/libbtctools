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
            
            // Used to support file upload HTTP requests (Reduce memory usage)
            // Replace replaceTag_ in content_ with file contents of filePath_
            bool fileUpload_ = false;
            string replaceTag_;
            string filePath_;

            int session_timeout_ = 0;
            int delay_timeout_ = 0;
            const void *usrdata_ = nullptr; // User-defined data
            bool is_final_ = false; // Whether it is the last request of the session (the session is destroyed after the request is completed)
        };

        struct Response
        {
            boost::system::error_code error_code_;
            string content_;
            std::shared_ptr<Session> session_; // Session of the Response
            const void *usrdata_ = nullptr; // The usrdata_ in the Request will be copied to its Response.
            bool is_final_ = false; // Whether it is the last response of the session (the session has been destroyed)
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
