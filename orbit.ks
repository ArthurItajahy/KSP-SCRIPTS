// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accuracy

global targetAltitude is 200000. // Target altitude in meters
global targetSemiMajorAxis is body("Earth"):radius + targetAltitude.

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
  doOrbitalBurn().
  print "Mission Completed!".
  unlock steering.
  wait until false.
}

function doLaunch {
  print "Launching...".
  lock throttle to 1.
  doSafeStage().
  wait 3.
  doSafeStage().
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


function doOrbitalBurn {
  local circ is list(time:seconds + 30, 0, 0, 0).
  until false {
    local oldScore is score(circ).
    set circ to improve(circ).
    if oldScore <= score(circ) {
      break.
    }
  }
  executeManeuver(circ).
}

function score {
  parameter data.

  // Create a maneuver node with the candidate data
  local mnv is node(data[0], data[1], data[2], data[3]).
  addManeuverToFlightPlan(mnv).

  // Get orbital parameters from the maneuver node
  local semiMajorAxis is mnv:orbit:semiMajorAxis.
  local eccentricity is mnv:orbit:eccentricity.
  local periapsisAltitude is mnv:orbit:periapsis - body("Earth"):radius. // Calculate periapsis altitude

  // Check if the periapsis altitude is below the Earth's surface
  if periapsisAltitude < 0 {
    removeManeuverFromFlightPlan(mnv).
    return 1e9. // Penalize invalid orbits heavily
  }

  // Calculate a meaningful score, prioritizing near-circular orbits
  local scoreResult is abs(eccentricity) * 1000 + abs(semiMajorAxis - targetSemiMajorAxis).

  // Remove the temporary maneuver node
  removeManeuverFromFlightPlan(mnv).

  return scoreResult.
}

function improve {
  parameter data.
  local scoreToBeat is score(data).
  local bestCandidate is data.
  
  // Increase the step sizes to match realistic orbital changes
  local stepSize is 100. // Larger step size for maneuvers (adjust as needed)
  
  // Generate candidates with larger changes
  local candidates is list(
    list(data[0] + stepSize, data[1], data[2], data[3]),
    list(data[0] - stepSize, data[1], data[2], data[3]),
    list(data[0], data[1] + stepSize, data[2], data[3]),
    list(data[0], data[1] - stepSize, data[2], data[3]),
    list(data[0], data[1], data[2] + stepSize, data[3]),
    list(data[0], data[1], data[2] - stepSize, data[3]),
    list(data[0], data[1], data[2], data[3] + stepSize),
    list(data[0], data[1], data[2], data[3] - stepSize)
  ).
  
  // Test each candidate's score
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
  
  // Create the maneuver node
  local mnv is node(mList[0], mList[1], mList[2], mList[3]).
  addManeuverToFlightPlan(mnv).

  // Calculate the start time for the burn
  local startTime is calculateStartTime(mnv).
  wait until time:seconds > startTime - 10.
  
  // Align to the burn vector
  lockSteeringAtManeuverTarget(mnv).

  // Start the burn
  wait until time:seconds > startTime.
  lock throttle to 1.
  
  // Execute the burn while checking for staging and orbit insertion
  until isManeuverComplete(mnv) or ship:orbit:periapsis > 100000 { // Ensure periapsis > 100 km (adjust for Realism Overhaul)
    // Check if fuel is low
    doAutoStage().
    wait 0.5. // Short delay to avoid performance issues
  }

  // Stop the burn
  lock throttle to 0.
  
  // Remove the maneuver node
  removeManeuverFromFlightPlan(mnv).

  // Final check to ensure orbit is stable
  if ship:orbit:periapsis > 100000 {
    print "Maneuver complete: Orbit achieved!".
  } else {
    print "Warning: Orbit not stable. Additional burn required.".
  }
}

function addManeuverToFlightPlan {
  parameter mnv.
  add mnv.
}

function calculateStartTime {
  parameter mnv.
  return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

function maneuverBurnTime {
  parameter mnv.

  local dV is mnv:deltaV:mag. // Delta-V for the maneuver
  local g0 is 9.80665.        // Standard gravity (m/s^2)
  local isp is 0.             // Initialize ISP
  local thrust is 0.          // Initialize thrust

  // Check if engines are active
  list engines in myEngines.
  for en in myEngines {
    if en:ignition and not en:flameout {
      set isp to isp + (en:isp * (en:maxThrust / ship:maxThrust)).
      set thrust to thrust + en:maxThrust.
    }
  }

  // If no engines are active, handle gracefully
  if isp <= 0 or thrust <= 0 {
    print "Warning: No active engines. Using estimated ISP and thrust.".
    set isp to 300. // Use an average ISP (adjust based on typical engine ISP)
    set thrust to 100000. // Use a rough estimate of thrust (adjust as needed)
  }

  // Compute burn time
  local initialMass is ship:mass.
  local finalMass is initialMass / constant():e^(dV / (isp * g0)).
  local fuelFlow is thrust / (isp * g0).
  local t is (initialMass - finalMass) / fuelFlow.

  return t.
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

function removeManeuverFromFlightPlan {
  parameter mnv.
  remove mnv.
}

// Start the mission
main().
