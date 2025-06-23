local component = require("component")
local event = require("event")
local gpu = component.gpu
local reactor1 = component.br_reactor

local colors = {
    green = 0x00FF00,
    white = 0xFFFFFF,
    black = 0x000000,
    gray = 0x333333,
    dark_green = 0x007700,
    red = 0xFF0000,
    yellow = 0xFFFF00,
    blue = 0x5555FF
}

local ButtonAPI = {}

function ButtonAPI.create(x, y, w, h, text, marginLeft, marginRight, callback)
    return {
        x = x, y = y, width = w, height = h,
        text = text, 
        marginLeft = marginLeft or 0,
        marginRight = marginRight or 0,
        callback = callback,
        draw = function(self, active)
            local effectiveWidth = self.width - self.marginLeft - self.marginRight
            gpu.setBackground(active and colors.dark_green or colors.gray)
            gpu.fill(self.x + self.marginLeft, self.y, effectiveWidth, self.height, " ")
            gpu.setForeground(colors.white)
            local textX = self.x + self.marginLeft + math.floor((effectiveWidth - #self.text)/2)
            local textY = self.y + math.floor(self.height/2)
            gpu.set(textX, textY, self.text)
            gpu.setBackground(colors.black)
        end,
        checkClick = function(self, x, y)
            return x >= (self.x + self.marginLeft) and 
                   x <= (self.x + self.width - self.marginRight) and
                   y >= self.y and 
                   y <= (self.y + self.height)
        end
    }
end

gpu.setResolution(80, 25)
gpu.setBackground(colors.black)
gpu.fill(1, 1, 80, 25, " ")

local toggleButton = ButtonAPI.create(1, 22, 80, 3, "TOGGLE REACTOR", 3, 3, function()
    reactor1.setActive(not reactor1.getActive())
end)

local function drawVerticalEnergyBar(x, y, height, energyStored, energyMax)
    local percent = math.floor((energyStored / energyMax) * 100)
    local fillHeight = math.floor(height * percent / 100)

    gpu.setBackground(colors.gray)
    gpu.fill(x-1, y-1, 7, height+2, " ")
    
    gpu.setBackground(colors.gray)
    gpu.fill(x, y, 5, height, " ")
    
    gpu.setBackground(percent > 20 and colors.green or colors.red)
    gpu.fill(x, y + height - fillHeight, 5, fillHeight, " ")
    gpu.setBackground(colors.black)
end

local function drawLabelValue(x, y, label, value, valueColor)
    gpu.setForeground(colors.white)
    gpu.set(x, y, label)
    gpu.setForeground(valueColor or colors.white)
    gpu.set(x + #label, y, value)
    gpu.setForeground(colors.white)
end

local function updateReactorData()
    local energyStored = reactor1.getEnergyStored()
    local energyMax = 10000000
    local active = reactor1.getActive()
    local generationRate = reactor1.getEnergyProducedLastTick()
    local fuelReactivity = reactor1.getFuelReactivity()
    local fuelConsumption = reactor1.getFuelConsumedLastTick()
    local fuelTemp = reactor1.getFuelTemperature()
    local casingTemp = reactor1.getCasingTemperature()
    local fuelAmount = reactor1.getFuelAmount()
    local wasteAmount = reactor1.getWasteAmount()
    local coolantAmount = reactor1.isActivelyCooled() and reactor1.getCoolantAmount() or 0
    local hotFluidAmount = reactor1.isActivelyCooled() and reactor1.getHotFluidAmount() or 0

    gpu.setBackground(colors.black)
    gpu.fill(1, 1, 80, 21, " ")

    drawVerticalEnergyBar(5, 3, 15, energyStored, energyMax)

    drawLabelValue(15, 3, "STATUS: ", active and "ACTIVE" or "INACTIVE", active and colors.green or colors.red)
    drawLabelValue(15, 5, "OUTPUT: ", string.format("%.2f RF/t", generationRate), colors.green)
    drawLabelValue(15, 7, "ENERGY: ", string.format("%d/%d RF", energyStored, energyMax), colors.yellow)
    drawLabelValue(15, 9, "CASING TEMP: ", string.format("%.1f°C", casingTemp), casingTemp > 500 and colors.red or colors.green)

    drawLabelValue(47, 3, "FUEL REACTIVITY: ", string.format("%.2f", fuelReactivity), colors.green)
    drawLabelValue(47, 5, "FUEL CONSUMPTION: ", string.format("%.2f mB/t", fuelConsumption), colors.green)
    drawLabelValue(47, 7, "FUEL TEMP: ", string.format("%.1f°C", fuelTemp), fuelTemp > 800 and colors.red or colors.green)
    drawLabelValue(47, 9, "FUEL AMOUNT: ", string.format("%d mB", fuelAmount), colors.green)
    drawLabelValue(47, 11, "WASTE AMOUNT: ", string.format("%d mB", wasteAmount), colors.yellow)

    if reactor1.isActivelyCooled() then
        drawLabelValue(15, 13, "COOLANT: ", string.format("%d mB", coolantAmount), colors.blue)
        drawLabelValue(47, 13, "HOT FLUID: ", string.format("%d mB", hotFluidAmount), colors.red)
    end

    local percent = math.floor((energyStored / energyMax) * 100)
    drawLabelValue(15, 11, "ENERGY LEVEL: ", string.format("%d%%", percent), 
                  percent > 80 and colors.green or (percent > 30 and colors.yellow or colors.red))

    toggleButton:draw(active)
end

while true do
    updateReactorData()
    local e, _, x, y = event.pull(1, "touch")
    if e == "touch" and toggleButton:checkClick(x, y) then
        toggleButton.callback()
    end
end
