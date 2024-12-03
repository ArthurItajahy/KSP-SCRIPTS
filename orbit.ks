// Set the altitudes and other parameters
SET TurnAltitude TO 10000.
SET LevelAltitude TO 45000.
SET OrbitAltitude TO 75000.
SET TargetApoEta TO 10.
SET CircularAltitude TO 80000.

// Initial settings
LOCK STEERING TO UP.
LOCK THROTTLE TO 1.0.

SAS ON.
STAGE.

PRINT "Getting to " + (TurnAltitude / 1000) + "km".

WAIT UNTIL ALTITUDE > TurnAltitude.
SAS OFF.

// Force stage transition if liquid fuel is empty
WAIT UNTIL SHIP:RESOURCE[LiquidFuel] > 0.
WHEN SHIP:RESOURCE[LiquidFuel] = 0 THEN STAGE.

PRINT "Starting first turn".

LOCK STEERING TO HEADING(45, 90).
WAIT UNTIL APOAPSIS > LevelAltitude.

PRINT "Leveling out".

LOCK STEERING TO HEADING(10, 90).
WAIT UNTIL APOAPSIS > OrbitAltitude.

LOCK THROTTLE TO 0.0.
LOCK STEERING TO PROGRADE.

PRINT "Getting to Apoapsis".

WAIT UNTIL ETA:APOAPSIS < TargetApoEta.

PRINT "Circularizing orbit".

LOCK THROTTLE TO 1.0.
WAIT UNTIL APOAPSIS > CircularAltitude.

LOCK THROTTLE TO 0.0.
