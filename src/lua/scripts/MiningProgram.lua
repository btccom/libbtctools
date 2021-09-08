MiningProgram = oo.class()

function MiningProgram:init(programs, bestProgram)
    self.programs = programs
    self:setBestProgram(bestProgram)
    self:reset()
end

-- Some WhatsMiners use btminer instead of cgminer, and the path is different.
-- This class is used to simplify the switching of such paths.
function MiningProgram:WhatsMinerDefault(bestProgram)
    self:init({
        "btminer",
        "cgminer"
    }, bestProgram)
end

function MiningProgram:setBestProgram(program)
    if not program then return end
    program = utils.trim(program)
    if program == "" then return end
    utils.removeByValue(self.programs, program)
    table.insert(self.programs, program)
end

function MiningProgram:reset()
    self.workingPrograms = utils.deepCopy(self.programs)
    self.currentProgram = nil
end

function MiningProgram:hasNext()
    return #self.workingPrograms > 0
end

function MiningProgram:getNext()
    self.currentProgram = table.remove(self.workingPrograms)
    return self.currentProgram
end

function MiningProgram:getCurrent()
    return self.currentProgram
end
