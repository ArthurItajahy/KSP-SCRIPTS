

lock throttle to 1.
stage.
wait 0.5.  // Give the stage some time to activate.
until ship:maxthrust > 0 { stage. wait 1. }

lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
set targetDirection to 90.
lock steering to heading(targetDirection, targetPitch).

set availThrust to ship:availablethrust.

until apoapsis > 100 {
  if ship:availablethrust < (availThrust - 10) {
    stage.
    wait 1.
    set availThrust to ship:availablethrust.
  }
}

lock throttle to 0.
lock steering to prograde.
