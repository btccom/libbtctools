utils = require "utils.utils"
http = require "utils.http"
date = require "utils.date"

require 'utils.oop'
require 'HelperBase'
require 'ExecutorBase'
require 'configurator.AntminerHttpCgi'
require 'configurator.BosHttpLuci'
require 'configurator.WhatsMinerHttpsLuci'
--require 'configurator.AvalonHttpLuci'

ConfiguratorHelper = oo.class({}, HelperBase)

function ConfiguratorHelper:newExecutor(context)
    local typeStr = context:miner():typeStr()
    if _G[typeStr] then
        return _G[typeStr](self, context)
    end
    throw(Exception("Don't support: " .. typeStr))
end

function makeRequest(context)
    ConfiguratorHelper:makeRequest(context)
end

function makeResult(context, response, stat)
    ConfiguratorHelper:makeResult(context, response, stat)
end
