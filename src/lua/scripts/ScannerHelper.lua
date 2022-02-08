utils = require "utils.utils"
http = require "utils.http"
date = require "utils.date"

require 'utils.oop'
require 'HelperBase'
require 'ExecutorBase'
require 'MiningProgram'
require 'scanner.HttpAutoDetect'
require 'scanner.GenericCgminerApi'
require 'scanner.AntminerHttpCgi'
require 'scanner.BosHttpLuci'
require 'scanner.WhatsMinerHttpsLuci'
require 'scanner.AvalonHttpLuci'
require 'scanner.AvalonDeviceCgi'
require 'scanner.AnthillOS'

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
