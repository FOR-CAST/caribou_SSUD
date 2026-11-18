# caribou_SSUD

A [SpaDES](https://spades.predictiveecology.org/) module that maps where caribou are expected to
spend their time. It takes the coefficients of a caribou integrated step-selection analysis (iSSA:
a model of which habitat caribou choose as they move) and turns them into a steady-state
utilization distribution (SSUD; [Potts & Schlaegel 2020](https://besjournals.onlinelibrary.wiley.com/doi/full/10.1111/2041-210X.13406)): the relative share of time an animal is expected to
spend in each map cell over the long run.

The module makes a baseline map from the current landscape. In dynamic mode, it also makes a map
for each forecast year as the landscape changes (e.g. with fire, forest growth and new roads and
mines from other SpaDES modules).

The module's manual, [caribou_SSUD.md](caribou_SSUD.md), lists its inputs, parameters and outputs.
It is made from `caribou_SSUD.Rmd`; changes are listed in [NEWS.md](NEWS.md).
