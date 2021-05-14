text = """~~~~~~~~~~~~~~~ CONTROLS ~~~~~~~~~~~~~~~

TOGGLE TIMESTEP (HOW MUCH TIME PASSES EACH FRAME) ...... RIGHT ARRROW (FASTER) / LEFT ARROW (SLOWER)              

TOGGLE VISCOSITY ....................................... UP ARROW (HIGHER VISCOSITY) / DOWN ARROW (LOWER VISCOSITY)

TOGGLE DIFFUSION RATE .................................. + (HIGHER) / - (LOWER)                                    

CHANGE COLOR MODE TO GRAYSCALE ......................... 1                                                         

CHANGE COLOR MODE TO RED ............................... 2                                                         

CHANGE COLOR MODE TO GREEN ............................. 3                                                         

CHANGE COLOR MODE TO BLUE .............................. 4                                                         

CHANGE COLOR MODE TO RGB TRANSITIONS ................... 5                                                         """
out = ""
for i in text.split('\n'):
    out += "db \"|" + ' ' * ((117 - len(i)) // 2) + i + ' ' * ((117 - len(i)) // 2) + ("|" if len(i) % 2 == 1 else " |") + "\",13,10\n"

print(out)    