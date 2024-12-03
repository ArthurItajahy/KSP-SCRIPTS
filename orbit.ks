declare global originalVector to V(0, 0, 0). // Initialize globally.
declare global oldThrust to 0. // Initialize with a default value.

function main {
    print"Starting Launch Sequence".
    doLaunch().
    print"LAUNCH!!".
    doAscent().
    until (apoapsis > 100000) {
        doAutoStage().
    }
    print"Apoapsis reached. Preparing for circularization.".
    wait until (periapsis > 0). // Ensure the craft is still on a suborbital trajectory.

    // Example usage after reaching apoapsis:
    wait until (apoapsis > 100000).
    executeManeuver(time:seconds + 30). // Perform burn 30 seconds after reaching apoapsis.

    print"Orbit achieved! Shutting down.".
    doShutdown().
}
function executeManeuver {
    parameter utime. // Time for the burn.
    print("Calculating automatic circularization burn.").
    
    // Calculate the current orbital parameters.
    local orbitalRadius is body:radius + altitude. // Current orbital radius.
    local mu is body:mu. // Gravitational parameter of the celestial body.
    local v_circular is sqrt(mu / orbitalRadius). // Circular orbital velocity at current altitude.
    local deltaV is v_circular - velocity:orbit:mag. // Required delta-v for circularization.

    // Execute the burn.
    print("Performing circularization burn.").
    lock steering to prograde.
    wait until (time:seconds > utime - 5). // Prepare a few seconds before the burn.
    lock throttle to 1.
    wait until abs(deltaV - velocity:orbit:mag) < 10. // Burn until within 10 m/s of the target velocity.
    lock throttle to 0.1. // Fine-tune with low throttle.
    wait until abs(deltaV - velocity:orbit:mag) < 0.5. // Achieve precision within 0.5 m/s.
    lock throttle to 0.

    print("Circularization complete. Orbit achieved.").
}




function addManeuverToFlightPlan {
    parameter mnv.
    print"Adding node to flight plan.".
    add mnv.
}

function calculateStartTime {
    parameter mnv.
    return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

function lockSteeringAtManeuverTarget {
    parameter mnv.
    lock steering to mnv:burnvector.
}

function isManeuverComplete {
    parameter mnv.
    local currentVector is mnv:burnvector.
    // Check if maneuver has significantly diverged.
    if vang(originalVector, currentVector) > 90 {
        set originalVector to -1. // Reset the global variable.
        return true.
    }
    return false.
}

function removeManeuverFromFlightPlan {
    parameter mnv.
    print"Removing completed maneuver node.".
    remove mnv.
}

function doSafeStage {
    wait until stage:ready.
    print"Separating stage.".
    stage.
}

function doLaunch {
    lock throttle to 1.
    doSafeStage().
}

function doAscent {
    print("Starting ascent.").
    lock targetPitch to 90. // Vertical start.
    until (altitude > 10000) {
        lock steering to heading(90, targetPitch).
        wait 1.
    }
    // Smooth gravity turn.
    until (apoapsis > 100000) {
        set targetPitch to max(10, 88.963 - 1.03287 * alt:radar^0.409511). // Prevent excessive downward pitch.
        lock steering to heading(90, targetPitch).
        wait 1.
    }
    print("Ascent complete. Coasting to apoapsis.").
    lock throttle to 0.
}

function doAutoStage {
    if ship:availableThrust < (oldThrust - 10) {
        doSafeStage().
        wait 1.
        set oldThrust to ship:availableThrust. // Update the global variable.
    }
}

function doShutdown {
    lock throttle to 0.
    lock steering to prograde.
    print"Shutdown complete.".
    wait until false.
}

main().
