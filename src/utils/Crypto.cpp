#include "Crypto.h"

using namespace std;

namespace btctools
{
	namespace utils
	{

		string Crypto::md5(const string &str)
		{
			CryptoPP::Weak::MD5 md5;
			byte result[16];

			md5.Update((const byte*)str.c_str(), str.size());
			md5.Final(result);

			return bin2hex(result, sizeof(result));
		}

		string Crypto::sha1(const string & str)
		{
			CryptoPP::SHA1 sha1;
			
			byte result[20];

			sha1.Update((const byte*)str.c_str(), str.size());
			sha1.Final(result);

			return bin2hex(result, sizeof(result));
		}

		string Crypto::sha256(const string & str)
		{
			CryptoPP::SHA256 sha256;

			byte result[32];

			sha256.Update((const byte*)str.c_str(), str.size());
			sha256.Final(result);

			return bin2hex(result, sizeof(result));
		}

		string Crypto::base64Encode(const string &str, bool insertLineBreaks)
		{
			CryptoPP::Base64Encoder encoder(NULL, insertLineBreaks);

			encoder.Put((const byte*)str.c_str(), str.size());
			encoder.MessageEnd();

			unsigned int size = (unsigned int) encoder.MaxRetrievable();
			string encodedStr;

			if (size)
			{
				encodedStr.resize(size);
				encoder.Get((byte*)encodedStr.data(), encodedStr.size());
			}

			return std::move(encodedStr);
		}

		string Crypto::base64Decode(const string &encodedStr)
		{
			CryptoPP::Base64Decoder decoder;

			decoder.Put((const byte*)encodedStr.c_str(), encodedStr.size());
			decoder.MessageEnd();

			unsigned int size = (unsigned int) decoder.MaxRetrievable();
			string str;

			if (size)
			{
				str.resize(size);
				decoder.Get((byte*)str.data(), str.size());
			}

			return std::move(str);
		}

		string Crypto::bin2hex(const byte bArray[], int bArray_len)
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

		string Crypto::bin2hex(string bin, bool uppercase)
		{
			CryptoPP::HexEncoder encoder(NULL, uppercase);

			encoder.Put((const byte*)bin.c_str(), bin.size());
			encoder.MessageEnd();

			unsigned int size = (unsigned int)encoder.MaxRetrievable();
			string encodedStr;

			if (size)
			{
				encodedStr.resize(size);
				encoder.Get((byte*)encodedStr.data(), encodedStr.size());
			}

			return std::move(encodedStr);
		}

		string Crypto::hex2bin(string hex)
		{
			CryptoPP::HexDecoder decoder;

			decoder.Put((const byte*)hex.c_str(), hex.size());
			decoder.MessageEnd();

			unsigned int size = (unsigned int)decoder.MaxRetrievable();
			string str;

			if (size)
			{
				str.resize(size);
				decoder.Get((byte*)str.data(), str.size());
			}

			return std::move(str);
		}

		RsaKeyPair Crypto::rsaGenerateKey(const unsigned int keyLength)
		{
			CryptoPP::AutoSeededRandomPool rng;
			CryptoPP::InvertibleRSAFunction params;

			params.GenerateRandomWithKeySize(rng, keyLength);

			CryptoPP::RSA::PrivateKey privateKey(params);
			CryptoPP::RSA::PublicKey publicKey(params);

			return RsaKeyPair(std::move(privateKey), std::move(publicKey));
		}

		string Crypto::rsaPrivateKeyToString(const CryptoPP::RSA::PrivateKey &privateKey)
		{
			string str;
			privateKey.DEREncode(CryptoPP::StringSink(str));
			return std::move(str);
		}

		string Crypto::rsaPublicKeyToString(const CryptoPP::RSA::PublicKey &publicKey)
		{
			string str;
			publicKey.DEREncode(CryptoPP::StringSink(str));
			return std::move(str);
		}

		CryptoPP::RSA::PrivateKey Crypto::rsaStringToPrivateKey(const string &privateKeyStr)
		{
			CryptoPP::StringSource privateKeySource(privateKeyStr, true);
			CryptoPP::RSA::PrivateKey privateKey;

			privateKey.BERDecode(privateKeySource);
			return std::move(privateKey);
		}

		CryptoPP::RSA::PublicKey Crypto::rsaStringToPublicKey(const string &publicKeyStr)
		{
			CryptoPP::StringSource publicKeySource(publicKeyStr, true);
			CryptoPP::RSA::PublicKey publicKey;

			publicKey.BERDecode(publicKeySource);
			return std::move(publicKey);
		}

		string Crypto::rsaPublicKeyEncrypt(const CryptoPP::RSA::PublicKey &publicKey, string data)
		{
			CryptoPP::AutoSeededRandomPool rng;
			string encryptedData;

			CryptoPP::RSAES_OAEP_SHA_Encryptor e(publicKey);

			CryptoPP::StringSource ss(data, true,
				new CryptoPP::PK_EncryptorFilter(rng, e,
					new CryptoPP::StringSink(encryptedData)
				) // PK_EncryptorFilter
			); // StringSource

			return std::move(encryptedData);
		}

		string Crypto::rsaPrivateKeyDecrypt(const CryptoPP::RSA::PrivateKey &privateKey, string encryptedData)
		{
			CryptoPP::AutoSeededRandomPool rng;
			string data;

			CryptoPP::RSAES_OAEP_SHA_Decryptor d(privateKey);

			CryptoPP::StringSource ss4(encryptedData, true,
				new CryptoPP::PK_DecryptorFilter(rng, d,
					new CryptoPP::StringSink(data)
				) // PK_DecryptorFilter
			); // StringSource

			return std::move(data);
		}

		string Crypto::rsaPrivateKeySign(const CryptoPP::RSA::PrivateKey &privateKey, string data)
		{
			CryptoPP::AutoSeededRandomPool rng;
			string signedData;

			CryptoPP::RSASS<CryptoPP::PSSR, CryptoPP::SHA1>::Signer signer(privateKey);

			CryptoPP::StringSource ss(data, true,
				new CryptoPP::SignerFilter(rng, signer,
					new CryptoPP::StringSink(signedData),
					true // putMessage for recovery
				) // SignerFilter
			); // StringSource

			return std::move(signedData);
		}

		string Crypto::rsaPublicKeyVerify(const CryptoPP::RSA::PublicKey &publicKey, string signedData)
		{
			string data;

			CryptoPP::RSASS<CryptoPP::PSSR, CryptoPP::SHA1>::Verifier verifier(publicKey);

			CryptoPP::StringSource ss(signedData, true,
				new CryptoPP::SignatureVerificationFilter(
					verifier,
					new CryptoPP::StringSink(data),
					CryptoPP::HashVerificationFilter::Flags::THROW_EXCEPTION | CryptoPP::HashVerificationFilter::Flags::PUT_MESSAGE
				) // SignatureVerificationFilter
			); // StringSource

			return std::move(data);
		}

	} // namespace utils
} // namespace btctools
