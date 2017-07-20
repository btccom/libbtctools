#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string.h>
#include <btctools/utils/Crypto.h>

using namespace std;
using namespace CryptoPP;

using Crypto = btctools::utils::Crypto;

string readFileIntoString(const string &filename)
{
	ifstream ifile(filename, std::ios::binary);
	ostringstream buf;
	char ch;
	
	while (buf && ifile.get(ch))
	{
		buf.put(ch);
	}

	ifile.close();

	return buf.str();
}

void writeStringToFile(const string &filename, const string &data)
{
	std::ofstream ofile(filename, std::ios::binary);
	ofile.write(data.c_str(), data.size());
	ofile.close();
}

void help(const char *procName)
{
	cerr << "Usage: " << procName << " [encrypt|e|decrypt|d|sign|s|verify|v] <key-path> <in-file-path> <out-file-path>" << endl;
}
  
int main(int argc, char *argv[])  
{
    try
    {
		const char *procName = argv[0];

		if (argc != 5)
		{
			help(procName);
			return -1;
		}

		string action = argv[1];
		string keyPath = argv[2];
		string inFilePath = argv[3];
		string outFilePath = argv[4];

		string keyData = readFileIntoString(keyPath);
		string inData = readFileIntoString(inFilePath);

		if (action == "encrypt" || action == "e")
		{
			auto key = Crypto::rsaStringToPublicKey(keyData);
			auto result = Crypto::rsaPublicKeyEncrypt(key, inData);
			writeStringToFile(outFilePath, result);
		}
		else if (action == "decrypt" || action == "d")
		{
			auto key = Crypto::rsaStringToPrivateKey(keyData);
			auto result = Crypto::rsaPrivateKeyDecrypt(key, inData);
			writeStringToFile(outFilePath, result);
		}
		else if (action == "sign" || action == "s")
		{
			auto key = Crypto::rsaStringToPrivateKey(keyData);
			auto result = Crypto::rsaPrivateKeySign(key, inData);
			writeStringToFile(outFilePath, result);
		}
		else if (action == "verify" || action == "v")
		{
			auto key = Crypto::rsaStringToPublicKey(keyData);
			auto result = Crypto::rsaPublicKeyVerify(key, inData);
			writeStringToFile(outFilePath, result);
		}
		else
		{
			cerr << "Unknown action : " << action << endl;
			help(procName);
			return -1;
		}

        return 0;
    }
    catch(CryptoPP::Exception const &e)
    {
        cerr << "\nCryptoPP::Exception caught: " << e.what() << endl;
        return -2;
    }
    catch(std::exception const &e)
    {
		cerr << "\nstd::exception caught: " << e.what() << endl;
        return -2;
    }

	return -3;
}
