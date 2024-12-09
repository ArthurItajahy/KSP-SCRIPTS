// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accurac

function main {
  startingMission().
  startCountDown().
  doLaunch().
  doAscent().
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

  // Auto-stage configuration
  if not (defined oldThrust) {
    global oldThrust is ship:availablethrust. // Store initial thrust
  }

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
    if ship:availablethrust < (oldThrust - 10) {
      print "Auto-staging...".
      stage. // Trigger next stage
      wait 1. // Allow for staging delay
      set oldThrust to ship:availablethrust. // Update thrust for next stage
    }

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

  // Wait until near apoapsis
  wait until eta:apoapsis < 30. // Adjust this value if needed (30 seconds to apoapsis)

  // Calculate the required burn to circularize
  local mu is body("Earth"):mu. // Gravitational parameter of Earth
  local r is ship:orbit:apoapsis. // Distance to apoapsis
  local v_circular is sqrt(mu / r). // Circular orbital velocity
  local v_current is velocity:orbit:mag. // Current orbital velocity
  local delta_v is v_circular - v_current. // Required delta-V

  print "Delta-V for circularization: " + round(delta_v, 2) + " m/s.".

  // Create a maneuver node
  local circNode is node(time:seconds + eta:apoapsis, 0, delta_v, 0). // Create the burn node
  add circNode.

  // Align to the maneuver node
  lock steering to circNode:burnvector.

  // Wait until burn start time
  local burn_time is calculateBurnTime(delta_v).
  local burn_start_time is time:seconds + eta:apoapsis - burn_time / 2.
  wait until time:seconds > burn_start_time.

  // Execute the burn
  print "Executing circularization burn...".
  lock throttle to 1.
  wait until circNode:deltav:mag < 1.0 or ship:orbit:periapsis > (body("Earth"):radius + 100000). // Cutoff conditions

  // Finish the burn
  lock throttle to 0.
  remove circNode.
  print "Circularization complete! Orbit established.".

  // Final cleanup
  unlock steering.
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
