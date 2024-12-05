// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accuracy

global THROTTLE_LEVEL is 1.0.
lock throttle to THROTTLE_LEVEL.

function main {
  wait 10.
  doLaunch().
  doAscent().
  
  until apoapsis > 180000 { // Target: 180 km Low Earth Orbit
    wait 3.
    doAutoStage().
    wait 3.
  }
   
  doShutdown().
  doCircularization().
  print "Mission Completed!".
  unlock steering.
  wait until false.
}

function doCircularization {
  local circ is list(time:seconds + 60, 0, 0, 0). // Circularization node ~60s after apogee
  until false {
    local oldScore is score(circ).
    set circ to improve(circ).
    if oldScore <= score(circ) {
      break.
    }
  }
  executeManeuver(circ).
}

function addManeuverToFlightPlan {
  parameter mnv.
  add mnv.
}

function removeManeuverFromFlightPlan {
  parameter mnv.
  remove mnv.
}

function score {
  parameter data.
  local mnv is node(data[0], data[1], data[2], data[3]).
  addManeuverToFlightPlan(mnv).
  local result is mnv:orbit:eccentricity.
  removeManeuverFromFlightPlan(mnv).
  return result.
}

function improve {
  parameter data.
  local scoreToBeat is score(data).
  local bestCandidate is data.
  local candidates is list(
    list(data[0] + 1, data[1], data[2], data[3]),
    list(data[0] - 1, data[1], data[2], data[3]),
    list(data[0], data[1] + 1, data[2], data[3]),
    list(data[0], data[1] - 1, data[2], data[3]),
    list(data[0], data[1], data[2] + 1, data[3]),
    list(data[0], data[1], data[2] - 1, data[3]),
    list(data[0], data[1], data[2], data[3] + 1),
    list(data[0], data[1], data[2], data[3] - 1)
  ).
  for candidate in candidates {
    local candidateScore is score(candidate).
    if candidateScore < scoreToBeat {
      set scoreToBeat to candidateScore.
      set bestCandidate to candidate.
    }
  }
  return bestCandidate.
}

function executeManeuver {
  parameter mList.
  local mnv is node(mList[0], mList[1], mList[2], mList[3]).
  addManeuverToFlightPlan(mnv).
  local startTime is calculateStartTime(mnv).
  wait until time:seconds > startTime - 10.
  lockSteeringAtManeuverTarget(mnv).
  wait until time:seconds > startTime.
  lock throttle to THROTTLE_LEVEL.
  wait until isManeuverComplete(mnv).
  lock throttle to 0.
  removeManeuverFromFlightPlan(mnv).
}
function lockSteeringAtManeuverTarget {
  parameter mnv.
  lock steering to mnv:burnvector.
}

function isManeuverComplete {
  parameter mnv.
  if not(defined originalVector) or originalVector = -1 {
    declare global originalVector to mnv:burnvector.
  }
  if vang(originalVector, mnv:burnvector) > 90 {
    declare global originalVector to -1.
    return true.
  }
  return false.
}


function calculateStartTime {
  parameter mnv.
  return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

function doLaunch {
  print "Launching...".
  lock throttle to THROTTLE_LEVEL.
  doSafeStage().
}
function maneuverBurnTime {
  parameter mnv.
  local dV is mnv:deltaV:mag.
  local g0 is 9.80665.
  local isp is 0.

  list engines in myEngines.
  for en in myEngines {
    if en:ignition and not en:flameout {
      set isp to isp + (en:isp * (en:maxThrust / ship:maxThrust)).
    }
  }

  local mf is ship:mass / constant():e^(dV / (isp * g0)).
  local fuelFlow is ship:maxThrust / (isp * g0).
  local t is (ship:mass - mf) / fuelFlow.

  return t.
}

function doAscent {
  lock targetPitch to 88.5 - 0.9 * alt:radar^0.38. // Adjusted gravity turn for Earth
  set targetDirection to 90. // Eastward launch
  lock steering to heading(targetDirection, targetPitch).
}

function doAutoStage {
  if not(defined oldThrust) {
    global oldThrust is ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    doSafeStage(). wait 1.
    global oldThrust is ship:availablethrust.
  }
}

function doShutdown {
  lock throttle to 0.
  lock steering to prograde.
  print "Engines Shut Down.".
}

function doSafeStage {
  wait until stage:ready.
  stage.
}

// Start the mission
main().
