globals [wage-min wage-max wage-list    amount-people-moved]

breed [people person]
breed [landlords landlord]
breed [firms firm]

people-own [firm! home! selected-patch land-cost lov budget product-cost spending-on-land spending-on-goods utility income]
landlords-own [base-land-cost net-stock-level home-x home-y p-color]
firms-own [wage-output base-product-cost]
patches-own [p-land-cost belongs-to]

to setup
  set amount-people-moved 0
  clear-all
  ask patches [set pcolor black]
  setup-landlords
  setup-firms
  setup-people
  reset-ticks
end


to setup-landlords
  create-landlords num-landlords
  ask landlords [
    set base-land-cost ((round random 4) + 1) * 0.25
    set p-color ( one-of [0 10 20 30 40 50 60 70 80 90 110 120 130] + one-of [3 4 5 6 7 8 9] )
    ifelse (landlords-visible = true)
    [ set color (p-color - 3)]
    [ set hidden? true ]
    setxy random-xcor random-ycor
    ;ask patch-here [set pcolor p-color]
    set pcolor p-color
    ask patch-here [
      set p-land-cost [base-land-cost] of myself
      set belongs-to myself
    ]
    set home-x pxcor
    set home-y pycor
  ]
  while [any? patches with [pcolor = black]] [
    let patches-count count patches
    let patches-assigned count patches with [pcolor != black]
    let assigned% (patches-assigned / patches-count * 100)

    ifelse (assigned% < p-tipping-point)
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
        set belongs-to myself
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
      if ( all? neighbors4 [belongs-to = [belongs-to] of one-of neighbors4 and belongs-to != 0])
      [
        set pcolor [pcolor] of one-of neighbors4
        set p-land-cost [p-land-cost] of one-of neighbors4
        set belongs-to [belongs-to] of one-of neighbors4
      ]
    ]
  ]
end

to setup-cellular-landlord-patches
  ask patches with [pcolor = black] [
    let clone-patch one-of neighbors4 with [pcolor != black]
    if(clone-patch != nobody) [
     set p-land-cost [p-land-cost] of clone-patch
     set belongs-to [belongs-to] of clone-patch
     set pcolor [pcolor] of clone-patch
    ]
  ]
end

to setup-firms
  create-firms num-firms
  ask firms [
    set wage-output round (random (wage-gap * num-firms) + 0.5)

    ifelse (num-firms = 1)
    [ set base-product-cost 1 ]
    [ set base-product-cost one-of [1 2 3 4] ]

    set label wage-output
    set label-color black
    set color color;(wage-output + 2)
    set shape "pentagon_ol"
    set size 6

    while [(xcor = 0 and ycor = 0)]
    [
      ; radius around firms/ number of firms limits the size you are able to set the city radius
      move-to one-of patches in-radius ((city-radius% / 100) * (max-pxcor * 2)) with [ not any? firms in-radius 5 ]
    ]

    set wage-list sentence wage-list wage-output
  ]
end

to setup-people
  create-people num-people
  ask people [
    set firm! one-of firms
    set lov ( lov-median + random (lov-range * random+-) ) + 0.1

    set label [wage-output] of firm!
    set label-color [color] of firm!
    set color [color] of firm!
    set shape "person"
    setxy random-xcor random-ycor
  ]
end

; GO

to go
    LandLord-cost-adjust
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
   set spending-on-land get-spending-on-land(home!)
   set utility calculate-utility(home!)
  ]
end

to LandLord-cost-adjust

  ask-concurrent landlords
  [


    ; get refrence to current land lord for use later
    let ll self
    ; allocate temp varibles
    let price-change 0
    let stock count patches with [belongs-to = ll]
    let used-stock 0
    ;count number of patches with people on
    ask patches with [belongs-to = ll]
    [
    if(any? people-on self)
      [
      set used-stock used-stock + count people-on self
      ]
    ]


    ;show("used-stock")
    ;pecentege of the stock before land lord starts lowering prices
    ;should be 100 but we never get stock use that high
    let stock-balance (stock / 100) * land-lord-stock-balance
    ;calc stock avalible
    set net-stock-level  stock - used-stock

    if-else(auto-landlord-stock)
    [
     let c-landlord count landlords

     let c-people count people

     let avg (c-people / c-landlord)

      if-else(used-stock > avg)
      [
      set price-change  1

      ]
      [
       set price-change  -1
      ]
    ]
    [
         ; if the stocked avalible is more than the target start reducing prices
    set price-change  ((stock-balance - net-stock-level ) ) / land-lord-cost-multiplier
    ]
    ;set price
    set base-land-cost base-land-cost + price-change

   ; min stock value
    if(base-land-cost < 1 )
    [set base-land-cost  1]
   ;; show(ll)
   ; show(base-land-cost)

    ; assign new value to patches
    ask patches with [belongs-to = ll]
    [
      set p-land-cost [base-land-cost] of ll
    ]

  ]
ask patches [set pcolor (p-land-cost + 9)]

end


to people-search
  ask people [
    let ten-random-patches []
    ask n-of 10 patches [set ten-random-patches lput self ten-random-patches]

    let i 0
    while [ i < length ten-random-patches] [
      let p-utility calculate-utility(item i ten-random-patches)
      if (p-utility >= 0) [
        if (p-utility < utility) [
          set selected-patch item i ten-random-patches
        ]
      ]
      set i (i + 1)
    ]
    if (selected-patch != 0) [
      move-to selected-patch
      ;show "moved to "
      ;show selected-patch
      set amount-people-moved (amount-people-moved + 1)
  ]]
end

to-report get-budget [patch!]
  report [wage-output] of firm! - (commute-cost-per-patch * calculate-patch-firm-distance-pythagoras(patch!))
end

to-report get-product-cost [patch!]
  report [base-product-cost] of firm! + (delivery-cost-per-patch) ;* calculate-patch-firm-distance-pythagoras(patch!))
end

to-report get-spending-on-goods [patch!]
  report ( ( ( get-product-cost(patch!) ^ (1 / (lov - 1)) ) * get-budget(patch!)) / ( [p-land-cost] of patch! ^ (lov / (lov - 1)) ))
end


; -- BROKEN --

to-report get-spending-on-goods2 [patch!]
  report ( stuff1(patch!) / stuff2(patch!) )
end

to-report stuff1 [patch!]
  report ( ( get-product-cost(patch!) ^ (1 / (lov - 1)) ) * get-budget(patch!))
end

to-report stuff2 [patch!]
  report ( [p-land-cost] of patch! ^ (lov / (lov - 1)) )
end

; -- BROKEN --

to-report get-spending-on-land [patch!]

  report ( [p-land-cost] of patch! ^ ((1 / (lov - 1)) * get-budget(patch!)) ) / ( get-product-cost(patch!) ^ (lov / (lov - 1)) )
end

to-report get-utility
  report (( spending-on-goods ^ lov ) + ( spending-on-land ^ lov )) ^ (1 / lov)
end

to-report calculate-utility [patch!]
  ifelse (get-budget(patch!) <= 0)
  [ report -1]
  [ report (( get-spending-on-goods(patch!) ^ lov ) + ( get-spending-on-land(patch!) ^ lov )) ^ (1 / lov) ]
end

to-report calculate-patch-firm-distance-pythagoras [patch!]
  report sqrt ((distance patch!)^(2) + (distance firm!)^(2))
end





; RANDOM UTILITIES

to-report check-val[val]
  if(val < 0) [
    report(0)
  ]
  report(val)
end

to-report random+-
  report one-of [1 -1]
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
@#$#@#$#@
GRAPHICS-WINDOW
239
10
1055
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
19
35
82
68
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
106
38
169
71
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
18
122
190
155
num-landlords
num-landlords
5
1000
278.0
1
1
NIL
HORIZONTAL

SWITCH
18
184
165
217
landlords-visible
landlords-visible
0
1
-1000

SWITCH
1089
14
1292
47
bidded-land-costs-percede
bidded-land-costs-percede
1
1
-1000

SLIDER
20
277
192
310
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
21
319
193
352
wage-gap
wage-gap
1
3
1.0
1
1
NIL
HORIZONTAL

MONITOR
21
639
191
684
NIL
wage-list
17
1
11

SLIDER
15
703
187
736
city-radius%
city-radius%
5
50
36.0
1
1
%
HORIZONTAL

SLIDER
17
534
189
567
lov-range
lov-range
0
0.25
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
26
441
198
474
num-people
num-people
5
1000
1000.0
1
1
NIL
HORIZONTAL

SLIDER
24
360
210
393
commute-cost-per-patch
commute-cost-per-patch
0.00
0.5
0.0
0.1
1
NIL
HORIZONTAL

SLIDER
26
406
218
439
delivery-cost-per-patch
delivery-cost-per-patch
0.05
1
1.0
0.05
1
NIL
HORIZONTAL

MONITOR
1121
192
1333
237
NIL
mean [base-land-cost] of landlords
17
1
11

MONITOR
1126
265
1465
310
NIL
mean [p-land-cost] of patches
17
1
11

MONITOR
1133
342
1302
387
NIL
min [p-land-cost] of patches
17
1
11

MONITOR
1137
132
1331
177
NIL
min [base-land-cost] of landlords
17
1
11

BUTTON
1113
516
1313
549
NIL
ask people [set color white]
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
1119
407
1260
452
NIL
mean [utility] of people
17
1
11

BUTTON
1124
579
1397
612
NIL
ask patches [set pcolor (p-land-cost + 10)]
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
1338
355
1508
400
NIL
max[p-land-cost] of patches
17
1
11

PLOT
1070
635
1454
827
utility
ticks
utility
0.0
10000.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [utility] of people"

MONITOR
1283
422
1417
467
NIL
max [utility] of people
17
1
11

MONITOR
1316
481
1445
526
NIL
min [utility] of people
17
1
11

SLIDER
16
492
188
525
lov-median
lov-median
0.1
1
0.6
0.05
1
NIL
HORIZONTAL

MONITOR
1161
61
1449
106
NIL
amount-people-moved
17
1
11

SLIDER
17
772
189
805
p-tipping-point
p-tipping-point
0
100
33.0
1
1
NIL
HORIZONTAL

SLIDER
16
234
206
267
land-lord-cost-multiplier
land-lord-cost-multiplier
0.5
100
14.5
1
1
NIL
HORIZONTAL

PLOT
1468
61
1668
211
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"pen-0" 1.0 0 -7500403 true "" "plot mean [p-land-cost] of patches"

SLIDER
16
79
195
112
land-lord-stock-balance
land-lord-stock-balance
0
100
51.0
1
1
NIL
HORIZONTAL

SWITCH
18
588
185
621
auto-landlord-stock
auto-landlord-stock
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
