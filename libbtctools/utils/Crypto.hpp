#pragma once

#include <string>
#include <cryptopp/md5.h>
#include <cryptopp/base64.h>

using namespace std;

namespace btctools
{
	namespace utils
	{

		class Crypto
		{
		public:
			static string md5(const string &str)
			{
				CryptoPP::MD5 md5;
				byte result[16];

				md5.Update((const byte*)str.c_str(), str.size());
				md5.Final(result);

				return bin2hex(result, sizeof(result));
			}

			static string base64Encode(const string &str)
			{
				CryptoPP::Base64Encoder encoder(NULL, false);

				encoder.Put((const byte*)str.c_str(), str.size());
				encoder.MessageEnd();

				auto size = encoder.MaxRetrievable();
				string encodedStr;

				if (size)
				{
					encodedStr.resize(size);
					encoder.Get((byte*)encodedStr.data(), encodedStr.size());
				}

				return std::move(encodedStr);
			}

			static string base64Decode(const string &encodedStr)
			{
				CryptoPP::Base64Decoder decoder;

				decoder.Put((const byte*)encodedStr.c_str(), encodedStr.size());
				decoder.MessageEnd();

				auto size = decoder.MaxRetrievable();
				string str;

				if (size)
				{
					str.resize(size);
					decoder.Get((byte*)str.data(), str.size());
				}

				return std::move(str);
			}

		protected:
			static string bin2hex(const byte bArray[], int bArray_len)
			{
				static char hexArray[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
				string strHex;
				int nIndex = 0;

				strHex.resize(bArray_len * 2);

				for (int i = 0; i<bArray_len; i++)
				{
					byte high = bArray[i] >> 4;
					byte low = bArray[i] & 0x0f;
					strHex[nIndex] = hexArray[high];
					strHex[nIndex + 1] = hexArray[low];
					nIndex += 2;
				}

				return std::move(strHex);
			}
		}; // class end

	} // namespace utils
} // namespace btctools