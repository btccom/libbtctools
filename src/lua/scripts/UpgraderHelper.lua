require 'utils.log'

utils = require "utils.utils"
http = require "utils.http"
date = require "utils.date"

require 'utils.oop'
require 'HelperBase'
require 'ExecutorBase'
require 'MiningProgram'
require 'upgrader.AntminerHttpCgi'
require 'upgrader.BosHttpLuci'

UpgraderHelper = oo.class({}, HelperBase)

function UpgraderHelper:newExecutor(context)
    local typeStr = context:miner():typeStr()
    if _G[typeStr] then
        return _G[typeStr](self, context)
    end
    throw(Exception("Don't support: " .. typeStr))
end

function makeRequest(context)
    UpgraderHelper:makeRequest(context)
end

function makeResult(context, response, stat)
    UpgraderHelper:makeResult(context, response, stat)
end
