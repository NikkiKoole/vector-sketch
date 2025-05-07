local lib = {}


lib.allBehaviors = {
    { name = 'KEEP_ANGLE', description = 'keep a body at a certain angle, still not completely settled on the other variables. Kp*I etc.' },
    { name = 'LIMB_HUB',   description = 'a polygon that has limbs attached, the location where the limbs start is defined in here, by its edge number and a lerp between vertex -1 and vertex.' }
}


return lib
