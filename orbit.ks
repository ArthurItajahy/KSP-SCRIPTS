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

FUNCTION doAscent {
    // Define key parameters
    SET targetApoapsis TO 180000. // Target apoapsis in meters (180 km for low Earth orbit)
    SET initialPitch TO 88.5.    // Starting pitch angle
    SET pitchFactor TO 0.9.      // Controls the rate of gravity turn
    SET altitudeExponent TO 0.38. // Exponent for smooth gravity turn

    // Calculate launch azimuth for the Moon's inclination
    SET moonInclination TO 28. // Moon's orbital inclination in degrees
    SET launchAzimuth TO 90 - moonInclination. // Eastward offset for inclination

    // Begin ascent loop
    UNTIL ship:orbit:apoapsis > targetApoapsis {
        // Calculate dynamic pitch adjustment based on radar altitude
        SET targetPitch TO initialPitch - pitchFactor * alt:radar^altitudeExponent.
        LOCK steering TO heading(launchAzimuth, targetPitch). // Match the Moon's orbital inclination

        // Adjust throttle dynamically
        IF alt:radar < 35000 {
            LOCK throttle TO 1. // Full throttle in lower atmosphere
        } ELSE {
            SET throttleAdjustment TO (targetApoapsis - ship:orbit:apoapsis) / targetApoapsis.
            LOCK throttle TO MAX(0.2, MIN(1, throttleAdjustment)). // Throttle between 20% and 100%
        }

        // Auto-staging logic
        doAutoStage().

        // Debugging information
        PRINT "Target pitch: " + ROUND(targetPitch, 2) + "°, Apoapsis: " + ROUND(ship:orbit:apoapsis / 1000, 1) + " km, Throttle: " + ROUND(throttle * 100, 1) + "%.".
        WAIT 0.5. // Short delay for control updates
    }

    // Hold prograde after reaching target apoapsis
    PRINT "Target apoapsis reached. Holding prograde.".
    LOCK steering TO prograde.
    LOCK throttle TO 0. // Temporarily cut throttle
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
  REMOVE circNode.
 

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
