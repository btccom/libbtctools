#include <windows.h>
#include <wincrypt.h>
#include <string>
#include <iostream>
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
		// Setup
		string message = "RSA-PSSR Test", signature, recovered;

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


		////////////////////////////////////////////////

		string plain = "RSA Encryption", cipher, rec2;

		////////////////////////////////////////////////
		// Encryption
		cipher = Crypto::rsaPublicKeyEncrypt(publicKey, plain);

		////////////////////////////////////////////////
		// Decryption
		rec2 = Crypto::rsaPrivateKeyDecrypt(Priv, cipher);

		cout << plain << endl;
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
