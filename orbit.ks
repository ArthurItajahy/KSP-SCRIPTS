//Function Launch Script

function main{
    
    doLaunch().
    print"LAUNCH!!".
    doAscent().
    until apoapsis > 100000{
        
        doAutoStage().
    }
    print"Shutdown in 10 seconds".
    wait 0.9.
    executeManeuver(time:seconds + 30, 100, 100, 100).
    doShutdown().
}
function executeManeuver{
    parameter utime, radial, normal, prograde.
    local mnv is node(utime, radial, normal, prograde).
    addManeuverToFlightPlan(mnv).
    local startTime is calculateStartTime(mnv).
    wait until time:seconds > startTime - 10.
    lockSteeringAtManeuverTarget(mnv).
    wait until time:seconds > startTime.
    lock throttle to 1.
    wait until isManeuverComplete(mnv).
    lock throttle to 0.
    removeManeuverFromFlightPlan(mnv).
}

function  addManeuverToFlightPlan {
    parameter mnv.
    //TODO
}

function  calculateStartTime {
    parameter mnv.
    // TODO
    return 0.
}

function lockSteeringAtManeuverTarget{
    // TODO
    parameter mnv.

}

function isManeuverComplete{
    parameter mnv.
    //TODO
    return true.
}
function removeManeuverFromFlightPlan{
    //TODO
    parameter mnv.
}


function doSafeStage{
    wait until stage:ready.
    print"Separating!".
    stage.
}

function doLaunch{ 
    lock throttle to 1.
    doSafeStage().
}



function doAscent{
    print"Doing the Ascend".
    lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
    set targetDirection to 90.
    lock steering to heading(targetDirection, targetPitch).
}


function doAutoStage{
    if not(defined oldThrust) {
        
        declare global oldThrust to ship:availableThrust.
    }
    if ship:availablethrust < (oldThrust - 10){
        doSafeStage(). wait 1.
        declare global oldThrust to ship:availablethrust.
    }
}


function doShutdown{
    lock throttle to 0.
    lock steering to prograde.

    wait until false.
}

main().
