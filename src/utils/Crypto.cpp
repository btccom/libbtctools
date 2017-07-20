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

		string Crypto::base64Encode(const string &str)
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

		string Crypto::base64Decode(const string &encodedStr)
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

		void Crypto::rsaGenerateKey(const unsigned int KeyLength, const char *Seed, CryptoPP::RSAES_OAEP_SHA_Decryptor &Priv, CryptoPP::RSAES_OAEP_SHA_Encryptor &Pub)
		{
			CryptoPP::RandomPool RandPool;
			RandPool.IncorporateEntropy((byte *)Seed, strlen(Seed));

			//generate private key  
			Priv = CryptoPP::RSAES_OAEP_SHA_Decryptor(RandPool, KeyLength);

			//generate public key using private key  
			Pub = CryptoPP::RSAES_OAEP_SHA_Encryptor(Priv);
		}

		void Crypto::rsaGenerateKey(const unsigned int KeyLength, const char *Seed, string &strPriv, string &strPub)
		{
			CryptoPP::RandomPool RandPool;
			RandPool.IncorporateEntropy((byte *)Seed, strlen(Seed));

			//generate private key  
			CryptoPP::RSAES_OAEP_SHA_Decryptor Priv(RandPool, KeyLength);
			CryptoPP::HexEncoder PrivateEncoder(new CryptoPP::StringSink(strPriv));//本博客作者加：就为了这句代码整整找了1天！  
			Priv.DEREncode(PrivateEncoder);
			PrivateEncoder.MessageEnd();

			//generate public key using private key  
			CryptoPP::RSAES_OAEP_SHA_Encryptor Pub(Priv);
			CryptoPP::HexEncoder PublicEncoder(new CryptoPP::StringSink(strPub));
			Pub.DEREncode(PublicEncoder);
			PublicEncoder.MessageEnd();
		}

		void Crypto::rsaEncryptString(const CryptoPP::RSAES_OAEP_SHA_Encryptor &Pub, const char *Seed, const string &Plaintext, string &Ciphertext)
		{
			CryptoPP::RandomPool RandPool;
			RandPool.IncorporateEntropy((byte *)Seed, strlen(Seed));

			int MaxMsgLength = Pub.FixedMaxPlaintextLength();
			for (int i = Plaintext.size(), j = 0; i > 0; i -= MaxMsgLength, j += MaxMsgLength)
			{
				string PartPlaintext = Plaintext.substr(j, MaxMsgLength);
				string PartCiphertext;
				CryptoPP::StringSource(PartPlaintext, true, new CryptoPP::PK_EncryptorFilter(RandPool, Pub, new CryptoPP::HexEncoder(new CryptoPP::StringSink(PartCiphertext))));
				Ciphertext += PartCiphertext;
			}
		}

		void Crypto::rsaEncryptString(const string &strPub, const char *Seed, const string &Plaintext, string &Ciphertext)
		{
			CryptoPP::StringSource PublicKey(strPub, true, new CryptoPP::HexDecoder);
			CryptoPP::RSAES_OAEP_SHA_Encryptor Pub(PublicKey);

			CryptoPP::RandomPool RandPool;
			RandPool.IncorporateEntropy((byte *)Seed, strlen(Seed));

			int MaxMsgLength = Pub.FixedMaxPlaintextLength();
			for (int i = Plaintext.size(), j = 0; i > 0; i -= MaxMsgLength, j += MaxMsgLength)
			{
				string PartPlaintext = Plaintext.substr(j, MaxMsgLength);
				string PartCiphertext;
				CryptoPP::StringSource(PartPlaintext, true, new CryptoPP::PK_EncryptorFilter(RandPool, Pub, new CryptoPP::HexEncoder(new CryptoPP::StringSink(PartCiphertext))));
				Ciphertext += PartCiphertext;
			}
		}

		void Crypto::rsaDecryptString(const CryptoPP::RSAES_OAEP_SHA_Decryptor &Priv, const string &Ciphertext, string &Plaintext)
		{
			//indicate the ciphertext in hexcode  
			int CiphertextLength = Priv.FixedCiphertextLength() * 2;
			for (int i = Ciphertext.size(), j = 0; i > 0; i -= CiphertextLength, j += CiphertextLength)
			{
				string PartCiphertext = Ciphertext.substr(j, CiphertextLength);
				string PartPlaintext;
				CryptoPP::StringSource(PartCiphertext, true, new CryptoPP::HexDecoder(new CryptoPP::PK_DecryptorFilter(rsaRNG(), Priv, new CryptoPP::StringSink(PartPlaintext))));
				Plaintext += PartPlaintext;
			}
		}

		void Crypto::rsaDecryptString(const string &strPriv, const string &Ciphertext, string &Plaintext)
		{
			CryptoPP::StringSource PrivKey(strPriv, true, new CryptoPP::HexDecoder);
			CryptoPP::RSAES_OAEP_SHA_Decryptor Priv(PrivKey);

			//indicate the ciphertext in hexcode  
			int CiphertextLength = Priv.FixedCiphertextLength() * 2;
			for (int i = Ciphertext.size(), j = 0; i > 0; i -= CiphertextLength, j += CiphertextLength)
			{
				string PartCiphertext = Ciphertext.substr(j, CiphertextLength);
				string PartPlaintext;
				CryptoPP::StringSource(PartCiphertext, true, new CryptoPP::HexDecoder(new CryptoPP::PK_DecryptorFilter(rsaRNG(), Priv, new CryptoPP::StringSink(PartPlaintext))));
				Plaintext += PartPlaintext;
			}
		}

		CryptoPP::RandomPool & Crypto::rsaRNG(void)
		{
			return m_rsaRandPool;
		}

		CryptoPP::RandomPool Crypto::m_rsaRandPool;

	} // namespace utils
} // namespace btctools
