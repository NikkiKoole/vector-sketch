local lib = {}


lib.allBehaviors = {
    { name = 'KEEP_ANGLE',
      description = 'keep a body at a certain angle, still not completely settled on the other variables. Kp*I etc.' },
    { name = 'LIMB_HUB',
      description = 'a polygon that has things attached, the location where is defined in here, '
        .. 'by its edge number and a lerp between vertex -1 and vertex.' },
    { name = 'SIGNAL_BUTTON',
      description = 'tap it to send its signal (default gate1) to receivers (src/signals.lua).' },
    { name = 'SIGNAL_PLATE',
      description = 'pressure plate: anything resting on it sends its signal; hold mode sends again when free.' },
    { name = 'SIGNAL_GATE',
      description = 'a body on a prismatic joint; toggles open/closed on its signal (src/signals.lua).' },
    { name = 'SQUISHY',
      description = 'soft prop: plays a winegum-kiss sound when it hits something (src/mipo-voice.lua).' },
}


return lib
