#include <windows.h>
#include <wincrypt.h>
#include <string>
#include <iostream>
#include <fstream>
#include <string.h>
#include <btctools/utils/Crypto.h>
#include <cryptopp/osrng.h>
#include <cryptopp/pssr.h>
#include <cryptopp/filters.h>

using namespace std;
using namespace CryptoPP;

using Crypto = btctools::utils::Crypto;
  
int main(int argc, char *argv[])  
{
    try  
    {  
		const char *privKeyBegin = "-----BEGIN RSA PRIVATE KEY-----\n";
		const char *privKeyEnd = "-----END RSA PRIVATE KEY-----";
		const char *pubKeyBegin = "-----BEGIN RSA PUBLIC KEY-----\n";
		const char *pubKeyEnd = "-----END RSA PUBLIC KEY-----";

		auto keyPair = Crypto::rsaGenerateKey(4096);

		RSA::PrivateKey privateKey = keyPair.first;
		RSA::PublicKey publicKey = keyPair.second;

		string privRaw = Crypto::rsaPrivateKeyToString(privateKey);
		string privHex = Crypto::bin2hex(privRaw);
		string privBase64 = Crypto::base64Encode(privRaw, true);

		string pubRaw = Crypto::rsaPublicKeyToString(publicKey);
		string pubHex = Crypto::bin2hex(pubRaw);
		string pubBase64 = Crypto::base64Encode(pubRaw, true);

		// private key

		std::ofstream privRawFile("./private-key-raw.dat", std::ios::binary);
		privRawFile.write(privRaw.c_str(), privRaw.size());
		privRawFile.close();

		std::ofstream privHexFile("./private-key-hex.txt", std::ios::binary);
		privHexFile.write(privHex.c_str(), privHex.size());
		privHexFile.close();

		std::ofstream privPemFile("./private-key.pem", std::ios::binary);
		privPemFile.write(privKeyBegin, strlen(privKeyBegin));
		privPemFile.write(privBase64.c_str(), privBase64.size());
		privPemFile.write(privKeyEnd, strlen(privKeyEnd));
		privPemFile.close();

		// public key

		std::ofstream pubRawFile("./public-key-raw.dat", std::ios::binary);
		pubRawFile.write(privRaw.c_str(), pubRaw.size());
		pubRawFile.close();

		std::ofstream pubHexFile("./public-key-hex.txt", std::ios::binary);
		pubHexFile.write(privHex.c_str(), pubHex.size());
		pubHexFile.close();

		/*
		* Run the command to convert RSA public key to SSL public key so OpenSSL can load it:
		*
		* openssl rsa -in public-key.pem -RSAPublicKey_in -pubout
		*/
		std::ofstream pubPemFile("./public-key.pem", std::ios::binary);
		pubPemFile.write(pubKeyBegin, strlen(pubKeyBegin));
		pubPemFile.write(pubBase64.c_str(), pubBase64.size());
		pubPemFile.write(pubKeyEnd, strlen(pubKeyEnd));
		pubPemFile.close();

        return 0;
    }  
    catch(CryptoPP::Exception const &e)  
    {  
        cout << "\nCryptoPP::Exception caught: " << e.what() << endl;  
        return -1;  
    }  
    catch(std::exception const &e)  
    {  
        cout << "\nstd::exception caught: " << e.what() << endl;  
        return -2;  
    }

    return -3;  
}
