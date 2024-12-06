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
  doOrbitalBurn().
  print "Mission Completed!".
  unlock steering.
  wait until false.
}

function doLaunch {
  print "Launching...".
  lock throttle to THROTTLE_LEVEL.
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
  print "Starting orbital burn...".

  // Define the target orbit altitude (e.g., 180 km)
  local targetAltitude is 180000.

  // Calculate the efficient orbit and lock steering
  local node_maneuver is calculateEfficientOrbitAndLockSteering(targetAltitude).

    // Assume `node` is a valid maneuver node created earlier
  local burnTime is maneuverBurnTime(node_maneuver). // Calculate burn time beforehand

  // Call the function to wait for the right burn time
  waitForManeuver(node_maneuver, burnTime).

  // Execute the burn
  lock throttle to 1.
  wait until node_maneuver:deltaV:mag < 1. // Wait until delta-V is nearly zero
  lock throttle to 0.

  // Cleanup
  unlock steering.
  node_maneuver:remove().
  print "Efficient orbit achieved!".

}

function maneuverBurnTime2 {
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

function maneuverBurnTime {
  parameter mnv.
  local dV is mnv:deltaV:mag.  // Delta-V required for the maneuver
  local g0 is 9.80665.          // Standard gravity (m/s^2)
  local ispSum is 0.            // Sum of ISPs weighted by thrust
  local thrustSum is 0.         // Total available thrust

  // Create an empty list to hold engines
  list engines.

  // Iterate over all parts to filter out engines
  for part in ship:parts {
    if part:type = "engine" {  // Check if part is an engine
      engines:add(part).
    }
  }

  // Iterate through each engine to sum ISP and thrust
  for en in engines {
    if en:ignition and not en:flameout {  // Ensure the engine is ignited and not flamed out
      set ispSum to ispSum + (en:isp * en:maxThrust).
      set thrustSum to thrustSum + en:maxThrust.
    }
  }

  // If no engines are active, return 0
  if thrustSum = 0 {
    print "No active engines! Cannot calculate burn time.".
    return 0.
  }

  // Calculate the average ISP based on thrust weighting
  local avgIsp is ispSum / thrustSum.

  // Calculate the fuel flow (rate of fuel consumption based on total thrust)
  local fuelFlow is thrustSum / (avgIsp * g0).

  // Use the Tsiolkovsky rocket equation to calculate the burn time
  local initialMass is ship:mass.
  local finalMass is initialMass / e()^(dV / (avgIsp * g0)). // Final mass after burn

  // Calculate burn time based on the change in mass and fuel flow rate
  local burnTime is (initialMass - finalMass) / fuelFlow.

  return burnTime.
}


function waitForManeuver {
  parameter node. // The maneuver node
  parameter burnTime. // Pre-calculated burn time (optional)

  // If burn time isn't provided, calculate it
  if not(defined burnTime) {
    set burnTime to maneuverBurnTime(node).
  }

  local waitTime is node:eta - burnTime / 2. // Time to start the burn

  if waitTime < time:seconds {
    print "Burn time already passed! Starting immediately.".
    return. // Skip waiting if time has already passed
  }

  print "Waiting for maneuver node...".  
  wait until time:seconds > waitTime.
  print "Time to burn!".
}

function calculateEfficientOrbitAndLockSteering {
  parameter targetAltitude. // Target orbit altitude in meters

  // Constants
  local mu is body:mu.             // Gravitational parameter of the body
  local radius is body:radius.     // Radius of the celestial body

  // Current orbit parameters
  local currentAltitude is ship:orbit:periapsis - radius. // Current altitude at periapsis
  local semiMajorAxis is (radius + currentAltitude + radius + targetAltitude) / 2. // Semi-major axis of transfer

  // Vis-viva equation to calculate velocities
  local v1 is sqrt(mu / (radius + currentAltitude)). // Current velocity at periapsis
  local vTransfer is sqrt(2 * mu / (radius + currentAltitude) - mu / semiMajorAxis). // Velocity needed for transfer orbit
  local deltaV is vTransfer - v1. // Delta-V required for the transfer

  print "Calculating maneuver node for efficient orbit...".

  // Create the maneuver node
  local eta_maneuver is ship:orbit:timeToApoapsis.
  local transferNode is node(time:seconds + eta_maneuver, 0, 0, deltaV).

  // Add the maneuver node directly to the ship
  ship:control:addnode(transferNode).

  // Lock steering to the maneuver node's burn vector
  print "Locking steering to maneuver node burn vector...".
  lock steering to transferNode:burnvector.

  return transferNode. // Return the node for further use if needed
}


// Start the mission
main().
