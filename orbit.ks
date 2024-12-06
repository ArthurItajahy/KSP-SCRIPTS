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
  local mnv is node(data[0], data[1], data[2], data[3]).
  addManeuverToFlightPlan(mnv).

  local semiMajorAxis is mnv:orbit:semiMajorAxis.
  local eccentricity is mnv:orbit:eccentricity.
  local periapsisAltitude is mnv:orbit:periapsis - body("Earth"):radius.

  if periapsisAltitude < 0 {
    removeManeuverFromFlightPlan(mnv).
    return 1e9.
  }

  local scoreResult is abs(eccentricity) * 1000 + abs(semiMajorAxis - targetSemiMajorAxis).
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
  local mnv is node(mList[0], mList[1], mList[2], mList[3]).
  addManeuverToFlightPlan(mnv).

  local startTime is calculateStartTime(mnv).

  lockSteeringAtManeuverTarget(mnv).

  wait until time:seconds > startTime - 10.
  
  // Calculate fuel mass and max fuel mass
  local fuelMass is ship:mass - ship:dryMass. // Current fuel mass
  local maxFuelMass is ship:maxFuelMass. // Maximum fuel mass at launch
  
  // Start the burn
  wait until time:seconds > startTime.
  lock throttle to 0.5. // Start with half throttle to prevent overshoot

  until isManeuverComplete(mnv) or ship:orbit:periapsis > 100000 {
    // Dynamically adjust throttle based on fuel mass
    local throttleAdjustment is 0.5 + (fuelMass / maxFuelMass) * 0.5.
    lock throttle to throttleAdjustment.
    
    // Update fuel mass for the next loop (assuming fuel consumption)
    set fuelMass to ship:mass - ship:dryMass.
    
    wait 3.
  }

  lock throttle to 0. // Stop the burn
  
  removeManeuverFromFlightPlan(mnv).

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
  local idealBurnTime is time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
  return idealBurnTime.
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
   // Lock steering to the maneuver's burn vector with a smoother control
   set burnVector to mnv:burnvector.
   set progradeDirection to mnv:orbit:prograde.
   
   if (isManeuverComplete(mnv)) {
      // Lock to prograde when close to burn completion
      lock steering to progradeDirection.
   } else {
      lock steering to burnVector.
   }
}


function isManeuverComplete {
  parameter mnv.

  // Get the remaining delta-v for the maneuver
  local remainingDeltaV is mnv:deltav:mag.
  
  // Threshold for considering the burn complete
  local completionThreshold is 0.5. // Adjust as needed (m/s)
  
  // Check if the remaining delta-v is below the threshold
  if remainingDeltaV < completionThreshold {
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
