#pragma once

#include "common.h"

namespace btctools
{
	namespace miner
	{
        using string = std::string;

		string& Pool::url()
		{
			return url_;
		}
		string& Pool::worker()
		{
			return worker_;
		}
		string& Pool::passwd()
		{
			return passwd_;
		}

		void Pool::setUrl(string url)
		{
			url_ = std::move(url);
		}
		void Pool::setWorker(string worker)
		{
			worker_ = std::move(worker);
		}
		void Pool::setPasswd(string passwd)
		{
			passwd_ = std::move(passwd);
		}


		string& Miner::ip()
		{
			return ip_;
		}
		string& Miner::stat()
		{
			return stat_;
		}
		string& Miner::typeStr()
		{
			return typeStr_;
		}
		string& Miner::fullTypeStr()
		{
			return fullTypeStr_;
		}
		Pool& Miner::pool1()
		{
			return pool1_;
		}
		Pool& Miner::pool2()
		{
			return pool2_;
		}
		Pool& Miner::pool3()
		{
			return pool3_;
		}
		string Miner::opt(const string &key) const
		{
			if (opts_.count(key))
			{
				return opts_.at(key);
			}
			else
			{
				return string("");
			}
		}

		void Miner::setIp(string ip)
		{
			ip_ = std::move(ip);
		}
		void Miner::setStat(string stat)
		{
			stat_ = std::move(stat);
		}
		void Miner::setTypeStr(string typeStr)
		{
			typeStr_ = std::move(typeStr);
		}
		void Miner::setFullTypeStr(string fullTypeStr)
		{
			fullTypeStr_ = std::move(fullTypeStr);
		}
		void Miner::setPool1(Pool pool1)
		{
			pool1_ = std::move(pool1);
		}
		void Miner::setPool2(Pool pool2)
		{
			pool2_ = std::move(pool2);
		}
		void Miner::setPool3(Pool pool3)
		{
			pool3_ = std::move(pool3);
		}
		void Miner::setOpt(const string &key, const string &value)
		{
			opts_[key] = value;
		}
        

		string& WorkContext::stepName()
		{
			return stepName_;
		}
		Miner& WorkContext::miner()
		{
			return miner_;
		}
		bool& WorkContext::canYield()
		{
			return canYield_;
		}
		string& WorkContext::requestHost()
		{
			return request_.host_;
		}
		string& WorkContext::requestPort()
		{
			return request_.port_;
		}
		string& WorkContext::requestContent()
		{
			return request_.content_;
		}
		int WorkContext::requestSessionTimeout()
		{
			return request_.session_timeout_;
		}
		int WorkContext::requestDelayTimeout()
		{
			return request_.delay_timeout_;
		}

		void WorkContext::setStepName(string stepName)
		{
			stepName_ = std::move(stepName);
		}
		void WorkContext::setMiner(Miner miner)
		{
			miner_ = std::move(miner);
		}
		void WorkContext::setCanYield(bool canYield)
		{
			canYield_ = std::move(canYield);
		}
		void WorkContext::setRequestHost(string host)
		{
			request_.host_ = std::move(host);
		}
		void WorkContext::setRequestPort(string port)
		{
			request_.port_ = std::move(port);
		}
		void WorkContext::setRequestContent(string content)
		{
			request_.content_ = std::move(content);
		}
		void WorkContext::setRequestSessionTimeout(int timeout)
		{
			request_.session_timeout_ = timeout;
		}
		void WorkContext::setRequestDelayTimeout(int timeout)
		{
			request_.delay_timeout_ = timeout;
		}

	} // namespace tcpclient
} // namespace btctools
