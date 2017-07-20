#include <windows.h>
#include <wincrypt.h>
#include <string>
#include <iostream>  
#include <btctools/utils/Crypto.h>

using namespace std;
using namespace CryptoPP;
  
/***** STATIC VARIABLES *****/  
static RSAES_OAEP_SHA_Encryptor g_Pub;
static RSAES_OAEP_SHA_Decryptor g_Priv;
static string g_strPub;  
static string g_strPriv;  

/* the code copied from <http://blog.csdn.net/phker/article/details/5056288> */

int main(int argc, char *argv[])  
{  
    try  
    {  
        char Seed[1024], Message[1024], MessageSeed[1024];  
        unsigned int KeyLength;  
        btctools::utils::Crypto MyRSA;
		HCRYPTPROV   hCryptProv;


		if (CryptAcquireContext(
			&hCryptProv,
			NULL,
			NULL,
			PROV_RSA_FULL,
			0))
		{
			printf("CryptAcquireContext succeeded. \n");
		}
		else
		{
			printf("Error during CryptAcquireContext!\n");
			return -1;
		}

		if (CryptGenRandom(hCryptProv, 1024, (BYTE*)Seed) && 
		    CryptGenRandom(hCryptProv, 1024, (BYTE*)MessageSeed))
		{
			printf("get random data success\n");
		}
		else
		{
			printf("get random data failed\n");
		}

		if (CryptReleaseContext(hCryptProv, 0)) {
			printf("The handle has been released.\n\n");
		}
		else {
			printf("The handle could not be released.\n\n");
		}

  
        cout << "Key length in bits: ";  
        cin >> KeyLength;  
  
        cout << "\nMessage: ";  
        ws(cin);      
        cin.getline(Message, 1024);      
  
        //MyRSA.rsaGenerateKey(KeyLength, Seed, g_Priv, g_Pub);  
        MyRSA.rsaGenerateKey(KeyLength, Seed, g_strPriv, g_strPub);  
  
        //If generate key in RSAES_OAEP_SHA_Encryptor and RSAES_OAEP_SHA_Decryptor, please note four lines below  
         
        cout << "g_strPub = " << g_strPub << endl; 
        cout << endl; 
        cout << "g_strPriv = " << g_strPriv << endl; 
        cout << endl; 
        
          
        string Plaintext(Message);  
        string Ciphertext;  
        //MyRSA.rsaEncryptString(g_Pub, MessageSeed, Plaintext, Ciphertext);
        MyRSA.rsaEncryptString(g_strPub, MessageSeed, Plaintext, Ciphertext);  
        cout << "\nCiphertext: " << Ciphertext << endl;  
        cout << endl;
  
		string Decrypted;  
        //MyRSA.rsaDecryptString(g_Priv, Ciphertext, Decrypted);
        MyRSA.rsaDecryptString(g_strPriv, Ciphertext, Decrypted);  
        cout << "\nDecrypted: " << Decrypted << endl;  

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
