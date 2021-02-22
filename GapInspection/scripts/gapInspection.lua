--[[----------------------------------------------------------------------------

  Application Name:
  GapInspection

  Summary:
  Inspecting gaps in a heightmaps

  Description:
  This sample demonstrated how to use the Profile API to measure gaps in
  heightmaps.

  How to run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the image viewer on the DevicePage.
  Restarting the Sample may be necessary to show the profiles after loading the webpage.
  To run this Sample a device with SICK Algorithm API and AppEngine >= V2.5.0 is
  required. For example SIM4000 with latest firmware. Alternatively the Emulator
  on AppStudio 2.3 or higher can be used.

  More Information:
  Tutorial "Algorithms - Profile - FirstSteps".

------------------------------------------------------------------------------]]

--Start of Global Scope---------------------------------------------------------

local DOT_DECO = View.ShapeDecoration.create()
DOT_DECO:setLineColor(255, 255, 255) -- white
DOT_DECO:setPointSize(0.5)

local EDGE_DECO = View.ShapeDecoration.create()
EDGE_DECO:setLineColor(59, 156, 208) -- blue
EDGE_DECO:setLineWidth(0.1)
EDGE_DECO:setPointSize(0.5)

local LINE_DECO = View.ShapeDecoration.create()
LINE_DECO:setLineColor(242, 148, 0) -- orange
LINE_DECO:setLineWidth(0.1)
LINE_DECO:setPointSize(0.1)

local ANGLE_TO_AGGREGATE = 5 * math.pi / 180 -- 5 degree
local MIN_LENGTH = 0.75 -- min length between to edge points in mm

-- Pause between visualization, for demonstration purpose
local DELAY = 50

--End of Global Scope-----------------------------------------------------------

local function profileToPolyline(profile, spaceBetweenPoints)
  if not profile then return {} end
  spaceBetweenPoints = spaceBetweenPoints or 1
  local polyline

  local pointBuff = {}
  for i = 0, profile:getSize() - 1 do
    local x = i * spaceBetweenPoints
    local y = Profile.getValue(profile, i)
    pointBuff[#pointBuff + 1] = Point.create(x, y)
  end

  if #pointBuff > 0 then
    polyline = Shape.createPolyline(pointBuff, false)
  end
  return polyline
end

local function main()
  local heightMap = Object.load('resources/tabAerator.json')
  local pxSizeX, _, _ = heightMap:getPixelSize()

  -- Floor level can be calculated using the histogram
  local floorLevel = 20.6

  -- Fill all missing data with the floor level
  heightMap = heightMap:missingDataSetAll(floorLevel)

  -- Center can be calculated by image processing (i.e. Shape fitter)
  local center = Point.create(2.11, 19.47)

  -----------------------------------------------
  -- Scan the model -----------------------------
  -----------------------------------------------

  local baseScanLine = Shape.createLineSegment(center:subtract(Point.create(-15, 0)),
                                               center:subtract(Point.create(15, 0)))

  local curAngle = 0
  while true do

    -----------------------------------------------
    -- Aggregate multiple angles into one profile -
    -----------------------------------------------

    local profilesToAggregate = {}
    for i = 0, 9 do
      local scanLine = baseScanLine:rotate(curAngle + ANGLE_TO_AGGREGATE / 10 * i, center)
      profilesToAggregate[#profilesToAggregate + 1] = heightMap:extractProfile(scanLine, 30 / pxSizeX)
    end
    local scannedProfile = Profile.aggregate(profilesToAggregate, 'MEDIAN')

    -- Binarize to upper end of the model to extract the two outer rings (higher then the inlet)
    scannedProfile = scannedProfile:binarize(floorLevel + 15)

    -----------------------------------------------
    -- Search edges on the min-level --------------
    -----------------------------------------------
    local startIndex = nil
    local valueToSearch = scannedProfile:getMin()
    local edgeIndices = {}

    for index = 0, scannedProfile:getSize() - 1 do
      if scannedProfile:getValue(index) == valueToSearch then
        startIndex = startIndex or index
      else
        if startIndex and (index - 1 - startIndex) * pxSizeX >= MIN_LENGTH then
          edgeIndices[#edgeIndices + 1] = startIndex
          edgeIndices[#edgeIndices + 1] = index - 1
        end
        startIndex = nil
      end
    end
    if startIndex and (scannedProfile:getSize() - 1 - startIndex) * pxSizeX >= MIN_LENGTH  then
      edgeIndices[#edgeIndices + 1] = startIndex
      edgeIndices[#edgeIndices + 1] = scannedProfile:getSize() - 1
    end

    -----------------------------------------------
    -- Visualization ------------------------------
    -----------------------------------------------

    local edgePoints = {}
    for _, index in pairs(edgeIndices) do
      edgePoints[#edgePoints + 1] = Point.create(index * pxSizeX, scannedProfile:getValue(index))
    end

    local profileLine = profileToPolyline(scannedProfile, pxSizeX)

    local centerProfile = Point.create(scannedProfile:getSize() * pxSizeX / 2, 0)
    local profileTransformation = Transform.createRigid2D(curAngle, center:getX() - centerProfile:getX(),
                                                          center:getY() - centerProfile:getY() , centerProfile)
    profileLine = Shape.transform(profileLine, profileTransformation)
    edgePoints = Point.transform(edgePoints, profileTransformation)

    local v = View.create()

    v:clear()
    local imageID = v:addImage(heightMap)
    v:addShape(center, DOT_DECO, nil, imageID)
    v:addShape(profileLine, LINE_DECO, nil, imageID)
    for _, point in ipairs(edgePoints) do
      v:addShape(point, EDGE_DECO, nil, imageID)
    end
    v:present()

    curAngle = (curAngle + ANGLE_TO_AGGREGATE) % (2 * math.pi)
    Script.sleep(DELAY)
  end
end
Script.register('Engine.OnStarted', main)
-- serve API in global scope
