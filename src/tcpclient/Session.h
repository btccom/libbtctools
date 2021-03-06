#ifndef BTCTOOLS_TCPCLIENT_SESSION
#define BTCTOOLS_TCPCLIENT_SESSION

#include <functional>
#include <fstream>

#include <boost/asio/io_service.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl.hpp>
#include <boost/asio/steady_timer.hpp>

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
			
			// Resume the session. The request has been updated externally.
			// Resend the request and read the response (reuse the previous connection).
			void resumeSession();

		protected:
			void run(Request *request, int session_timeout);
			void run(Request * request, int session_timeout, int delay_timeout);
			void setTimeout(int timeout);

      template<class T>
			void writeContent(T *socket);

      enum class FileUploadStage {
        BEFORE_FILE_UPLOAD,
        IN_FILE_UPLOAD,
        AFTER_FILE_UPLOAD
      };

      template<class T>
      void writeFileContent(T* socket, FileUploadStage stage = FileUploadStage::BEFORE_FILE_UPLOAD, size_t replaceTagPos = string::npos);

      template<class T>
      void writeFileContent(T* socket, std::shared_ptr<std::ifstream> fs, size_t replaceTagPos);

      template<class T>
			void readContent(T *socket);
			
      void clean();
			void yield(boost::system::error_code ec);

		private:
			const int BUFFER_SIZE = 8192;

			bool running_;

			boost::asio::ip::tcp::socket *socketTCP_;
			boost::asio::ssl::stream<boost::asio::ip::tcp::socket> *socketSSL_;
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

#endif //BTCTOOLS_TCPCLIENT_SESSION
