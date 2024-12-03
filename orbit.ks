// Efficient Launch Script for Lowest Orbit Possible

// Constants
set targetApoapsis to 70000. // Target orbit apoapsis in meters
set gravityTurnStart to 1000. // Altitude to start gravity turn (meters)
set gravityTurnEnd to 45000. // Altitude to finish gravity turn (meters)
set targetPeriapsis to 70000. // Target periapsis for circular orbit

// Initialization
lock throttle to 1. // Full throttle
lock steering to heading(90, 90). // Point straight up
stage. // Activate the first stage
wait 1. // Allow engines to stabilize

// Gravity Turn
until alt:radar >= gravityTurnStart {
    if stage:liquidfuel <= 0 and stage:solidfuel <= 0 {
        stage. // Stage immediately when fuel is depleted
        wait 0.5. // Allow engines to stabilize
    }
    wait 0.1. // Frequent checks for fuel depletion
}

// Smoothly pitch down for gravity turn
lock steering to heading(90, 70). // Adjust to 70° pitch
wait until alt:radar >= gravityTurnEnd. // Gradual pitch until gravity turn ends
lock steering to heading(90, 45). // Finish gravity turn at 45 km

// Apoapsis Check
until apoapsis >= targetApoapsis {
    if stage:liquidfuel <= 0 and stage:solidfuel <= 0 {
        stage. // Stage immediately when fuel is depleted
        wait 0.5. // Allow engines to stabilize
    }
    wait 0.1. // Frequent checks for fuel depletion
}

// Cut engines at target apoapsis
lock throttle to 0. // Stop burning once apoapsis is reached

// Coast to Apoapsis
wait until eta:apoapsis < 10. // Wait until near apoapsis

// Circularize Orbit
lock steering to prograde. // Point prograde for circularization
lock throttle to 1. // Burn at full throttle 

// Circularization burn control
until periapsis >= targetPeriapsis {
    if periapsis > targetPeriapsis - 500 {
        lock throttle to 0.5. // Reduce throttle for finer control
    }
    if periapsis > targetPeriapsis - 50 {
        lock throttle to 0.1. // Further reduce throttle for precision
    }
    if stage:liquidfuel <= 0 and stage:solidfuel <= 0 {
        stage. // Stage immediately when fuel is depleted
        wait 0.5. // Allow engines to stabilize
    }
    wait 0.1. // Frequent checks for fuel depletion
}

// Finalize Orbit
lock throttle to 0. // Cut throttle after achieving orbit
print "Orbit Achieved: Apoapsis = " + apoapsis + "m, Periapsis = " + periapsis + "m".
