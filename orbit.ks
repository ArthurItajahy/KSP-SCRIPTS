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
  SET initialPitch TO 88.5.       // Starting pitch angle
  SET pitchFactor TO 0.9.         // Controls the rate of gravity turn
  SET altitudeExponent TO 0.38.   // Exponent for smooth gravity turn
  SET moonInclination TO 28.6.    // Moon's orbital inclination in degrees
  SET targetDeltaV TO 8.3.        // Target Delta-V in m/s
    
  // Determine launch azimuth based on Moon's inclination
  SET launchAzimuth TO 90 - moonInclination. // Adjust for eastward launch

  // Example to calculate Delta-V manually
  SET Isp TO 350.   // Example specific impulse (seconds)
  SET g0 TO 9.81.   // Standard gravity
  SET initialMass TO ship:mass.  // Get initial mass
  SET fuelAmount TO ship:liquidfuel.  // Get fuel amount in units
  SET fuelMass TO fuelAmount * 5.  // Convert to mass (kg) using assumed density

  // Calculate final mass after fuel is burned
  SET finalMass TO initialMass - fuelMass.

  // Calculate delta-v
  SET deltaV TO Isp * g0 * LOG(initialMass / finalMass).

  PRINT "Calculated Delta-V: " + ROUND(deltaV, 2) + " m/s.".

      PRINT "Launching to Moon's inclination of " + moonInclination + "°.".
      
      // Begin ascent loop
      until ship:deltaV:mag >= targetDeltaV {
          // Calculate dynamic pitch based on altitude
          SET targetPitch TO initialPitch - pitchFactor * alt:radar^altitudeExponent.
          LOCK steering TO heading(launchAzimuth, targetPitch). // Align with Moon's inclination

          // Adjust throttle dynamically
          IF alt:radar < 35000 {
              LOCK throttle TO 1. // Full throttle below 35 km
          } ELSE {
              LOCK throttle TO 0.7. // Reduce throttle for upper atmosphere
          }

          // Auto-staging logic
          doAutoStage().
          
          // Debugging information
          PRINT "Pitch: " + ROUND(targetPitch, 2) + "°, Altitude: " + ROUND(alt:radar / 1000, 1) + " km, Delta-V: " + ROUND(ship:deltaV:mag, 2) + " m/s.".
          
          WAIT 0.5. // Small delay for control updates
      }

      // Once the target Delta-V is achieved, cut the throttle
      LOCK throttle TO 0.
      PRINT "Target Delta-V reached. Burn complete.".
      
      // Final adjustments in space
      PRINT "Orbit inclination matched with Moon. Shutting down engines.".
      LOCK steering TO prograde. // Maintain current direction for stability
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
