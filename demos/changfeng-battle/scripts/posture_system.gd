extends RefCounted
## Pure authority-side posture math. Only accepted BattleModel actions call this.
## Posture is accumulated strain, not an action cost or animation frame counter.

func impact(actor, amount: int) -> Dictionary:
    var cap: int = maxi(1,int(actor.stats.get("max_posture",10)))
    var before: int = clampi(int(actor.posture),0,cap)
    actor.posture = before
    if actor.hp_u <= 0 or amount <= 0:
        return {"delta":0,"current":before,"max_posture":cap,"broken":false}
    var accumulated: int = mini(cap,before+amount)
    var broken: bool = accumulated >= cap
    # A broken stance starts recovering from zero. The resolver owns the
    # exposed/opening status, event log and all gameplay reactions.
    actor.posture = 0 if broken else accumulated
    return {"delta":accumulated-before,"current":actor.posture,
        "max_posture":cap,"broken":broken}

func recover(actor, amount: int) -> Dictionary:
    var cap: int = maxi(1,int(actor.stats.get("max_posture",10)))
    var before: int = clampi(int(actor.posture),0,cap)
    actor.posture = before
    if actor.hp_u <= 0 or amount <= 0:
        return {"delta":0,"current":before,"max_posture":cap}
    actor.posture = maxi(0,before-amount)
    return {"delta":before-actor.posture,"current":actor.posture,
        "max_posture":cap}
