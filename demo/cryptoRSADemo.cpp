#ifdef _WIN32
 #include <windows.h>
 #include <wincrypt.h>
#endif

#include <string>
#include <iostream>
#include "utils/Crypto.h"
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
		////////////////////////////////////////////////
		// Generate keys
		AutoSeededRandomPool rng;

		auto keyPair = Crypto::rsaGenerateKey(4096);
		RSA::PrivateKey privateKey = keyPair.first;
		RSA::PublicKey publicKey = keyPair.second;

		string strPriv = Crypto::rsaPrivateKeyToString(privateKey);
		RSA::PrivateKey Priv = Crypto::rsaStringToPrivateKey(strPriv);

		cout << Crypto::bin2hex(strPriv) << endl;
		cout << endl;
		cout << Crypto::bin2hex(Crypto::hex2bin(Crypto::bin2hex(strPriv))) << endl;

		////////////////////////////////////////////////

		cout << endl << endl << endl;

		// Setup
		string message = "RSA-PSSR Test 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", signature, recovered;

		cout << message << endl;

		////////////////////////////////////////////////
		// Sign and Encode
		signature = Crypto::rsaPrivateKeySign(privateKey, message);

		cout << Crypto::bin2hex(signature) << endl;

		   ////////////////////////////////////////////////
		   // Verify and Recover
		recovered = Crypto::rsaPublicKeyVerify(publicKey, signature);

		cout << recovered << endl;

		cout << "Verified signature on message" << endl;

		/////////////////////////////////////////////////////////////////////////////////////////

		cout << endl << endl << endl;

		////////////////////////////////////////////////

		string plain = "RSA Encryption 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", cipher, rec2;

		////////////////////////////////////////////////
		// Encryption
		cipher = Crypto::rsaPublicKeyEncrypt(publicKey, plain);

		////////////////////////////////////////////////
		// Decryption
		rec2 = Crypto::rsaPrivateKeyDecrypt(Priv, cipher);

		cout << plain << endl;
		cout << Crypto::bin2hex(cipher) << endl;
		cout << rec2 << endl;

		if (plain == rec2)
		{
			cout << "ok" << endl;
		}


		/////////////////////////////////////////////////////////////////////////////////////////

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
	catch (...)
	{
		cout << "\nunknown exception caught." << endl;
		return -3;
	}

	cout << "enter to exit" << endl;

	char x[1];
	cin.getline(x, 1);
    return 0;  
}
