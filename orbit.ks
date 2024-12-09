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

    // Calculate launch azimuth for Moon's orbital inclination
    SET earthLatitude TO 28.5.    // Latitude of Cape Canaveral in degrees
    SET moonInclination TO 28.6.  // Moon's orbital inclination in degrees
    SET launchAzimuth TO ARCSIN(COS(moonInclination) / COS(earthLatitude)). // Adjust for Earth's rotation

    // Ascent loop
    UNTIL ship:orbit:apoapsis > targetApoapsis {
        // Calculate dynamic pitch adjustment
        SET targetPitch TO initialPitch - pitchFactor * alt:radar^altitudeExponent.
        LOCK steering TO heading(launchAzimuth, targetPitch). // Steer towards the Moon's inclination

        // Adjust throttle dynamically
        IF alt:radar < 35000 {
            LOCK throttle TO 1. // Full throttle below 35 km
        } ELSE {
            SET throttleAdjustment TO (targetApoapsis - ship:orbit:apoapsis) / targetApoapsis.
            LOCK throttle TO MAX(0.2, MIN(1, throttleAdjustment)). // Between 20% and 100%
        }

        // Auto-staging
        doAutoStage().

        // Debugging information
        PRINT "Pitch: " + ROUND(targetPitch, 2) + "°, Apoapsis: " + ROUND(ship:orbit:apoapsis / 1000, 1) + " km, Throttle: " + ROUND(throttle * 100, 1) + "%.".
        WAIT 0.5.
    }

    // Hold prograde for circularization
    PRINT "Target apoapsis reached. Holding prograde.".
    LOCK steering TO prograde.
    LOCK throttle TO 0.
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
