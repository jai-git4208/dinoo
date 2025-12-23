local player = {
    x = 80,
    y = 0,
    width = 1,
    height = 1,
    velocityY = 0,
    isJumping = false
}

local ground = { y = 0, height = 40 }
local obstacles = {}
local spawnTimer = 0
local spawnInterval = 1.5
local gameSpeed = 300
local score = 0
local highScore = 0
local gameOver = false
local gravity = 1200
local jumpForce = -500

-- Game States
local STATE_RUNNING = "running"
local STATE_BOSS = "boss"
local STATE_WIN = "win"
local gameState = STATE_RUNNING

-- Boss Fight Variables
local lastBossScore = 0
local playerHealth = 100
local boss = {
    x = 0,
    y = 0,
    width = 100,
    height = 100,
    health = 200,
    maxHealth = 200,
    speed = 150,
    attackTimer = 0
}
local attackCooldown = 0
local biteRange = 60
local tailRange = 100
local attackEffects = {} -- For visual feedback

local images = {
    bosses = {}
}
local dinoScale = 1
local bossScale = 1
local fonts = {}

function love.load()
    love.window.setTitle("Dinooooo")
    
    images.dino = love.graphics.newImage("assets/dino.jpeg")
    images.cactus = love.graphics.newImage("assets/obstacle.jpeg")
    
    -- Load all boss images
    local bossFiles = {"boss1.png", "boss2.png", "boss4.png", "boss5.jpeg", "boss6.jpeg"}
    for _, file in ipairs(bossFiles) do
        table.insert(images.bosses, love.graphics.newImage("assets/" .. file))
    end
    
    local targetHeight = 60
    dinoScale = targetHeight / images.dino:getHeight()
    player.width = images.dino:getWidth() * dinoScale
    player.height = targetHeight
    
    ground.y = love.graphics.getHeight() - ground.height
    player.y = ground.y - player.height + 1
    
    fonts.main = love.graphics.newFont(20)
    fonts.win = love.graphics.newFont(40)
    love.graphics.setFont(fonts.main)
end

function love.update(dt)
    if gameOver or gameState == STATE_WIN then return end
    
    if gameState == STATE_RUNNING then
        score = score + dt * 10
        gameSpeed = 300 + score * 0.5
        
        -- Win Condition at 500 score
        if score >= 500 then
            gameState = STATE_WIN
            if score > highScore then highScore = score end
        end
        
        -- Trigger boss fight every 100 score
        if gameState == STATE_RUNNING and math.floor(score) >= lastBossScore + 100 then
            startBossFight()
        end
        
        if player.isJumping then
            player.velocityY = player.velocityY + gravity * dt
            player.y = player.y + player.velocityY * dt
            
            if player.y >= ground.y - player.height then
                player.y = ground.y - player.height + 1
                player.isJumping = false
                player.velocityY = 0
            end
        end
        
        spawnTimer = spawnTimer + dt
        if spawnTimer >= spawnInterval then
            spawnTimer = 0
            spawnInterval = math.random(10, 20) / 10
            spawnObstacle()
        end
        
        for i = #obstacles, 1, -1 do
            local obs = obstacles[i]
            obs.x = obs.x - gameSpeed * dt
            
            if obs.x + obs.width < 0 then
                table.remove(obstacles, i)
            end
            
            if checkCollision(player, obs) then
                gameOver = true
                if score > highScore then
                    highScore = score
                end
            end
        end
    elseif gameState == STATE_BOSS then
        updateBossFight(dt)
    end
end

function startBossFight()
    gameState = STATE_BOSS
    lastBossScore = math.floor(score / 100) * 100
    obstacles = {} -- Clear obstacles
    playerHealth = 100
    boss.health = 200 + (score * 0.5) -- Scaled health
    boss.maxHealth = boss.health
    
    -- Pick a random boss image
    boss.image = images.bosses[math.random(#images.bosses)]
    local targetBossHeight = 120
    boss.scale = targetBossHeight / boss.image:getHeight()
    boss.width = boss.image:getWidth() * boss.scale
    boss.height = targetBossHeight
    
    boss.x = love.graphics.getWidth() - boss.width - 50
    boss.y = ground.y - boss.height
    player.isJumping = false
    player.velocityY = 0
end

function updateBossFight(dt)
    -- Player Movement (WASD)
    local moveSpeed = 250
    if love.keyboard.isDown("w") then player.y = player.y - moveSpeed * dt end
    if love.keyboard.isDown("s") then player.y = player.y + moveSpeed * dt end
    if love.keyboard.isDown("a") then player.x = player.x - moveSpeed * dt end
    if love.keyboard.isDown("d") then player.x = player.x + moveSpeed * dt end
    
    -- Keep player within bounds
    player.x = math.max(0, math.min(love.graphics.getWidth() - player.width, player.x))
    player.y = math.max(0, math.min(ground.y - player.height + 20, player.y)) -- Allow a bit of movement below line
    
    -- Boss AI
    -- Follow player Y
    if boss.y < player.y then boss.y = boss.y + boss.speed * 0.5 * dt end
    if boss.y > player.y then boss.y = boss.y - boss.speed * 0.5 * dt end
    
    -- Bobbing/Hovering X
    boss.x = boss.x + math.sin(love.timer.getTime() * 2) * 50 * dt
    
    -- Boss Attack
    boss.attackTimer = boss.attackTimer + dt
    if boss.attackTimer > 2 then
        boss.attackTimer = 0
        -- Simple projectile or dash
        if math.abs(player.y - boss.y) < 50 then
            playerHealth = playerHealth - 15
        end
    end
    
    -- Cooldowns
    if attackCooldown > 0 then attackCooldown = attackCooldown - dt end
    
    -- Effects
    for i = #attackEffects, 1, -1 do
        attackEffects[i].timer = attackEffects[i].timer - dt
        if attackEffects[i].timer <= 0 then table.remove(attackEffects, i) end
    end
    
    -- Check Win/Loss
    if playerHealth <= 0 then
        gameOver = true
        if score > highScore then highScore = score end
    end
    
    if boss.health <= 0 then
        gameState = STATE_RUNNING
        player.x = 80 -- Reset player position
        player.y = ground.y - player.height + 1
    end
end

function love.draw()
    love.graphics.clear(1, 1, 1)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.line(0, ground.y, love.graphics.getWidth(), ground.y)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(images.dino, player.x, player.y, 0, dinoScale, dinoScale)
    
    for _, obs in ipairs(obstacles) do
        love.graphics.draw(images.cactus, obs.x, obs.y, 0,
            obs.width / images.cactus:getWidth(),
            obs.height / images.cactus:getHeight())
    end
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Score: " .. math.floor(score), 10, 10)
    love.graphics.print("High Score: " .. math.floor(highScore), 10, 35)
    
    if gameState == STATE_BOSS then
        -- Draw Boss
        love.graphics.setColor(1, 1, 1)
        if boss.image then
            love.graphics.draw(boss.image, boss.x, boss.y, 0, boss.scale, boss.scale)
        else
            love.graphics.setColor(1, 0, 0) -- Fallback
            love.graphics.rectangle("fill", boss.x, boss.y, boss.width, boss.height)
        end
        
        -- Boss Health Bar
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", boss.x, boss.y - 20, boss.width, 10)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", boss.x, boss.y - 20, boss.width * (boss.health / boss.maxHealth), 10)
        
        -- Player Health Bar
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", 10, 60, 200, 20)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", 10, 60, 200 * (playerHealth / 100), 20)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("HP", 10, 60)
        
        -- Draw Attacks
        for _, effect in ipairs(attackEffects) do
            love.graphics.setColor(1, 1, 0, effect.timer * 2)
            love.graphics.circle("line", effect.x, effect.y, effect.radius)
        end
    end
    
    if gameOver then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("GAME OVER", love.graphics.getWidth() / 2 - 60, love.graphics.getHeight() / 2 - 30)
        love.graphics.print("Press SPACE to restart", love.graphics.getWidth() / 2 - 100, love.graphics.getHeight() / 2 + 10)
    end
    
    if gameState == STATE_WIN then
        love.graphics.setColor(0, 0, 1, 0.7) -- Blue win screen
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.win)
        love.graphics.print("GO FIND JOB BRO!", love.graphics.getWidth() / 2 - 150, love.graphics.getHeight() / 2 - 30)
        
        love.graphics.setFont(fonts.main)
        love.graphics.print("Press SPACE to restart", love.graphics.getWidth() / 2 - 100, love.graphics.getHeight() / 2 + 50)
    end
end

function love.keypressed(key)
    if key == "space" or key == "up" then
        if gameOver or gameState == STATE_WIN then
            restartGame()
        elseif gameState == STATE_RUNNING and not player.isJumping then
            player.isJumping = true
            player.velocityY = jumpForce
        end
    end
    
    -- Attacks in Boss Fight
    if gameState == STATE_BOSS and not gameOver then
        if key == "j" and attackCooldown <= 0 then -- Bite
            attackCooldown = 0.3
            table.insert(attackEffects, {x = player.x + player.width, y = player.y + player.height/2, radius = biteRange, timer = 0.2})
            if checkDist(player.x + player.width, player.y + player.height/2, boss.x, boss.y, boss.width, boss.height) < biteRange then
                boss.health = boss.health - 20
            end
        elseif key == "k" and attackCooldown <= 0 then -- Tail Swing
            attackCooldown = 0.5
            table.insert(attackEffects, {x = player.x, y = player.y + player.height/2, radius = tailRange, timer = 0.3})
            if checkDist(player.x, player.y + player.height/2, boss.x, boss.y, boss.width, boss.height) < tailRange then
                boss.health = boss.health - 15
            end
        end
    end
    
    if key == "escape" then
        love.event.quit()
    end
end

function checkDist(ax, ay, bx, by, bw, bh)
    local cx = bx + bw / 2
    local cy = by + bh / 2
    return math.sqrt((ax - cx)^2 + (ay - cy)^2)
end

function spawnObstacle()
    local obstacle = {
        x = love.graphics.getWidth(),
        width = 30,
        height = 50
    }
    obstacle.y = ground.y - obstacle.height + 1
    table.insert(obstacles, obstacle)
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function restartGame()
    gameOver = false
    gameState = STATE_RUNNING
    score = 0
    lastBossScore = 0
    obstacles = {}
    spawnTimer = 0
    gameSpeed = 300
    player.x = 80
    player.y = ground.y - player.height + 1
    player.isJumping = false
    player.velocityY = 0
    playerHealth = 100
end