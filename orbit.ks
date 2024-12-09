// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accurac

function main {
  startingMission().
  startCountDown().
  doLaunch().
  doAscent().
  doCircularization().
  doSafeStage().

 


  print "Mission Completed!".  // Print mission completion message

  // Unlock all controls
  unlock steering.  // Unlock steering control
  unlock throttle.  // Unlock throttle control (optional, as throttle is already set to 0)

  // End Script
  // Stop the script
  print "Script completed successfully!".  // Inform the user
  wait until false.  // Prevent the script from executing further

}
function startingMission{
  PRINT "=========================================".
  PRINT "      MISSION: LOW ORBIT SATELLITE".
  PRINT "        ROCKET: ARARA-90-STAR-ONE".
  PRINT "=========================================".
}
function startCountDown{
  PRINT "Counting down:".
  FROM {local countdown is 10.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. // pauses the script here for 1 second.
  }
}

function doLaunch {
  print "Launching...".
  lock throttle to 1.
  doSafeStage().
  wait 3.
  doSafeStage().
}

function doAscent {
  // Define key parameters
  set targetApoapsis to 180000. // Target apoapsis in meters (180 km for low Earth orbit)
  set initialPitch to 88.5. // Starting pitch angle
  set pitchFactor to 0.9. // Controls the rate of gravity turn
  set altitudeExponent to 0.38. // Exponent for smooth gravity turn

  // Target direction is already aligned with the Moon's inclination
  set targetDirection to 87. // Close to eastward

  // Ascent loop
  until ship:orbit:apoapsis > targetApoapsis {
    // Calculate dynamic pitch adjustment based on radar altitude
    set targetPitch to initialPitch - pitchFactor * alt:radar^altitudeExponent.
    lock steering to heading(targetDirection, targetPitch). // Update heading dynamically

    // Adjust throttle dynamically to control ascent
    if alt:radar < 35000 {
      // Full throttle in lower atmosphere
      lock throttle to 1.
    } else {
      // Reduce throttle as apoapsis approaches target
      set throttleAdjustment to (targetApoapsis - ship:orbit:apoapsis) / targetApoapsis.
      lock throttle to max(0.2, min(1, throttleAdjustment)). // Throttle between 20% and 100%
    }

    // Auto-staging logic
    doAutoStage().

    // Print debugging information
    print "Target pitch: " + round(targetPitch, 2) + "°, Apoapsis: " + round(ship:orbit:apoapsis / 1000, 1) + " km, Throttle: " + round(throttle * 100, 1) + "%.".

    wait 0.5. // Short delay for control updates
  }

  // Once target apoapsis is reached, hold prograde for efficiency
  print "Target apoapsis reached. Holding prograde.".
  lock steering to prograde.
  lock throttle to 0. // Cut throttle temporarily
}

function doCircularization {
  print "Preparing for circularization...".

  // Calculate the required burn to circularize
  local mu is body("Earth"):mu. // Gravitational parameter of Earth
  local r_apoasis is ship:orbit:apoapsis. // Distance to apoapsis
  local v_circular is sqrt(mu / r_apoasis). // Circular orbital velocity
  local v_current is velocity:orbit:mag. // Current orbital velocity
  local delta_v is v_circular - v_current. // Required delta-V

  print "Delta-V for circularization: " + round(delta_v, 2) + " m/s.".

  // Create a maneuver node
  local circNode is node(time:seconds + eta:apoapsis, 0, delta_v, 0). // Create the burn node
  add circNode.

  // Align to the maneuver node
  lock steering to circNode:burnvector.
// Start main burn
  LOCK THROTTLE TO 1. // Ensure throttle is set to full initially

  UNTIL SHIP:VELOCITY:SURFACE:MAG > 8300 {
      DOAUTOSTAGE(). // Auto-stage if necessary
      PRINT "Speed: " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 2) + " m/s, Periapsis: " + ROUND(SHIP:ORBIT:PERIAPSIS / 1000, 2) + " km" AT (0, 0). // Debugging info
      WAIT 0.1. // Small delay to reduce CPU usage
  }

  // Reduce throttle for precision burn
  LOCK THROTTLE TO 0.2. 
  PRINT "Fine-tuning to reach target velocity...".

  UNTIL SHIP:VELOCITY:SURFACE:MAG > 8300.1 OR SHIP:ORBIT:PERIAPSIS > (BODY("Earth"):RADIUS + 100000) {
      // Monitor burn progress
      PRINT "Speed: " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 2) + " m/s, Periapsis: " + ROUND(SHIP:ORBIT:PERIAPSIS / 1000, 2) + " km" AT (0, 0).
      WAIT 0.1. // Short delay for real-time updates
  }

  // Stop the burn
  LOCK THROTTLE TO 0.
  PRINT "Target velocity of 8.3 km/s achieved. Circularization complete!".
  // Remove the node if it still exists
  IF circNode:exists {
      REMOVE circNode.
  }

  // Final message
  PRINT "Circularization complete! Orbit established.".

  // Final cleanup
  UNLOCK STEERING.
}
function calculateBurnTime {
  parameter delta_v.

  // Get engine parameters
  local isp is 0.
  local thrust is 0.

  list engines in myEngines.
  for en in myEngines {
    if en:ignition and not en:flameout {
      set isp to isp + (en:isp * (en:maxThrust / ship:maxThrust)).
      set thrust to thrust + en:maxThrust.
    }
  }

  // Handle cases with no active engines
  if isp <= 0 or thrust <= 0 {
    print "Warning: No active engines detected. Using estimated ISP and thrust.".
    set isp to 300. // Typical vacuum ISP
    set thrust to 100000. // Estimated thrust
  }

  // Compute burn time
  local g0 is 9.80665. // Standard gravity
  local initialMass is ship:mass.
  local finalMass is initialMass / constant():e^(delta_v / (isp * g0)).
  local fuelFlow is thrust / (isp * g0).
  local burnTime is (initialMass - finalMass) / fuelFlow.

  return burnTime.
}

//function doAscent {
//  lock targetPitch to 88.5 - 0.9 * alt:radar^0.38. // Adjusted gravity turn for Earth
 // set targetDirection to 87. // Eastward launch
 // lock steering to heading(targetDirection, targetPitch).
//  print targetPitch.
//}

function doAutoStage {
  if not(defined oldThrust) {
    global oldThrust is ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    doSafeStage(). wait 4.
    lock throttle to 0.3.
    wait 5.
    lock throttle to 0.7.
    wait 5.
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


// IKNOW 
//Iknow
// Start the mission
main().
