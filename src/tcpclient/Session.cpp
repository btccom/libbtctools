#include <fstream>

#include <boost/asio.hpp>
#include <boost/asio/io_service.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include <boost/asio/steady_timer.hpp>
#include <boost/asio/write.hpp>

#include <boost/coroutine2/all.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/algorithm/string.hpp>

#include "Session.h"

using namespace std;
using boost::asio::ip::tcp;

namespace btctools
{
    namespace tcpclient
    {
	#if BOOST_VERSION >= 106600
		using tcpEndpoint = boost::asio::ip::tcp::endpoint;
	#else
		using tcpEndpoint = boost::asio::ip::tcp::resolver::iterator;
	#endif
        
		Session::Session(boost::asio::io_service &io_service, ResponseYield &responseYield)
			:socketTCP_(nullptr), socketSSL_(nullptr),
			request_(nullptr), response_(nullptr),
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

			if (socketTCP_ != nullptr)
			{
				delete socketTCP_;
				socketTCP_ = nullptr;
			}

			if (socketSSL_ != nullptr)
			{
				delete socketSSL_;
				socketSSL_ = nullptr;
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
			response_->session_ = self;
			response_->usrdata_ = request->usrdata_;

			string scheme = "tcp";
			string host = request->host_;
			
			auto pos = host.find("://");
			if (pos != string::npos) {
				scheme = host.substr(0, pos);
				boost::algorithm::to_lower(scheme);

				host = host.substr(pos + 3);
			}

			tcp::resolver resolver(io_service_);
			auto endpoint_iterator = resolver.resolve({ host, request->port_ });

			setTimeout(session_timeout);

			if (scheme == "tcp") {
				socketTCP_ = new tcp::socket(io_service_);

				boost::asio::async_connect(*socketTCP_, endpoint_iterator, [this, self](
					const boost::system::error_code& ec, tcpEndpoint)
				{
					if (!running_ || ec == boost::asio::error::operation_aborted)
					{
						return;
					}

					if (ec)
					{
						yield(ec);
						return;
					}

					writeContent(socketTCP_);
				});
			}
			else if (scheme == "ssl" || scheme == "tls") {
				boost::asio::ssl::context ctx(boost::asio::ssl::context::sslv23);
				socketSSL_ = new boost::asio::ssl::stream<boost::asio::ip::tcp::socket>(io_service_, ctx);
				socketSSL_->set_verify_mode(boost::asio::ssl::verify_none);

				boost::asio::async_connect(socketSSL_->lowest_layer(), endpoint_iterator, [this, self](
					const boost::system::error_code& ec, tcpEndpoint)
				{
					if (!running_ || ec == boost::asio::error::operation_aborted)
					{
						return;
					}

					if (ec)
					{
						yield(ec);
						return;
					}
					
					socketSSL_->async_handshake(boost::asio::ssl::stream_base::client, [this, self](
						const boost::system::error_code& ec)
					{
						if (!running_ || ec == boost::asio::error::operation_aborted)
						{
							return;
						}

						if (ec) {
							yield(ec);
							return;
						}

						writeContent(socketSSL_);
					});
				});
			}
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

    template<class T>
		void Session::writeContent(T* socket)
		{
			auto self(shared_from_this());

      if (request_->fileUpload_) {
        return writeFileContent(socket);
      }

			boost::asio::async_write(*socket, boost::asio::buffer(request_->content_),
				[this, self, socket](const boost::system::error_code& ec,
				    std::size_t bytes_transferred)
			{
				if (!running_ || ec == boost::asio::error::operation_aborted)
				{
					return;
				}

				// note: the end of stream becomes an error code `boost::asio::error::eof`
				if (ec) {
					yield(ec);
					return;
				}

				readContent(socket);
			});
		}

    template<class T>
    void Session::writeFileContent(T* socket, FileUploadStage stage, size_t replaceTagPos)
    {
      auto self(shared_from_this());

      switch (stage) {
      case FileUploadStage::BEFORE_FILE_UPLOAD:
      {
        if (request_->content_.empty() || request_->replaceTag_.empty()) {
          return writeFileContent(socket, FileUploadStage::IN_FILE_UPLOAD, string::npos);
        }

        size_t pos = request_->content_.find(request_->replaceTag_);
        if (pos == request_->content_.npos) {
          return writeFileContent(socket, FileUploadStage::IN_FILE_UPLOAD, string::npos);
        }

        // write the part before replaceTag
        boost::asio::async_write(*socket, boost::asio::buffer(request_->content_.data(), pos),
          [this, self, socket, pos](const boost::system::error_code& ec,
            std::size_t bytes_transferred)
        {
          if (!running_ || ec == boost::asio::error::operation_aborted) {
            return;
          }
          // note: the end of stream becomes an error code `boost::asio::error::eof`
          if (ec) {
            yield(ec);
            return;
          }

          writeFileContent(socket, FileUploadStage::IN_FILE_UPLOAD, pos);
        });
        return;
      }

      case FileUploadStage::IN_FILE_UPLOAD:
      {
        shared_ptr<ifstream> fs = make_shared<ifstream>(request_->filePath_, ios::binary);

        if (!*fs) {
          yield(boost::asio::error::not_found);
          return;
        }

        return writeFileContent(socket, fs, replaceTagPos);
      }

      case FileUploadStage::AFTER_FILE_UPLOAD:
      {
        if (replaceTagPos == string::npos) {
          return readContent(socket);
        }

        // write the part after replaceTag
        boost::asio::async_write(*socket, boost::asio::buffer(
          request_->content_.data() + replaceTagPos + request_->replaceTag_.size(),
          request_->content_.size() - replaceTagPos - request_->replaceTag_.size()),
          [this, self, socket](const boost::system::error_code& ec,
            std::size_t bytes_transferred)
        {
          if (!running_ || ec == boost::asio::error::operation_aborted) {
            return;
          }
          // note: the end of stream becomes an error code `boost::asio::error::eof`
          if (ec) {
            yield(ec);
            return;
          }

          readContent(socket);
        });
        return;
        }
      }
    }

    template<class T>
    void Session::writeFileContent(T* socket, shared_ptr<ifstream> fs, size_t replaceTagPos) {
      auto self(shared_from_this());

      fs->read(buffer_, BUFFER_SIZE);
      size_t bufLen = fs->gcount();

      if (bufLen == 0) {
        return writeFileContent(socket, FileUploadStage::AFTER_FILE_UPLOAD, replaceTagPos);
      }

      boost::asio::async_write(*socket, boost::asio::buffer(buffer_, bufLen),
        [this, self, socket, fs, replaceTagPos](const boost::system::error_code& ec,
          std::size_t bytes_transferred)
      {
        if (!running_ || ec == boost::asio::error::operation_aborted) {
          return;
        }
        // note: the end of stream becomes an error code `boost::asio::error::eof`
        if (ec) {
          yield(ec);
          return;
        }

        if (fs->eof()) {
          return writeFileContent(socket, FileUploadStage::AFTER_FILE_UPLOAD, replaceTagPos);
        }

        writeFileContent(socket, fs, replaceTagPos);
      });
    }

    template<class T>
		void Session::readContent(T* socket)
		{
			auto self(shared_from_this());

      socket->async_read_some(boost::asio::buffer(buffer_, BUFFER_SIZE),
				[this, self, socket](const boost::system::error_code& ec,
					std::size_t bytes_transferred)
			{
				if (!running_ || ec == boost::asio::error::operation_aborted)
				{
					return;
				}

				// note: the end of stream becomes an error code `boost::asio::error::eof`
				if (ec) {
					yield(ec);
					return;
				}

				response_->content_ += string(buffer_, bytes_transferred);
				readContent(socket);
			});
		}

		void Session::clean()
		{
			running_ = false;

			if (session_timer_ != nullptr)
			{
				session_timer_->cancel();
			}

			// Prevent shutdown() from throwing an exception
			boost::system::error_code ec;

			if (socketTCP_ != nullptr && socketTCP_->is_open())
			{
        socketTCP_->shutdown(boost::asio::ip::tcp::socket::shutdown_both, ec);
				socketTCP_->close();
			}

			if (socketSSL_ != nullptr && socketSSL_->lowest_layer().is_open())
			{
        socketSSL_->shutdown(ec);
        socketSSL_->lowest_layer().shutdown(boost::asio::ip::tcp::socket::shutdown_both, ec);
				socketSSL_->lowest_layer().close();
			}
		}

		void Session::yield(boost::system::error_code ec)
		{
			if (request_->is_final_ || ec) {
				response_->is_final_ = true;

				// close session
				clean();
			}
			else {
				response_->is_final_ = false;

				// cancel timer
				if (session_timer_ != nullptr)
				{
					session_timer_->cancel();
					session_timer_ = nullptr;
				}
			}

			response_->error_code_ = ec;
			responseYield_(response_);
		}

		void Session::resumeSession()
		{
			if (!running_) {
				return;
			}

			auto self(shared_from_this());

			// clear contents
			response_->content_.clear();

			setTimeout(request_->delay_timeout_);

			if (socketTCP_ != nullptr) {
				writeContent(socketTCP_);
			}
			else if (socketSSL_ != nullptr) {
				writeContent(socketSSL_);
			}
			else {
				yield(boost::asio::error::service_not_found);
			}
		}

    } // namespace tcpclient
} // namespace btctools
