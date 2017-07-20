#pragma once

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include <string>
#include <cryptopp/sha.h>
#include <cryptopp/md5.h>
#include <cryptopp/base64.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/hex.h>
#include <cryptopp/randpool.h>
#include <cryptopp/rsa.h>

namespace btctools
{
	namespace utils
	{
        using string = std::string;

		class Crypto
		{
		public:
			static string md5(const string &str);

			static string sha1(const string &str);
			static string sha256(const string &str);

			static string base64Encode(const string &str);
			static string base64Decode(const string &encodedStr);

			static string bin2hex(const byte bArray[], int bArray_len);

			//******* the RSA code copied from <http://blog.csdn.net/phker/article/details/5056288> *******

			//You must set the KeyLength 512, 1024, 2048 ...  
			void rsaGenerateKey(const unsigned int KeyLength, const char *Seed, CryptoPP::RSAES_OAEP_SHA_Decryptor &Priv, CryptoPP::RSAES_OAEP_SHA_Encryptor &Pub);
			void rsaGenerateKey(const unsigned int KeyLength, const char *Seed, string &strPriv, string &strPub);

			//use public key to encrypt  
			void rsaEncryptString(const CryptoPP::RSAES_OAEP_SHA_Encryptor &Pub, const char *Seed, const string &Plaintext, string &Ciphertext);
			void rsaEncryptString(const string &strPub, const char *Seed, const string &Plaintext, string &Ciphertext);

			//use private key to decrypt  
			void rsaDecryptString(const CryptoPP::RSAES_OAEP_SHA_Decryptor &Priv, const string &Ciphertext, string &Plaintext);
			void rsaDecryptString(const string &strPriv, const string &Ciphertext, string &Plaintext);

		private:
			static CryptoPP::RandomPool & rsaRNG(void);

		private:
			static CryptoPP::RandomPool m_rsaRandPool;
		}; // class end

	} // namespace utils
} // namespace btctools