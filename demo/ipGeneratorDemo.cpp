#include <iostream>
#include "utils/IpGenerator.h"

#ifdef _WIN32
 #include <windows.h>
#endif

using namespace std;
using namespace btctools::utils;

int main()
{
	IpGeneratorGroup ipg;

	ipg.addIpRange("192.168.1.1-192.168.2.254");
	/*ipg.addIpRange("192.168.1.1-192.168.1.3");
	ipg.addIpRange("192.168.2.10-192.168.2.100");
	ipg.addIpRange("192.168.3.1-192.168.3.255");*/

	cout << ipg.getIpNumber() << endl;

	/*auto sourceAll = ipg.genIpRange();

	for (auto ip : sourceAll)
	{
		cout << ip << endl;
	}*/

	auto source1 = ipg.genIpRange(20);

	for (auto ip : source1)
	{
		cout << ip << endl;
	}

	cout << "-------------------------------------------" << endl;

	auto source2 = ipg.genIpRange(30);

	cout << "lastIp" << ipg.getLastIp() << endl;
	cout << "nextIp" << ipg.getNextIp() << endl;

	for (auto ip : source2)
	{
		cout << ip << endl;
	}

	cout << "-------------------------------------------" << endl;

	auto sourceAll = ipg.genIpRange();

	for (auto ip : sourceAll)
	{
		cout << ip << endl;
	}

	cout << "\nDone" << endl;

#ifdef _WIN32
	::system("pause");
#endif

	return 0;
}