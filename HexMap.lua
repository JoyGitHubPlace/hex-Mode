--[[
    关于地图的算法模块，方便其他模块使用和调取
    约定：使用平面三维坐标系，一个单位为正六边形,原点坐标为中心位置
]]--
---@classdef HexMap
local HexMap = {}

local HexMapDirection = XQRequire("HexMapDirection")
local UnitPathingMoveType = XQRequire("UnitPathingMoveType")
---@class Hex
local Hex = XQRequire("Hex")
local MapTile=XQRequire ("MapTile")
--系统包的引用
local bit = require ("bit")

HexMap.MapNodes = nil

HexMap.__index=HexMap

local tinsert = table.insert

function HexMap:New()
    local o = {}
    setmetatable(o,HexMap)
    o.MapNodes = {}
    return o
end

---定义一个新的类入口，选择特殊情况的方法调用
-- @return @HexMap
function HexMap:GetMapSearcher()
    return self
end

---使用一组已知的地图数据初始化地图
-- @param MTiles @Array(MapTile) 地图单元格
-- @return nil
function HexMap:Init(Tiles)
    local v
    local key
    for i=1,Tiles:Size() do
        v=Tiles[i]
        key= self:Addchar(v.Hex)
        self.MapNodes[key]=v
    end
end

---通过宽高来初始化地图
-- @param @num Width 宽度
-- @param @num Hight 高度
-- @return nil
function HexMap:InitBySize(Width,Hight)
    local minY=math.ceil(Hight*(-1)/2)
    local maxY
    local param
    if Hight/2==math.floor(Hight/2) then
        maxY=Hight/2-1
    else
        maxY=math.floor(Hight/2)
    end
    local param2=0
    local leng
    for j=maxY,minY,-1 do
        if j%2==0 then
            param=2
            leng=Width-1
        else
            param=1
            leng=Width
        end
        for i=leng,1,-1 do
            local b=j
            local a=j-i+param2
            local c=0-a-b
            local hex = Hex.Get(a,b,c)
            local tile=MapTile.New(true,hex)
            self.MapNodes[hex]=tile
        end
        param2=param2+param
    end
end

function HexMap:Addchar(pos)
    return pos
end

--- 添加地图单元格
-- @param Tile @class MapTile 地图单元格
-- @return nil
function HexMap:AddTile(Tile)
    local key=self:Addchar(Tile.Hex)
    if self.MapNodes[key]==nil then
        self.MapNodes[key]=Tile
    end
end

---根据uid获取一个hex
function HexMap:Hex(uid)
    return Hex.GetHexFromUID(uid)
end

---:根据坐标获得一个单元格
-- @param position @class Hex 位置信息
-- @return v @class MapTile
function HexMap:GetTileByHex(position)
    return self.MapNodes[self:Addchar(position)]
end

---获得地图上单元格数量
-- @return @int 单元格数量
function HexMap:GetTileCount()
    return table.count(self.MapNodes)
end

--- 获得所有的单元格
--- @return:MapNodes @Array(MapTile)
function HexMap:GetTiles()
    local values=Array.New()
    for k,v in pairs(self.MapNodes) do
        values:Add(v)
    end
    return values
end

---获得from 到 to 的无视阻挡距离，邻边也是1的距离，而不是0，技能有减1的处理，有修改距离方式要通知下
-- @param from @class MapTile.Hex
-- @param to @class MapTile.Hex
-- @return distance @num
function HexMap:GetDistance(from,to)
    local distance=0
    local keyFrom=self:Addchar(from)
    local keyTo=self:Addchar(to)
    if self.MapNodes[keyFrom]~=nil and self.MapNodes[keyTo]~=nil then
        local mabs = math.abs
        distance= bit.rshift(mabs(from.q - to.q) + mabs(from.r - to.r) + mabs(from.s - to.s), 1)
    end
    return distance
end

---获得以from为原点，movement为半径的圆上的单元格
-- @param from @class MapTile.Hex
-- @param movement @num
--- @return:Range @Array(MapTile)
function HexMap:GetCircleRange(from,movement)
    local around=Array:New()
    local n=movement
    for i=(-1)*n,n do
        for j=(-1)*n,n do
            for k=(-1)*n,n do
                if i+j+k==0 then
                    if  i==n or j==n or k==n or i==-n or j==-n or k==-n then
                        local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                        local tile=self:GetTileByHex(pos)
                        if tile~=nil then
                            around:Add(tile)
                        end
                    end
                end
            end
        end
    end
    around:Remove(self:GetTileByHex(from))
    return around
end

--- 获得范围内的所有单元格
-- @param from @class MapTile.Hexn
-- @param movement @num
--- @return:Range @Array(MapTile)
function HexMap:GetRadiusRange(from,movement)
    local around=Array:New()
    local n=movement
    for k=(-1)*n,n do
        for i=n,(-1)*n,-1 do
            for j=n,(-1)*n,-1 do
                if i+j+k==0 then
                    local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                    local tile=self:GetTileByHex(pos)
                    if tile~=nil then
                        around:Add(tile)
                    end
                end
            end
        end
    end
    around:Remove(self:GetTileByHex(from))
    return around
end

--- 获得范围内的所有单位
--@param from @class MapTile.Hexn
--@param movement @num
--@param 忽略的单位
--@return @table(unit)
function  HexMap:GetRadiusRangeUnit(from, movement, ignoreunit)
    local around = {}
    local n = movement
    for i=(-1)*n,n do
        for j=(-1)*n,n do
            for k=(-1)*n,n do
                if i+j+k==0 then
                    local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                    local tile=self:GetTileByHex(pos)
                    if tile and tile.unit then
                        --去掉忽略的单位
                        if not ignoreunit or ignoreunit ~= tile:GetUnit() then
                            tinsert(around, tile.unit)
                        end
                    end
                end
            end
        end
    end
    return around
end

--- 获得玩家进场时可以拖入的单元格
-- @param from @class MapTile.Hex
-- @param movement @num
--- @return table(MapTile)
function HexMap:GetCanLoadRange(from, movement)
    local around = {}
    local n=movement
    for i=(-1)*n,n do
        for j=(-1)*n,n do
            for k=(-1)*n,n do
                if i+j+k==0   then
                    local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                    local tile=self:GetTileByHex(pos)
                    if tile and not tile:HasUnit() then
                        tinsert(around, tile)
                    end
                end
            end
        end
    end
    --table.removeValue(around, self:GetTileByHex(from)) 自己的canwalk=false，添加不进
    return around
end

--- 获得玩家可以移动到的位置，考虑寻路
-- @param from @class MapTile.Hexn
-- @param movement @num
--- @return Range @table(MapTile)
function HexMap:GetMoveRange(from, movement)
    local around = {}
    local n = movement
    for i=(-1)*n,n do
        for j=(-1)*n,n do
            for k=(-1)*n,n do
                if i+j+k==0 then
                    local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                    local tile=self:GetTileByHex(pos)
                    if tile then
                        local path = self:GetPath(from,pos)
                        if path and path:Size() <= movement then
                            tinsert(around, tile)
                        end
                    end
                end
            end
        end
    end
    table.removeValue(around, self:GetTileByHex(from))
    return around
end

---寻路
-- @param from @class MapTile.Hex
-- @param to @class MapTile.Hex
-- @param movement @num
-- @return Range @Array(MapTile)
function HexMap:GetMovePath(from,to,movement,moveType,fixToMovement)
    local Range=Array:New()
    if moveType==UnitPathingMoveType.Teleport then
        Range:Add(self:GetTileByHex(to))
        return Range
    end
    if moveType==UnitPathingMoveType.Move then
        local Path=self:GetPath(from,to)
        if Path~=nil then
            if Path:Size()>movement and fixToMovement==true then
                for i=Path:Size(),Path:Size()-movement+1,-1  do
                    Range:Add(Path[i])
                end
            else
                Range=Path
            end
            return Range
        else
            --不能到达
        end
    end
end
---计算冲击力专用
-- @param @Array(MapTile)路线
-- @return @num len 长度
function HexMap:GetFastAttackPath(range)
    local cnt = range:Size()
    if cnt == 1 then return 1 end
    local leng=0
    if range~=nil and cnt>1 then
        leng = 1
        local tempQ=range[1].Hex.q-range[2].Hex.q
        local tempR=range[1].Hex.r-range[2].Hex.r
        local tempS=range[1].Hex.s-range[2].Hex.s
        for i=1,cnt-1 do
            if range[i].Hex.q-range[i+1].Hex.q==tempQ and  range[i].Hex.q-range[i+1].Hex.q==tempQ and  range[i].Hex.q-range[i+1].Hex.q==tempQ then
                leng=leng+1
            else
                break
            end
        end
    end
    return leng
end
function HexMap:GetDirectPath(from,to)
    local CanThrough=true
    local node
    local range=Array:New()
    local i,j=0,0
    --区分最大差值和其余两个
    local temp
    local a=math.abs(from.q-to.q)
    local b=math.abs(from.r-to.r)
    local c=math.abs(from.s-to.s)
    local pos
    if a>b then
        temp=a
    else
        temp=b
    end
    if temp < c then
        temp=c
    end
    --根据其余两个确定中间位置
    if temp==a then
        local p=Hex.Get((-1)*(from.r+to.s),from.r,to.s)
        if self:GetTileByHex(p)~=nil  then
            pos=p
        else
            pos=Hex.Get((-1)*(to.r+from.s),to.r,from.s)
        end
    else
        if temp==b then
            local p=Hex.Get(from.q,(-1)*(from.q+to.s),to.s)
            if self:GetTileByHex(p)~=nil then
                pos=p
            else
                pos=Hex.Get(to.q,(-1)*(to.q+from.s),from.s)
            end
        else
            if temp==c then
                local p=Hex.Get(from.q,to.r,(-1)*(from.q+to.r))
                if self:GetTileByHex(p)~=nil then
                    pos=p
                else
                    pos=Hex.Get(to.q,from.r,(-1)*(to.q+from.r))
                end
            end
        end
    end
    local t
    if pos.q-to.q~=0 then
        t=math.abs(pos.q-to.q)
    else
        t=math.abs(pos.r-to.r)
    end
    --根据中间位置来连接两段路
    while(i~=t)do
        local node=Hex.Get((pos.q-to.q)*i/t,(pos.r-to.r)*i/t,(pos.s-to.s)*i/t)
        local tile=self:GetTileByHex(self:PosSum(to,node))
        if tile:CanWalk() then
            range:Add(tile)
        else
            CanThrough=false
        end
        i=i+1
    end
    while(j~=temp-t)do
        local node=Hex.Get((from.q-pos.q)*j/(temp-t),(from.r-pos.r)*j/(temp-t),(from.s-to.s)*j/(temp-t))
        local tile=self:GetTileByHex(self:PosSum(pos,node))
        if tile:CanWalk() then
            range:Add(tile)
        else
            CanThrough=false
        end
        j=j+1
    end
    if CanThrough then
        return range
    else
        return nil
    end
end
function HexMap:PosSum(pos1,pos2)
    return Hex.Get(pos1.q+pos2.q,pos1.r+pos2.r,pos1.s+pos2.s)
end

---获取某个点周围坐标
-- @param from @Hex 位置点
-- @return @table{@Hex}
function HexMap:GetNeightbor(from)
    local around=Array:New()
    local Tneightbor = {Hex.Get(from.q + 1, from.r + 0, from.s - 1),
                        Hex.Get(from.q - 1, from.r + 0, from.s + 1),
                        Hex.Get(from.q + 0, from.r + 1, from.s - 1),
                        Hex.Get(from.q + 1, from.r - 1, from.s + 0),
                        Hex.Get(from.q - 1, from.r + 1, from.s + 0),
                        Hex.Get(from.q + 0, from.r - 1, from.s + 1)}
    for k,v in pairs(Tneightbor) do
        local tile=self:GetTileByHex(v)
        if tile~=nil then
            around:Add(tile)
        end
    end
    return around
end

---A*寻路
-- @param from @class MapTile.Hex
-- @param to @class MapTile.Hex
-- @return Range @Array(MapTile)
function HexMap:GetAStarPath(from,to)
    local Range
    local StartNode=self:GetTileByHex(from)
    local EndNode=self:GetTileByHex(to)
    local openSet=Array:New()
    local closeSet=Array:New()
    openSet:Add(StartNode)
    local getPath=false
    while(openSet:Size()>0) do
        local currentNote=openSet[1]

        for  i = 1,openSet:Size() do
            local node=openSet[i]
            if node.fCost<currentNote.fCost or  node.fCost==currentNote.fCost then
                if  node.hCost<currentNote.hCost then
                    currentNote=node
                end
            end
        end
        local a= openSet:Remove(currentNote)
        closeSet:Add(currentNote)
        if currentNote==EndNode then
            getPath=true
            --寻路成功
            Range=self:FinalPath(StartNode, EndNode)
            break
        end
        local curpos = currentNote.Hex
        local range=self:GetNeightbor(curpos)
        for k,v in ipairs(range) do
            if v:CanWalk()==false or closeSet:FindIndex(v)>0 then
                --遇到障碍物
            else
                local newCost = self:GetLong(currentNote,StartNode) + self:GetLong(currentNote,v)
                if newCost> self:GetLong(v,StartNode)or closeSet:FindIndex(v)<0 then
                    v.gCost = newCost
                    v.hCost =self:GetLong(EndNode,v)
                    if openSet:FindIndex(v)<0 or v.parent then
                        v.parent = currentNote
                    end
                    if closeSet:FindIndex(v)<0 then
                        openSet:Add(v)
                    end
                end
            end
        end
    end
    if getPath==true then
        return Range
    else
        return nil
    end
end
---计算两个单元格之间的直线距离
-- @param  @class MapTile from 单元格1
-- @param  @class MapTile to 单元格2
-- @return @num
function HexMap:GetLong(from,to)
    return (math.abs(from.Hex.q - to.Hex.q) + math.abs(from.Hex.r - to.Hex.r) + math.abs(from.Hex.s -to.Hex.s))/2
end
---多点A*寻路
-- @param from @class MapTile.Hex
-- @param to @Array(MapTile.Hex)
-- @return Range @Array(MapTile)
function HexMap:GetMorePath(from,list)
    local node
    local bastDistance=10000000
    for i=1,list:Size() do
        local temp=self:GetDistance(from,list[i])
        if temp<bastDistance then
            node=list[i]
            bastDistance=temp
        end
    end
    return self:GetPath(from,node)
end
---不考虑移动力寻路
-- @param from @class MapTile.Hex
-- @param to @class MapTile.Hex
-- @param true 不考虑障碍
-- @return Range @Array(MapTile)
function HexMap:GetPath(from, to, noobstacle)
    local range = self:GetDirectPath(from,to)
    if range == nil then
        return nil
    else
       return self:GetAStarPath(from,to) 
    end   
end
---反向追踪找出路径
-- @param startNode  @class MapTile 开始节点
-- @param endNode  @class MapTile 结束节点
-- @return Range @Array(MapTile)
function HexMap:FinalPath(startNode,endNode)
    local path=Array:New()
    local temp =endNode
    while temp~=startNode do
        path:Add(temp)
        temp=temp.parent
    end
    --path:Reverse()
    return path
end

--- 靠近某个位置周围，minRandius以外，maxRandius以内的最近路线
-- @param from @class MapTile.Hex
-- @param to @class MapTile.Hex
-- @param minRandius @num
-- @param maxRandius @num
-- @param movement @num
-- @param moveType @UnitPathingMoveType
-- @param fixToMovement @boolean
-- @return Range @Array(MapTile)
function HexMap:GetBestPath(from,to,minRandius,maxRandius,movement,moveType,fixToMovement)
    local finalPath
    if moveType== UnitPathingMoveType.Move then
        local n=maxRandius
        local currentPathCount=100
        local currentPath
        for i=(-1)*n,n do
            for j=(-1)*n,n do
                for k=(-1)*n,n do
                    if i+j+k==0 then
                        if i>=minRandius or j>=minRandius or k>=minRandius or i<=(-1)*minRandius or j<=(-1)*minRandius or k<=(-1)*minRandius  then
                            local pos=Hex.Get(to.q+i,to.r+j,to.s+k)
                            local tile=self:GetTileByHex(pos)
                            local mabs = math.abs
                            local distance= bit.rshift(mabs(from.q - pos.q) + mabs(from.r - pos.r) + mabs(from.s - pos.s), 1)
                            if tile ~= nil and distance < currentPathCount  then
                                local path = self:GetPath(from,pos)
                                if  path~=nil then
                                    local pathlong = path:Size()
                                    if  pathlong < currentPathCount then
                                        currentPathCount = pathlong
                                        currentPath = path
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if currentPath ~= nil then
            finalPath=Array:New()
            if currentPath:Size()>movement and fixToMovement==true then
                for i=currentPath:Size()-movement+1,currentPath:Size()  do
                    finalPath:Add(currentPath[i])
                end
            else
                finalPath=currentPath
            end
        else
            return nil
        end
        else if moveType== UnitPathingMoveType.Teleport then
            finalPath=Array:New()
            finalPath:Add(self:GetTileByHex(to))
            return finalPath
        end
    end
    return finalPath
end

---获得直线范围内的所有单元格
--@param from @class MapTile.Hex
--@param length @num 长度
--@param direction @sring 方向
--@param true 返回MapTile；false 返回有Unit的MapTile
--@return table
function HexMap:GetLineRange(from, length, direction, isTile)
    local listTile = {}
    if direction==HexMapDirection.Right then
        local key
        for i=1,length do
            key= Hex.Get(from.q+i,from.r,from.s+i *(-1))
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end
    elseif direction==HexMapDirection.RightUp then
        local key
        for i=1,length do
            key= Hex.Get(from.q,from.r+i,from.s+i *(-1))
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end
    elseif direction==HexMapDirection.LeftUp then
        local key
        for i=1,length do
            key= Hex.Get(from.q+i*(-1),from.r+i,from.s)
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end
    elseif direction==HexMapDirection.Left then
        local key
        for i=1,length do
            key= Hex.Get(from.q+i*(-1),from.r,from.s+i)
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end
    elseif direction==HexMapDirection.LeftDown then
        local key
        for i=1,length do
            key= Hex.Get(from.q,from.r+i*(-1),from.s+i)
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end
    elseif direction==HexMapDirection.RightDown then
        local key
        for i=1,length do
            key= Hex.Get(from.q+i,from.r+i*(-1),from.s)
            local tile = self.MapNodes[key]
            if tile ~= nil then
                if isTile then
                    tinsert(listTile, tile)
                elseif tile.unit then
                    tinsert(listTile, tile.unit)
                end
            end
        end

    end
    return listTile
end

---获得半径大于等于minRandius，小于等于maxRandius的一个环型区域
-- @param from @class MapTile.Hex
-- @param minRandius @num
-- @param maxRandius @num
-- @return Range @array(@MapTile)
function HexMap:GetCircle(from,minRandius,maxRandius)
    local range=Array:New()
    local finalRange=Array:New()
    for i=minRandius,maxRandius do
        range = self:GetCircleRange(from,i)
        for j=1,range:Size() do
            finalRange:Add(range[j])
        end
    end
    return finalRange
end

---添加一个单位
-- @param unit @UnitCardData 战斗单位
-- @param id @num 位置ID 位置Uid
-- @return @Hex 添加id后返回位置hex
function HexMap:AddUnitByHexId(unit,id)
    local tile = self:GetFirstStandTile(Hex.GetHexFromUID(id))
    if tile then
        tile.unit=unit
        tile.canwalk=false
        return tile.Hex
    end
    return nil
end

function HexMap:AddUnitByHex(unit,hex)
    local tile= self:GetTileByHex(hex)
    if tile then
        tile.unit=unit
        tile.canwalk=false
        return tile.Hex
    end
    return nil
end

function HexMap:AddUnitByTile(unit,tile)
    tile.unit=unit
    tile.canwalk=false
    return tile.Hex
end

---单位移动到新位置
function HexMap:MoveUnitByHexId(unit, oldHex, uid)
    local tile = self:GetTileByHex(Hex.GetHexFromUID(uid))
    tile.unit = unit
    tile.canwalk = false
    --重置以前的格子
    local oldtile = self:GetTileByHex(oldHex)
    oldtile.unit = nil
    oldtile.canwalk = true
    return tile.Hex
end

---单位移动到新位置
function HexMap:MoveUnitByHex(unit, oldHex, newHex)
    local newTile = self:GetTileByHex(newHex)
    newTile.unit = unit
    newTile.canwalk = false
    --重置以前的格子
    local oldtile = self:GetTileByHex(oldHex)
    oldtile.unit = nil
    oldtile.canwalk = true
    return newTile.Hex
end

function HexMap:MoveUnitByHexTile(unit, oldHex, newTile, findNear)
    if findNear then
        if newTile:HasUnit() then
            local tile = self:GetFirstStandTile(newTile.Hex)
            if tile then
                tile.unit = unit
                tile.canwalk = false
            else
                return nil
            end
        end
    else
        newTile.unit = unit
        newTile.canwalk = false
    end
    --重置以前的格子
    local oldtile = self:GetTileByHex(oldHex)
    oldtile.unit = nil
    oldtile.canwalk = true
    return newTile.Hex
end

---移除一个单位
-- @param unit @UnitCardData 战斗单位
-- @return nil
function HexMap:RemoveUnit(unit)
    for _,v in pairs(self.MapNodes) do
        if v.unit==unit then
            v.unit=nil
            v.canwalk=true
            break
        end
    end
end

---删除地图上的单位
function HexMap:RmUnitByHex(hex)
    local tile = self:GetTileByHex(hex)
    tile.unit = nil
    tile.canwalk = true
end

---更新hex里的单位为newunit
function HexMap:UpdateUnitHex(hex, newunit)
    local tile = self:GetTileByHex(hex)
    tile:SetUnit(newunit)
    return hex
end

---返回个空地
--@param uid
--@return @class MapTile 如果不是空地，nil
function HexMap:GetEmptyHex(uid)
    local tile = self:GetFirstStandTile(Hex.GetHexFromUID(uid))
    if tile and not tile:HasUnit() then return tile end
    return nil
end

---是否是空地
function HexMap:HasEmptyHex(hex)
    local tile = self:GetTileByHex(hex)
    return not tile:HasUnit()
end

---是否可以添加一个单位
-- @return canAdd @Boolean
function HexMap:CanAdd(pos)
    local id=self:Addchar(pos)
    if self.MapNodes[id]==nil then
        return true
    else
        return false
    end
end

---寻找最近的可出生点
-- @param pos 初始设定的位置
-- @return range[j] @MapTile
function HexMap:GetFirstStandTile(pos)
    if not self.MapNodes[pos].unit then
        return self.MapNodes[pos]
    end
    local range = nil
    for i=0,9 do
        range = self:GetRadiusRange(pos,i)
        for j=1,range.Count do
            if not range[j].unit then
                return range[j]
            end
        end
    end
    return nil
end

---获得指定范围内目前可以站单位的单元格
-- @param center @Hex 中心点
-- @param minRandius @int 最短半径
-- @param maxRandius @int 最长半径
-- @return range @Array(@MapTile)
function HexMap:GetStandCircle(center,minRandius,maxRandius)
    local range = nil
    local finalRange=Array:New()
    for i=minRandius,maxRandius-1 do
        range = self:GetRadiusRange(center,i)
        for j=1,range:Size() do
            if not range[j].unit then
                finalRange:Add(range[i])
            end
        end
    end
    return finalRange
end

---根据uid获得对应的Hex对象
--@param uid
--@return @class Hex
function HexMap:GetHexFromUID(uid)
    return Hex.GetHexFromUID(uid)
end

---单位是否在range范围内
-- @param unit @UnitCardData 战斗单位
-- @param Range @Array(@MapTile)
-- @return @boolean
function HexMap:IsUnitIntRange(unit,Range)
    for i=1,Range:Size() do
        if not Range[i].unit then
            return true
        end
    end
    return false
end

---单位是否在以center为中心，radius为半径的范围内
-- @param unit @UnitCardData 战斗单位
-- @param center @Hex 中心点
-- @param radius @int 半径
-- @return @boolean
function HexMap:IsUnitIntRadiueRange(unit,center,radius)
    local range=self:GetStandCircle(center,1,radius)
    self:IsUnitIntRange(unit,range)
end

---单位是否在以center为中心minRadiue和MaxRadiue之间的圆环区域
-- @param unit @UnitCardData 战斗单位
-- @param center @Hex 中心点
-- @param MinRadius @int 最小半径
-- @param MaxRadius @int 最大半径
-- @return @boolean
function HexMap:IsUnitIntBetweenRadiueRange(unit,center,MinRadius,MaxRadius)
    local range=self:GetStandCircle(center,MinRadius,MaxRadius)
    self:IsUnitIntRange(unit,range)
end

---获取全场没有单位的单元格
--@return @class MapTile table
function HexMap:GetTileNoUnit()
    local ret = {}
    for _, v in pairs(self.MapNodes) do
        ---@class MapTile
        local tile = v
        if not tile:HasUnit() then
            tinsert(ret, v)
        end
    end
    return v
end

---获取全场没有单位的Hex
--@return @class MapTile table
function HexMap:GetHexNoUnit()
    local ret = {}
    for _, v in pairs(self.MapNodes) do
        ---@class MapTile
        local tile = v
        if not tile:HasUnit() then
            tinsert(ret, tile.Hex)
        end
    end
    return ret
end

---获取半径距离内没有单位的单元格
--@return @class MapTile table
function HexMap:GetRadiusNoUnit(from, movement)
    local around = {}
    local n = movement
    for i=(-1)*n,n do
        for j=(-1)*n,n do
            for k=(-1)*n,n do
                if i+j+k==0 then
                    local pos=Hex.Get(from.q+i,from.r+j,from.s+k)
                    local tile=self:GetTileByHex(pos)
                    if tile and not tile.unit then
                        tinsert(around, tile)
                    end
                end
            end
        end
    end
    return around
end
---获取受击后的倒退缓冲路径
-- @param from @Hex 玩家坐标
-- @param to  @Hex 攻击方坐标
-- @param Movement @Num 倒退距离
-- @return around @table(@MapTile) 返回table
function HexMap:GetBackPath(from,to,Movement)
    local around={}
    if from.q - to.q ==0 or from.r - to.r ==0 or  from.s - to.s==0 then
        --获取单位方向
        local mabs = math.abs
        local distance= bit.rshift(mabs(from.q - to.q) + mabs(from.r - to.r) + mabs(from.s - to.s), 1)
        local pos=Hex.Get((to.q-from.q)/distance,(to.r-from.r)/distance,(to.s-from.s)/distance)
        --获取后退路径
        for i=1,Movement do
            local pos1=Hex.Get(from.q-(pos.q)*i,from.r-(pos.r)*i,from.s-(pos.s)*i)
            local tile = self:GetTileByHex(pos1)
            if tile then
                tinsert(around, tile)
            else
                break
            end
        end
    end
    return around
end

---获取相对于起点位置的目标点的两翼坐标，有几个返回几个
-- @param from @Hex  起点坐标
-- @param to @Hex 终点坐标
-- @return around  @table(@unit) 返回table
function HexMap:GetTargetNeighbors(from,to)
    local around={}
    if from.q - to.q ==0 or from.r - to.r ==0 or  from.s - to.s==0 then
        --获取终点临近的四边形对角坐标
        local mabs = math.abs
        local distance= bit.rshift(mabs(from.q - to.q) + mabs(from.r - to.r) + mabs(from.s - to.s), 1)
        local pos=Hex.Get((to.q-from.q)/distance,(to.r-from.r)/distance,(to.s-from.s)/distance)
        local pos1=Hex.Get(to.q-pos.q,to.r-pos.r,to.s-pos.s)
        --根据四边形的两个对角坐标获取另外两个坐标
        local pos2
        local pos3
        if to.q-pos1.q==0 then
            if pos1.r> to.r then
                pos2=Hex.Get(to.q+1,to.r,pos1.s)
                pos3=Hex.Get(to.q-1,pos1.r,to.s)
            else
                pos2=Hex.Get(to.q+1,pos1.r,to.s)
                pos3=Hex.Get(to.q-1,to.r,pos1.s)
            end
            else if to.r-pos1.r==0 then
                if pos1.q>to.q then
                    pos2=Hex.Get(pos1.q,to.r-1,to.s)
                    pos3=Hex.Get(to.q,to.r+1,pos1.s)
                else
                    pos2=Hex.Get(pos1.q,to.r+1,to.s)
                    pos3=Hex.Get(to.q,to.r-1,pos1.s)
                end
                else if to.s-pos1.s==0 then
                    if pos1.q>to.q then
                        pos2=Hex.Get(pos1.q,to.r,to.s-1)
                        pos3=Hex.Get(to.q,pos1.r,to.s+1)
                    else
                        pos2=Hex.Get(to.q,pos1.r,to.s-1)
                        pos3=Hex.Get(pos1.q,to.r,to.s+1)
                    end
                end
            end
        end
        --判断是否为空并加入table
        local tile = self:GetTileByHex(pos2)
        if tile ~= nil and tile:HasUnit() then
            tinsert(around, tile:GetUnit())
        end
        tile = self:GetTileByHex(pos3)
        if tile ~=nil and tile:HasUnit() then
            tinsert(around, tile:GetUnit())
        end
    end
    return around
end

return HexMap
