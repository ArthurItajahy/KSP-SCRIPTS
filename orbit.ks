// Functional Launch Script for Earth
// TODO: Adjust throttle dynamically based on atmospheric pressure
// TODO: Incorporate engine ignitions and ullage calculations
// TODO: Enhance maneuver convergence accurac

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
  until periapsis > 100000 { // Target: 180 km Low Earth Orbit
    wait 3.
    doAutoStage().
  }
  
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
function doOrbitalBurn {

  // Start with a steep angle and gradually reduce the pitch to adjust the orbit
  // Gradually decrease pitch to achieve the desired periapsis around 100 km
  // Until periapsis reaches 100 km
  // Adjust pitch gradually based on altitude (from steep to gentle)
  lock targetPitch to 135 - 0.1 * alt:radar. // Gentle reduction of pitch with altitude
  lock steering to heading(90, targetPitch). // Lock heading to eastward (90°) and adjust pitch

   wait 1.

  
}

function doAutoStage {
  if not(defined oldThrust) {
    global oldThrust is ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    doSafeStage(). wait 4.
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



// Start the mission
main().
