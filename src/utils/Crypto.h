#pragma once

#define CRYPTOPP_ENABLE_NAMESPACE_WEAK 1

#include <string>
#include <utility>
#include <cryptopp/sha.h>
#include <cryptopp/md5.h>
#include <cryptopp/base64.h>
#include <cryptopp/files.h>
#include <cryptopp/filters.h>
#include <cryptopp/hex.h>
#include <cryptopp/randpool.h>
#include <cryptopp/rsa.h>
#include <cryptopp/osrng.h>
#include <cryptopp/pssr.h>
#include <cryptopp/filters.h>

namespace btctools
{
	namespace utils
	{
        using string = std::string;
		using RsaKeyPair = std::pair<CryptoPP::RSA::PrivateKey, CryptoPP::RSA::PublicKey>;

		class Crypto
		{
		public:
			static string md5(const string &str);

			static string sha1(const string &str);
			static string sha256(const string &str);

			static string base64Encode(const string &str, bool insertLineBreaks = false);
			static string base64Decode(const string &encodedStr);

			static string bin2hex(const byte bArray[], int bArray_len);
			static string bin2hex(string bin, bool uppercase = false);
			static string hex2bin(string hex);


			//******* the RSA code referrered from <https://www.cryptopp.com/wiki/RSA_Signature_Schemes> *******
			//******* and <https://www.cryptopp.com/wiki/RSA_Encryption_Schemes> *******

			//You must set the keyLength 512, 1024, 2048 ...
			static RsaKeyPair rsaGenerateKey(const unsigned int keyLength);
			static string rsaPrivateKeyToString(const CryptoPP::RSA::PrivateKey &privateKey);
			static string rsaPublicKeyToString(const CryptoPP::RSA::PublicKey &publicKey);
			static CryptoPP::RSA::PrivateKey rsaStringToPrivateKey(const string &privateKeyStr);
			static CryptoPP::RSA::PublicKey rsaStringToPublicKey(const string &publicKeyStr);
			static string rsaPublicKeyEncrypt(const CryptoPP::RSA::PublicKey &publicKey, string data);
			static string rsaPrivateKeyDecrypt(const CryptoPP::RSA::PrivateKey &privateKey, string encryptedData);
			static string rsaPrivateKeySign(const CryptoPP::RSA::PrivateKey &privateKey, string data);
			static string rsaPublicKeyVerify(const CryptoPP::RSA::PublicKey &publicKey, string signedData);

		}; // class end

	} // namespace utils
} // namespace btctools