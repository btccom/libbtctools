utils = require "utils.utils"
http = require "utils.http"
date = require "utils.date"

require 'utils.oop'
require 'HelperBase'
require 'ExecutorBase'
require 'MiningProgram'
require 'rebooter.AntminerHttpCgi'
require 'rebooter.BosHttpLuci'
require 'rebooter.WhatsMinerHttpsLuci'
require 'rebooter.AvalonHttpLuci'
require 'rebooter.AvalonDeviceCgi'
require 'rebooter.AnthillOS'

RebooterHelper = oo.class({}, HelperBase)

function RebooterHelper:newExecutor(context)
    local typeStr = context:miner():typeStr()
    if _G[typeStr] then
        return _G[typeStr](self, context)
    end
    throw(Exception("Don't support: " .. typeStr))
end

function makeRequest(context)
    RebooterHelper:makeRequest(context)
end

function makeResult(context, response, stat)
    RebooterHelper:makeResult(context, response, stat)
end
