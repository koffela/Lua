local time = 30
local lastTime = os.time()

function Timer()
    print("Time remaining in match: " .. time .. " seconds")
    time = time - 1

    --Need to break the loop when time runs out
    if time < 0 then
        print("Game over! X player has won the game")
        return false
    end
    --otherwise, keep the timer going
    return true
end

function Main()
    print("Let the match begin!")
    while true do
        local currentTime = os.time()
        if currentTime > lastTime then
            if not Timer() then
                break
            end
            lastTime = currentTime
        end
    end
end


Main()