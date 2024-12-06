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

  // Define constants for the target altitude and threshold orbital speed
  local targetAltitude is 180000. // 180 km in meters
  local targetSpeed is sqrt(body:mu / (body:radius + targetAltitude)). // Calculate required orbital speed using vis-viva equation

  // Wait until the ship is at the target altitude
  wait until alt:radar >= targetAltitude.
  print "Reached target altitude, locking orientation to prograde...".

  // Lock to current prograde orientation
  lock steering to ship:velocity:surface:normalized.

  // Engage throttle to full
  lock throttle to 1.0.

   until ship:velocity:surface:mag <= targetSpeed { // Target: Will autoStage untill get to space
    wait 3.
    doAutoStage().
    wait 3.
  }

  // Wait until the ship's speed matches or exceeds the target orbital speed
  wait until ship:velocity:surface:mag >= targetSpeed.
  print "Achieved target orbital speed, cutting throttle.".

  // Stop the engines
  lock throttle to 0.

  // Release control of the steering
  unlock steering.
  print "Orbital burn complete, control released.".
}



// Start the mission
main().
