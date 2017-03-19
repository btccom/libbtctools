#pragma once

#include <string>
#include <cryptopp/md5.h>

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