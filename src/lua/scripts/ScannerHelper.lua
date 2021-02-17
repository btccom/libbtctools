utils = require "utils.utils"
http = require "utils.http"
date = require "utils.date"

require 'utils.oop'
require 'HelperBase'
require 'ExecutorBase'
require 'scanner.HttpAutoDetect'
require 'scanner.AntminerCgminerApi'
require 'scanner.AntminerHttpCgi'
require 'scanner.BosHttpLuci'
--require 'scanner.AvalonHttpLuci'

ScannerHelper = oo.class({}, HelperBase)

function ScannerHelper:newExecutor(context)
    return HttpAutoDetect(self, context)
end

function makeRequest(context)
    ScannerHelper:makeRequest(context)
end

function makeResult(context, response, stat)
    ScannerHelper:makeResult(context, response, stat)
end
