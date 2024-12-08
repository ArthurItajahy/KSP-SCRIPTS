// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accurac

function main {

  startCountDown().
  doLaunch().
  doAscent().
  
  until apoapsis > 180000 { // Target: 180 km Low Earth Orbit
    wait 3.
    doAutoStage().
   wait 3.
  }
  lock steering to heading(87, 0).
  until periapsis > 100000 { // Target: 180 km Low Earth Orbit
    wait 3.
    doAutoStage().
  }

  // End of the program - Unlock all controls
  lock throttle to 0.  // Set throttle to 0 to stop any engine burns
  doSafeStage().

 


  print "Mission Completed!".  // Print mission completion message

  // Unlock all controls
  unlock steering.  // Unlock steering control
  unlock throttle.  // Unlock throttle control (optional, as throttle is already set to 0)


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
  lock targetPitch to 88.5 - 0.9 * alt:radar^0.38. // Adjusted gravity turn for Earth
  set targetDirection to 90. // Eastward launch
  lock steering to heading(targetDirection, targetPitch).
  print targetPitch.
}

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
