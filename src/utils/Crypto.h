#ifndef BTCTOOLS_UTILS_CRYPTO
#define BTCTOOLS_UTILS_CRYPTO

#include <string>
#include <cryptopp/rsa.h>

namespace btctools
{
	namespace utils
	{
        using std::string;
		using RsaKeyPair = std::pair<CryptoPP::RSA::PrivateKey, CryptoPP::RSA::PublicKey>;

		class Crypto
		{
		public:
			static string md5(const string &str);

			static string sha1(const string &str);
			static string sha256(const string &str);

			static string base64Encode(const string &str, bool insertLineBreaks = false, int maxLineLength = 72);
			static string base64Decode(const string &encodedStr);

			static string bin2hex(const byte bArray[], int bArray_len);
			static string bin2hex(string bin, bool uppercase = false);
			static string hex2bin(string hex);


			//******* the RSA code referrered from <https://www.cryptopp.com/wiki/RSA_Signature_Schemes> *******
			//******* and <https://www.cryptopp.com/wiki/RSA_Encryption_Schemes> *******
			//******* See also: Keys and Formats <https://www.cryptopp.com/wiki/Keys_and_Formats> *******

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

#endif //BTCTOOLS_UTILS_CRYPTO
