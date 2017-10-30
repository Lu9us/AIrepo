; TODO
; - work out a balancing equation between the spending-on-land-density and spending-on-goods in the utility function, think of it like a see-saw
; - study emergence through parameters

extensions [table]

globals [wage-min wage-max patch-search-set  perc-best-homed-people dif-between-g-and-l]

breed [people person]
breed [landlords landlord]
breed [firms firm]

people-own [firm! home! selected-patch land-density-cost lov budget product-cost spending-on-land-density spending-on-goods utility income]
landlords-own [base-land-cost net-stock-level home-x home-y p-color]
firms-own [wage-output base-product-cost]
patches-own [p-land-cost landlord! occupant]

to setup
  clear-all
  ask patches [set pcolor black]
  if (land-or-density = "land")
  [ setup-landlords ]
  if (land-or-density = "density")
  [ setup-density ]
  setup-firms
  setup-people
  set patch-search-set patch-set patches with [not any? firms in-radius 3]
  reset-ticks
end

to setup-landlords
  create-landlords num-landlords
  ask landlords [
    set base-land-cost ((round random 40) + 1) * 0.25
    set p-color ( one-of [0 10 20 30 40 50 60 70 80 90 110 120 130] + one-of [3 4 5 6 7 8 9] )
    ifelse (landlords-visible = true)
    [ set color (p-color - 3)]
    [ set hidden? true ]
    setxy random-xcor random-ycor
    ;ask patch-here [set pcolor p-color]
    set pcolor p-color
    ask patch-here [
      set p-land-cost [base-land-cost] of myself
      set landlord! myself
    ]
    set home-x pxcor
    set home-y pycor
  ]
  while [any? patches with [pcolor = black]] [
    let patches-count count patches
    let patches-assigned count patches with [pcolor != black]
    let assigned% (patches-assigned / patches-count * 100)

    ; landlords set up their patches with their properties,
    ; then after 10% is mapped use cellular automata to map the rest
    ifelse (assigned% < 10)
    [ setup-landlord-patches ]
    [ setup-cellular-landlord-patches ]
  ]

  ask landlords [
   setxy home-x home-y
  ]
end

to setup-landlord-patches
  ask landlords [
    set heading 0
    right one-of [ 0 90 180 270 ]
    fd 1
    ifelse (pcolor = black)
    [
      set pcolor p-color
      ask patch-here [
        set p-land-cost [base-land-cost] of myself
        set landlord! myself
      ]
    ]
    [
      ifelse (pcolor = p-color)
      [  ] ;do nothing
      [ right 180 fd 1 ]
    ]
  ]
  ask patches [
    if pcolor = black [
      if ( all? neighbors4 [landlord! = [landlord!] of one-of neighbors4 and landlord! != 0] )
      [
        set pcolor [pcolor] of one-of neighbors4
        set p-land-cost [p-land-cost] of one-of neighbors4
        set landlord! [landlord!] of one-of neighbors4
      ]
    ]
  ]
end

to setup-cellular-landlord-patches
  ask patches with [pcolor = black] [
    let clone-patch one-of neighbors4 with [pcolor != black]
    if(clone-patch != nobody) [
     set p-land-cost [p-land-cost] of clone-patch
     set landlord! [landlord!] of clone-patch
     set pcolor [pcolor] of clone-patch
    ]
  ]
end

to setup-density
  ask patches [set pcolor 2]
end

to setup-firms
  let wage-list []

  create-firms num-firms
  ask firms [
    while [wage-output = 0 or member? wage-output wage-list] [
      set wage-output round (random (wage-gap * num-firms) + 0.5)
    ]
    set wage-list (lput wage-output wage-list)

    set base-product-cost 1

    set label wage-output
    set label-color white
    set color ((wage-output * 10) + 5)
    set shape "pentagon_ol"
    set size 6

    while [(xcor = 0 and ycor = 0)]
    [
      ; radius around firms limits the size you are able to set the city radius
      move-to one-of patches in-radius ((city-radius% / 100) * (max-pxcor * 2)) with [ not any? firms in-radius 8 ]
    ]
  ]
end

to setup-people
  create-people num-people
  ask people [
    set firm! one-of firms
    set lov ( lov-median + random (lov-range * random+-) )

    set color [color] of firm!
    set shape "person"
    setxy random-xcor random-ycor
  ]
end

; GO

to go
  if(landlords-change-land-costs)
  [landlord-cost-adjust]
  people-set-attributes
  people-search
  tick
end

to people-set-attributes
  ask people [
   set home! patch-here
   set budget get-budget(home!)
   set product-cost get-product-cost(home!)
   set spending-on-goods get-spending-on-goods(home!)
   set spending-on-land-density get-spending-on-land-density(home!)
   set utility calculate-utility(home!)
  ]
end

to people-search
  ask people [
    let utility-temp (utility)
    let ten-random-patches []
    ask n-of 10 other patch-search-set with [not any? people-here] [set ten-random-patches lput self ten-random-patches]

    let i 0
    while [ i < length ten-random-patches] [
      let p-utility calculate-utility(item i ten-random-patches)
      if (p-utility >= 0) [
        if (p-utility > utility-temp)[
            set selected-patch item i ten-random-patches
            set utility-temp (p-utility)
        ]
      ]
      set i (i + 1)
    ]
    if (selected-patch != 0) [
      move-to selected-patch
      claim-patch selected-patch
    ]
  ]
end

to landLord-cost-adjust
  ask-concurrent landlords [
    ; get reference to current landlord for use later
    let landlord_self self
    ; allocate temp varibles
    let price-change 0
    let stock count patches with [landlord! = landlord_self]
    let used-stock 0
    ;count number of patches with people on
    ask patches with [landlord! = landlord_self] [
      if(any? people-on self) [
        set used-stock used-stock + count people-on self
      ]
    ]

    ;percentage of the stock before landlord starts lowering prices
    ;should be 100 but we never get stock use that high
    let stock-balance (stock / 100) * 50
    ;calc stock avalible
    set net-stock-level  stock - used-stock

    let c-landlord count landlords
    let c-people count people
    let avg (c-people / c-landlord)

    if-else(used-stock > avg)
    [ set price-change  1 ]
    [ set price-change  -1 ]

    ; if the stocked avalible is more than the target start reducing prices
    set price-change  ( (stock-balance - net-stock-level) / 75 )

    ;set price
    set base-land-cost base-land-cost + price-change

    ; min stock value
    if(base-land-cost < 1 )
    [set base-land-cost  1]
    ; show(ll)
    ; show(base-land-cost)

    ; assign new value to patches
    ask patches with [landlord! = landlord_self] [
      set p-land-cost [base-land-cost] of landlord_self
    ]
  ]
  ask patches [set pcolor (p-land-cost + 10)]
end

to-report get-budget [patch!]
  let dist 0
  ask firm! [ set dist (distance patch!) ]
  report ( [wage-output] of firm! - ((commute-cost-per-patch) * dist) )
end

to-report get-product-cost [patch!]
  report [base-product-cost] of firm! + ((delivery-cost))
end

to-report get-spending-on-goods [patch!]
  let land-or-density-cost 0
  if (land-or-density = "land")
  [set land-or-density-cost [p-land-cost] of patch!]
  if (land-or-density = "density")
  [set land-or-density-cost ( get-density-cost(self) )]

  report ( ( get-product-cost(patch!) ^ (1 / (lov - 1)) ) * get-budget(patch!))
                                         /
                    ( land-or-density-cost ^ (lov / (lov - 1)) )
end

to-report get-spending-on-land-density [patch!]
  let land-or-density-cost 0
  if (land-or-density = "land")
  [set land-or-density-cost [p-land-cost] of patch!]
  if (land-or-density = "density")
  [set land-or-density-cost ( get-density-cost(self) )]

  report ( land-or-density-cost ^ ((1 / (lov - 1)) * get-budget(patch!)) )
                                       /
                ( get-product-cost(patch!) ^ (lov / (lov - 1)) )
end

to-report get-utility
  report (( spending-on-goods ^ lov ) + ( spending-on-land-density ^ lov )) ^ (1 / lov)
end

to-report calculate-utility [patch!]
  ifelse (get-budget(patch!) <= 0)
  [ report -1]
  [  set dif-between-g-and-l ( dif-between-g-and-l + ( get-spending-on-goods(patch!) -  get-spending-on-land-density(patch!) ) )
    report (( get-spending-on-goods(patch!) ^ lov ) + ( get-spending-on-land-density(patch!) ^ lov )) ^ (1 / lov) ]
end

; no bidding version
to claim-patch [_patch]
  ask _patch [set occupant myself]
end

to-report get-density-cost [person_]
  let density-sum 0
  let density-calc 0
  let neighbors-in-bubble other people in-radius personal-bubble
  if (count neighbors-in-bubble >= 1) [
    ask neighbors-in-bubble [

      let dist  ( distance person_ )

      let dist-sum  ( 1 -( dist / personal-bubble ))
      set density-sum  ( density-sum + dist-sum )
    ]
    set density-calc ( density-sum / count neighbors-in-bubble)
  ]
  ask person_ [set land-density-cost ((density-calc * 10) + 1)]
  report ( ((density-calc * 10) + 1) )
end

; Only use for patches that the person isn't on
to-report calculate-patch-firm-distance [patch!]
  ; cosine rule:
  ; a² = b² + c² - (2bc * cosA)
  let b (distance patch!)
  let c (distance firm!)

  ; "towards" errors when finding the angle between the same two patches,
  ; sometimes we do this for finding parameters at current patch for people
  ; so we needed a check
  let A abs( towards-with-null-check(patch!) - towards-with-null-check(firm!) )
  report sqrt ( b ^(2) + c ^(2) - ((2 * b * c) * cos(A)) )
end

to-report towards-with-null-check [patch!]
  ifelse(patch! = patch-here and pycor != [pycor] of patch-here and pxcor != [pxcor] of patch-here)
  [ report towards(patch!) ]
  [ report 0 ]
end

to-report calculate-patch-firm-distance-pythagoras [patch!]
  ; only works with right-angled triangles
  report sqrt ((distance patch!)^(2) + (distance firm!)^(2))
end


; Utilities

to-report check-val[val]
  if(val < 0) [
    report(0)
  ]
  report(val)
end

to-report random+-
  report one-of [1 -1]
end

to percentage-of-best-homed-people
  set perc-best-homed-people 0
  let num 0
  ask people [
    let best-utility 999
    let all-patches []

    ask n-of (count patches) patches [set all-patches lput self all-patches]
    let i 0
    while [ i < length all-patches] [
      let temp-util calculate-utility (item i all-patches)
      if (temp-util > best-utility)
      [ set best-utility temp-util ]
      set i (i + 1)
    ]
    if (best-utility = utility and best-utility != 999)
    [ set num (num + 1) ]
  ]
  set perc-best-homed-people num
end

to help-people-search
;  let available-destinations patches
;  ;random 10 patches
;  ;patches with >0 people choosing
;  turtles with [ member? matching-patches
;  ;list of turtles on this patch
;
;
end

to-report calculate-offer

 ; report (
    ; add % for frugality
   ; ((((spending-on-land-density )^(lov - 1))*(base-land-cost + (commute-cost-per-patch * calculate-patch-firm-distance-pythagoras ))^(lov))/( budget ^ (lov - 1)))
  ;  )
end

to people-search-perfect
  ask people [
    let utility-temp (utility)
    let all-patches []
    ask patches with [not any? people-here] [set all-patches lput self all-patches]
    if(log!) [
      show "count"
      show count patches
      show "count all"
      show length all-patches
    ]
    let i 0
    while [ i < length all-patches] [
      let p-utility calculate-utility(item i all-patches)
      if (p-utility >= 0) [
        if (p-utility > utility-temp)[; and p-utility < budget) [
          ;if (uncrowded(item i ten-random-patches)) [
          if(log!) [
            show "p-utility"
            show p-utility
            show "utility-temp"
            show utility-temp
            show "p-patch"
            show item i all-patches
          ]
          set selected-patch item i all-patches
          set utility-temp (p-utility)
          ;]
        ]
      ]
      set i (i + 1)
    ]
    if (selected-patch != 0) [
      move-to selected-patch
      claim-patch selected-patch
    ]
  ]
  people-set-attributes
end
@#$#@#$#@
GRAPHICS-WINDOW
220
10
1036
827
-1
-1
8.0
1
20
1
1
1
0
0
0
1
-50
50
-50
50
0
0
1
ticks
60.0

BUTTON
13
10
76
43
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
82
10
145
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
129
184
162
num-landlords
num-landlords
5
1000
900.0
1
1
NIL
HORIZONTAL

SWITCH
12
170
185
203
landlords-visible
landlords-visible
1
1
-1000

SLIDER
12
253
183
286
num-firms
num-firms
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
12
295
184
328
wage-gap
wage-gap
1
3
3.0
1
1
NIL
HORIZONTAL

SLIDER
13
461
184
494
city-radius%
city-radius%
10
50
25.0
1
1
%
HORIZONTAL

SLIDER
13
419
184
452
lov-range
lov-range
0
0.25
0.05
0.05
1
NIL
HORIZONTAL

SLIDER
12
336
184
369
num-people
num-people
1
1000
1000.0
1
1
NIL
HORIZONTAL

SLIDER
13
522
184
555
commute-cost-per-patch
commute-cost-per-patch
0.00
0.5
0.01
0.005
1
NIL
HORIZONTAL

SLIDER
13
563
184
596
delivery-cost
delivery-cost
0.05
1
0.25
0.05
1
NIL
HORIZONTAL

MONITOR
1047
159
1244
204
NIL
mean [p-land-cost] of patches
17
1
11

MONITOR
1047
212
1245
257
NIL
min [p-land-cost] of patches
17
1
11

MONITOR
1047
85
1176
130
NIL
mean [utility] of people
17
1
11

BUTTON
1047
348
1247
381
Set patch colour by land cost
ask patches [set pcolor (p-land-cost + 9.75)]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1047
265
1245
310
NIL
max[p-land-cost] of patches
17
1
11

MONITOR
1323
85
1461
130
NIL
max [utility] of people
17
1
11

MONITOR
1182
85
1316
130
NIL
min [utility] of people
17
1
11

SLIDER
12
377
184
410
lov-median
lov-median
0.1
1
0.65
0.05
1
NIL
HORIZONTAL

BUTTON
1192
402
1247
435
X
ask people [set label \"\"]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1047
574
1248
619
NIL
perc-best-homed-people
17
1
11

BUTTON
1047
534
1248
567
NIL
percentage-of-best-homed-people
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1047
33
1237
78
NIL
mean [spending-on-goods] of people
17
1
11

MONITOR
1242
33
1461
78
NIL
mean [spending-on-land-density] of people
17
1
11

SLIDER
13
604
184
637
personal-bubble
personal-bubble
1
8
8.0
0.125
1
NIL
HORIZONTAL

BUTTON
1047
446
1247
479
Send people to perfect patch
people-search-perfect
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1250
446
1342
479
log!
log!
1
1
-1000

BUTTON
1047
490
1247
523
Set Love of Variety ->
ask people [set lov lov-test]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1250
490
1342
523
lov-test
lov-test
0
1
0.15
0.05
1
NIL
HORIZONTAL

MONITOR
1256
159
1460
204
NIL
mean [land-density-cost] of people
17
1
11

MONITOR
1256
213
1460
258
NIL
min [land-density-cost] of people
17
1
11

MONITOR
1256
265
1460
310
NIL
max [land-density-cost] of people
17
1
11

TEXTBOX
18
57
168
75
Setup Parameters
12
0.0
0

TEXTBOX
16
504
166
522
Run Parameters
12
0.0
0

CHOOSER
12
77
150
122
land-or-density
land-or-density
"land" "density"
1

TEXTBOX
1048
12
1198
30
Monitors
14
0.0
0

TEXTBOX
1047
138
1147
153
Land
12
0.0
0

TEXTBOX
1256
139
1372
154
Density
12
0.0
0

TEXTBOX
1098
385
1197
403
(darker ~ cheaper)
11
0.0
1

BUTTON
1047
402
1192
435
Set people's labels to wage
ask people [\n  set label [wage-output] of firm!\n  set label-color [color] of firm!\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1048
326
1198
344
Testing
14
0.0
0

BUTTON
13
788
184
821
Set Density Parameters
set land-or-density \"density\"\nset num-landlords 1\nifelse(monocentric = true)\n[set num-firms 1]\n[set num-firms 4]\nset wage-gap 3\nset num-people 1000\nset lov-median 0.65\nset lov-range 0.05\nset city-radius% 50\nset commute-cost-per-patch 0.01\nset delivery-cost 0.25\nset personal-bubble 8
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
13
707
184
740
Revert to Default
set num-landlords 900\nset landlords-visible false\nset num-people 1000\nset lov-median 0.65\nset lov-range 0.05\nset city-radius% 25\nset commute-cost-per-patch 0.01\nset delivery-cost 0.25
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
13
747
184
780
Set Land Parameters
set land-or-density \"land\"\nset num-landlords 900\nset landlords-visible true\nif(monocentric = true)\n[set num-firms 1]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
13
667
184
700
monocentric
monocentric
1
1
-1000

TEXTBOX
16
649
166
667
Parameters
12
0.0
0

SWITCH
12
211
193
244
landlords-change-land-costs
landlords-change-land-costs
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

A spatial agent-based model to analyse the relationship between several different types of agents to form an economic system. 


## HOW IT WORKS


Workers (People) look for somewhere to live based on a utility function (distance to work, spending on land and goods, density of people). 

Workplaces (Firms) provide goods for workers and a wage. Landlords provide land for workers to live and base their costs on demand.

Workers receive a wage and a chance to move every tick by randomly selecting ten patches of land and then moving to the most suitable location. 

The model is devised from the interactions between the three sets of agents during this.


## HOW TO USE IT

<h3>Setup Parameters</h3>
Parameters to set before setup is ran, describing properties and behaviours of agents throughout the simulation.

<h3>Run Parameters</h3>
Parameters that can be changed throughout the simulation run that will affect behaviour and parameters of agents.

<h3>Parameters</h3>
Buttons to set parameters fitted to either simulation type - land or density. 

<h3>Monitors</h3>
Monitors for most important attributes of agents, allowing user to view changes in behaviour and average properties of agents.

<h4>Land</h4>
Monitors for properties used in Land-Cost simulations.

<h4>Density</h4>
Monitors for properties used in Density simulations.

<h3>Testing</h3>
Testing modules to change visuals or agent parameters within simulation. This makes experiment analysis and testing easier.

## THINGS TO NOTICE

Take a note of the direction each group of people (belonging to each firm) move in duing the code running. 

People with a higher wage will care less about goods/ disatance costs and the people with lower wages care less about density in order to maximise their utility costs.


## THINGS TO TRY

Resseting the parameters to the default will help you quickly test new variables on the same model setup. 

When looking at density costs, try varying the size of the personal bubble and observe how the people disperse when it increases and vice versa.

The impact of differences in wealth and preferences- test the model with a wider range of wages and see what changes.

Multiple firms- Change the number of firms and how spread out they are and watch for the results.

## EXTENDING THE MODEL

Vary the land cost of a patch based on its distance from the land lord. 

Add personality paramaters into the people agents to make their behaviour more organic 
simulate concepts such as frugality and favrotism to allow the agents a more varied behaviour set. 

Make some of the varibles automatic to clean up the UI such as the number of factories and landlords.

## NETLOGO FEATURES

Agent breeds are extensivly used by this model to simulate diffrent types of agent produced by the economic system. Spacial simulation is a large part of this model and as such it uses alot of the spacial-relational tools within net-logo. 

Colors and shapes are used extensivly to differentiate diffrent breeds of agent and diffrent patch properties based on the model settings

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES
written and designed by:
Danny 
Laura 
Anthony


based on: https://tinyurl.com/yas3hcsd
An agent model of urban economics: Digging into emergence
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

pentagon_ol
false
0
Polygon -1 true false 150 15 15 120 60 285 240 285 285 120
Polygon -7500403 true true 150 36 30 124 71 270 230 271 270 124
Polygon -7500403 true true 15 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="density-experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>mean [land-density-cost] of people</metric>
    <enumeratedValueSet variable="lov-range">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-tipping-point">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lov-test">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-firms">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="city-radius%">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log!">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlord-cost-multiplier">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="delivery-cost-per-patch">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-landlords">
      <value value="309"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commute-cost-per-patch">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlord-stock-balance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lov-median">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-landlord-stock">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="land-or-density">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bbl">
      <value value="3.125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage-gap">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bidded-land-costs-persist">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="personal-bubble">
      <value value="1"/>
      <value value="0.1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlords-visible">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people-crowding">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-people">
      <value value="993"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <metric>mean [land-density-cost] of people</metric>
    <enumeratedValueSet variable="lov-range">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-tipping-point">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lov-test">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-firms">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="city-radius%">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log!">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlord-cost-multiplier">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="delivery-cost-per-patch">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-landlords">
      <value value="309"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commute-cost-per-patch">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlord-stock-balance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lov-median">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="auto-landlord-stock">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="land-or-density">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bbl">
      <value value="3.125"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wage-gap">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bidded-land-costs-persist">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="personal-bubble">
      <value value="1"/>
      <value value="1"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="landlords-visible">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people-crowding">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-people">
      <value value="993"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
