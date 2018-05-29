breed [penguins penguin]
globals
[nearest-center]
patches-own
[
  delta-temperature            ;; temperature on this patch
  old-delta-temperature
  herd?
  join-area?                   ;; indicate whether this patch area is an area that penguins can join the herd
  exposed?
]
penguins-own
[
  body-delta-temperature       ;; temperature of this penguin
  in-herd?                     ;; indicate whether this penguin is within a herd
  back-free?                   ;; indicate whether this penguin's back is free (i.e. this penguin is on the perimeter)
  selfish?                     ;; indicate whether this penguin is of type selfish or not
  lefty?                       ;; left handed or right handed
  death-warning                ;; counter for death warnings
  num-in-small                 ;; count of penguins within a small radius
  num-in-medium                ;; count of penguins within a medium radius
  num-in-large                 ;; count of penguins within a large radius
]
to reset-all
  clear-all
  reset-ticks
  ask penguins [die]
  default-settings
  reset-env-temp
end
to default-settings           ;; with these settings regular penguins can survive longer that the 'selfish' penguins
  set number-of-penguins 200
  set env-temp -40
  set color-herd? true
  set body-heat-generated-per-tick 5
  set penguin-size 3
  set min-distance 3
  set body-heat-lost-per-tick 0.47
  set death-warning-limit 500
end
to reset-env-temp
  ask patches [
    set delta-temperature C-to-Delta(env-temp)
    set old-delta-temperature C-to-Delta(env-temp)
  ]
  set-default-shape penguins "penguin"
  recolor-env
end
;; create disperse penguins         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to create-disperse-penguins
  create-penguins number-of-penguins [
    setxy random-xcor random-ycor
    while [count penguins in-radius min-distance > 1]
    [setxy random-xcor random-ycor]
    set size penguin-size
    set selfish? false
    set lefty? (2 * random 2) - 1
;    set death-warning 0
    set body-delta-temperature C-to-Delta(20 - random 60)
  ]
end
;; create clumped penguins           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to create-clumped-penguins
  let co-root ceiling sqrt number-of-penguins
  let alpha min-distance
  let xco 50 - (co-root * alpha / 2)
  let yco 50 - (co-root * alpha / 2)

  create-penguins number-of-penguins [
    set size penguin-size
    setxy xco yco
    set selfish? false
    set lefty? (2 * random 2) - 1
    set xco xco + alpha
;    set death-warning 0
    if xco >= (50 + (co-root * alpha / 2)) [
      set xco 50 - (co-root * alpha / 2)
      set yco yco + alpha
    ]
    set body-delta-temperature C-to-Delta(20 - random 60)
    set heading 1;20 - random 40
  ]
  create-penguins 1 [
    set size penguin-size
    setxy 50 + (co-root / 2) 50 + ((alpha / 2 * co-root) + (alpha * 2))
    set body-delta-temperature C-to-Delta(20 - random 60)
  ]
end
;; create disperse selfish penguins  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to create-disperse-selfish-penguins
  create-penguins number-of-penguins [
    setxy random-xcor random-ycor
    while [count penguins in-radius min-distance > 1]
    [setxy random-xcor random-ycor]
    set size penguin-size
    set selfish? true
    set lefty? (2 * random 2) - 1
    set shape "penguin 2"
    set body-delta-temperature C-to-Delta(20 - random 60)
  ]
end
to go
  ;; step 1 ;;; identify if penguin in herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  which-in-herd
  ;================================================================================================
  ;; step 2 ;;; move penguins outside the herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  if (no-huddle? = false)
  [repeat 5 [move-outside-herd]]
  ;================================================================================================
  ;; step 3 ;;; move penguins inside the herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  if (no-huddle? = false)
  [move-inside-herd]
  ;================================================================================================
  ;; step 4 ;;; body heat generation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  body-heat-generation
  ;================================================================================================
  ;; step 5 ;;; body heat loss + env heat gain ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  body-heat-loss+env-heat-gain
  ;================================================================================================
  ;; step 6 ;;; environment heat diffusion ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  env-heat-diffusion
  ;================================================================================================
  ;; step 7 ;;; agents die if they become too cold ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  cold-penguins-die
  ;================================================================================================
  ; keep temp within boundries
  ask penguins with [body-delta-temperature > C-to-Delta(20)] [set body-delta-temperature C-to-Delta(20)]
  ask penguins with [body-delta-temperature < C-to-Delta(-40)] [set body-delta-temperature C-to-Delta(-40)]

  tick
end
;; step 1 ;;; identify if penguin in herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to which-in-herd
  recolor-env
  foreach sort-on [ycor] penguins                                                                                                                                                      ; not perfect
  [
    the-penguin -> ask the-penguin
    [
      ifelse (count penguins in-radius (4.0 * min-distance) > 4)
      [
        ifelse (count penguins in-cone (1.5 * min-distance) 120 > 1)
        [
          set in-herd? true
        ]
        [
          set in-herd? false
          if (no-huddle? = false)
          [fd 2 * min-distance]
        ]
      ]
      [set in-herd? false]
    ]
  ]
  ask penguins with [in-herd? = true ]
  [ifelse (count penguins with [in-herd? = true] in-radius 10 > 10)
    [ask patches in-radius (0.8 * min-distance)[set herd? true
      if(color-herd?)[set pcolor red]]]
    [set in-herd? false]
  ]
  ask penguins with [in-herd? = false]
  [
    ask patches in-radius 2 [set herd? false
      if(color-herd?)[
        set pcolor green]]]

  ask patches [set join-area? false set exposed? false]
  ask penguins with [in-herd? = true]
  [
    set num-in-small (count penguins with [in-herd? = true] in-radius (3 * min-distance))
    set num-in-medium (count penguins with [in-herd? = true] in-radius (5 * min-distance))
    set num-in-large (count penguins with [in-herd? = true] in-radius (7 * min-distance))

    set heading heading + 180
    if (count penguins in-cone (1.5 * min-distance) 60 < 2)
    [
      if(num-in-medium > 35)
      [
        set back-free? true
      ]
      ask patches in-cone (1.0 * min-distance) 100
      [
        set exposed? true
          if(color-herd?)[
            set pcolor green]
          if([back-free?] of myself = true)
          [
            set join-area? true
            if(color-herd?)[
              set pcolor yellow]
          ]
      ]
    ]
    set heading heading + 180
  ]
end
;; step 2 ;;; move penguins outside the herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to move-outside-herd
  set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-large] of self ]
  if(nearest-center = Nobody)
  [set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-medium] of self ]
      if(nearest-center = Nobody)
      [set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-small] of self ]]
  ]
  ask penguins with [in-herd? = false]
  [
    let b4-center-heading heading
    if(nearest-center != Nobody)
    [face nearest-center]

    ifelse (count penguins in-cone (3 * min-distance) 50 < 2)
    [
      let tmpc 0
      while [tmpc < 5]
      [
        ifelse (count penguins in-cone (2 * min-distance) 50 > 1)
        [set tmpc 5]
        [set tmpc tmpc + 0.1
          fd 0.1]
      ]
    ]
    [
      ;get the direction of closest in herd penguin
      let nearest-neighbor Nobody
      set nearest-neighbor min-one-of (other penguins with [in-herd? = true]) [ distance myself ]
      if (nearest-neighbor != Nobody)
      [
        let in-herd-heading [heading] of nearest-neighbor
        let dis distance nearest-neighbor
        ;set direction towards herd
        face nearest-neighbor
        ; equation to determine whether myself is on the left or right with respect to nearest neigbour
        let d ((xcor - [xcor] of nearest-neighbor)*(cos(in-herd-heading))) - ((ycor - [ycor] of nearest-neighbor)*(sin(in-herd-heading)))
        ifelse (d != 0)
        [set d (d / abs(d))]
        [set d 1]
        ifelse (heading > 180 and abs(heading - in-herd-heading) < 180)
        [if (in-herd-heading < 180)[set in-herd-heading in-herd-heading + 360]]
        [if (in-herd-heading > 180)[set in-herd-heading in-herd-heading - 360]]
        let dis2 abs(heading - in-herd-heading)
        set heading heading + 100 * (lefty?)
        if(dis2 < 30)[
        let ttt min-one-of (other penguins with [back-free? = true]) [ distance myself ]
        let tttheading heading
        if (ttt != Nobody)
          [face ttt
            if (count penguins in-cone (distance ttt) 20 > 2)
            [set heading tttheading]
          ]
        ]
        let tmpc 0
        while [tmpc < 3]
        [
          ifelse ((count penguins with [in-herd? = true] in-radius (1 * min-distance)) > 1)
          [set tmpc 3]
          [set tmpc tmpc + 0.1
            fd 0.1]
        ]
      ]
    ]
  ]
end
;; step 3 ;;; move penguins inside the herd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to move-inside-herd
  if (count penguins with [in-herd? = true ] > 0)
  [
    set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-large] of self ]
    if(nearest-center = Nobody)
    [set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-medium] of self ]
      if(nearest-center = Nobody)
      [set nearest-center max-one-of (other penguins with [in-herd? = true]) [ [num-in-small] of self ]]
    ]
    if(nearest-center != Nobody)
    [
      ask penguins with [in-herd? = true]
      [
        set heading heading + 90
        let d ((xcor - [xcor] of nearest-center)*(cos(heading))) - ((ycor - [ycor] of nearest-center)*(sin(heading)))
        set heading heading - 90
        if (d > 0)
        [
          let tmpheading heading
          face nearest-center
          ifelse (heading > 180 and abs(heading - tmpheading) < 180)
          [if (tmpheading < 180)[set tmpheading tmpheading + 360]]
          [if (tmpheading > 180)[set tmpheading tmpheading - 360]]
          set heading abs(heading + 3 * tmpheading) / 4
        ]
      ]
    ]
    let theset reverse sort-on [ycor] penguins                                                                                                                                              ; not perfect
    foreach theset
    [
      the-penguin -> ask the-penguin
      [
        ifelse (in-herd? = true and selfish? = false)
        [
          let tmp 0
          let c 0
          ask penguins in-radius 5
          [
            set tmp tmp + heading
            if (heading < 180)[set tmp tmp + 360]
            set c c + 1
          ]
          set heading (tmp / c)                                                                                                                                                           ; not perfect

          let tmpc2 0
          while [tmpc2 < 1]
          [
            ifelse ((count penguins in-cone (1.0 * min-distance) 90 > 1))
            [set tmpc2 1]
            [set tmpc2 tmpc2 + 0.1
            fd 0.1]
          ]
        ]
        [
          if(selfish? = true)
          [
            if (selfish-strategy = "towards the center")
            [
              facexy (max-pxcor / 2) (max-pycor / 2)           ;; face the center
              let tmpc2 0
              while [tmpc2 < 2]
              [
                ifelse ((count penguins in-cone (1.0 * min-distance) 90 > 1))
                [set tmpc2 2]
                [set tmpc2 tmpc2 + 0.1
                  fd 0.1]
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end
;; step 4 ;;; body heat generation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to body-heat-generation
  ask penguins with [Delta-to-C(body-delta-temperature) < 20] [
    set body-delta-temperature body-delta-temperature + body-heat-generated-per-tick
  ]
end
;; step 5 ;;; body heat loss + env heat gain ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to body-heat-loss+env-heat-gain
  ask penguins [
    let tmp 0
    let num 0
    ask patches in-radius (1.0 * min-distance) [
      set tmp tmp + Delta-to-C(delta-temperature)
      set num num + 1
    ]
    let avg-env-temp (tmp / num)
    let adjusted-body-heat-lost-per-tick 0.5 * body-heat-lost-per-tick
    ifelse(count penguins in-cone (1.0 * min-distance) 100 > 1)
    [
      set heading heading + 180
      if(count penguins in-cone (1.0 * min-distance) 100 < 2)
      [set adjusted-body-heat-lost-per-tick 10 * body-heat-lost-per-tick]
      set heading heading - 180
    ]
    [set adjusted-body-heat-lost-per-tick 10 * body-heat-lost-per-tick]
    let tmp2 (- body-heat-lost-per-tick * (Delta-to-C(body-delta-temperature) - avg-env-temp))
    let tmp3 Delta-to-C(body-delta-temperature) + tmp2
    let tmp-lost Delta-to-C(body-delta-temperature) - tmp3
    set body-delta-temperature C-to-Delta(tmp3)
    set num count patches in-radius (1.0 * min-distance)
    let s-tmp (1 * tmp-lost / num)
    ask patches in-radius 2 [
      let x (Delta-to-C(delta-temperature) + s-tmp)
      set old-delta-temperature C-to-Delta(x)
    ]
  ]
end
;; step 6 ;;; environment heat diffusion ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to env-heat-diffusion
  ask patches
  [
    ;; diffuse the heat of a patch with its neighbors
    set delta-temperature (0.25 * (sum [old-delta-temperature] of neighbors4))
    ;; set the edges back to their constant heat
    set old-delta-temperature delta-temperature
  ]
  ;;;;;;;;;;;;;;;;;;;  wind-like simulation ; reset the temperature for patches outside the herd as if the warm air got replaced by cold air
  repeat 1 [ask patches with [herd? = false]
    [set delta-temperature 0
      set old-delta-temperature delta-temperature
    ]
  ]
  ;; attenuate temperature on patches close to the perimeter
  repeat 1 [ask patches with [exposed? = true]
    [set delta-temperature 0.9 * delta-temperature
      set old-delta-temperature delta-temperature
    ]
  ]
  recolor-env
end
;; step 7 ;;; agents die if they become too cold ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to cold-penguins-die
  ask penguins[
    ifelse (body-delta-temperature <= C-to-Delta(-30))
    [set death-warning death-warning + 1
    if (death-warning > death-warning-limit) [die]]
    [set death-warning 0]
  ]
end
;; other functions
to recolor-env ;; update the environment color to indicate the temperature
    ask patches with [delta-temperature <= C-to-Delta(0)] [
    set pcolor scale-color blue (40 + Delta-to-C(delta-temperature)) -40 40
  ]
  ask patches with [delta-temperature > C-to-Delta(0)] [
    set pcolor scale-color red (60 - Delta-to-C(delta-temperature)) 0 60
  ]
end
to-report C-to-Delta [C]
  report C - env-temp
end
to-report Delta-to-C [K]
  report K + env-temp
end
@#$#@#$#@
GRAPHICS-WINDOW
831
10
1546
726
-1
-1
7.0
1
10
1
1
1
0
1
1
1
0
100
0
100
0
0
1
ticks
30.0

BUTTON
329
13
416
127
NIL
reset-all
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
15
200
70
454
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
0

PLOT
10
528
354
725
population
time
population
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

BUTTON
75
200
156
455
NIL
go
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
131
204
230
237
1) which-in-herd
which-in-herd
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
132
276
247
309
3) move-inside-herd
move-inside-herd
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
132
240
187
273
x5
repeat 5 [move-outside-herd]
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
402
54
524
87
Clear All Penguins
clear-turtles
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
611
10
821
106
NIL
NIL
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
621
18
858
41
Blue    ==> T < Zero
20
105.0
1

TEXTBOX
621
44
849
69
Whilte ==> T = Zero
20
9.9
1

TEXTBOX
620
70
842
97
Red     ==> T > Zero
20
15.0
1

PLOT
362
527
705
725
Selfish Population
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
"default" 1.0 0 -16777216 true "" "plot count penguins with [selfish? = true]"

TEXTBOX
494
142
818
512
settings\n=====-----------------------------------------------------------\n|                                                                    |\n|                                                                    |\n|                                                                    |\n|                                                                    |\n|                                                                    |\n|                                                 -------------------|\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |* minumum distance\n|                                                |   among penguins\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n|                                                |\n--------------------------------------------------
12
0.0
1

BUTTON
132
312
268
345
4) body-heat-generation
body-heat-generation
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
131
347
311
380
5) body-heat-loss+env-heat-gain
body-heat-loss+env-heat-gain
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
131
382
247
415
6) cold-penguins-die
cold-penguins-die
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
131
417
251
450
7) env-heat-diffusion
env-heat-diffusion
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
232
204
332
237
color-herd?
color-herd?
0
1
-1000

BUTTON
402
89
524
122
NIL
default-settings
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
402
19
524
52
Reset Env. Temp.
reset-env-temp
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
502
256
686
289
body-heat-generated-per-tick
body-heat-generated-per-tick
0
10
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
502
336
685
369
min-distance
min-distance
1.5
4
3.0
0.1
1
NIL
HORIZONTAL

SLIDER
502
296
686
329
penguin-size
penguin-size
2
6
3.0
1
1
NIL
HORIZONTAL

SLIDER
502
377
684
410
body-heat-lost-per-tick
body-heat-lost-per-tick
0
2
0.47
0.01
1
NIL
HORIZONTAL

TEXTBOX
13
10
202
157
Create Penguins\n==========------------------------\n|                                            |\n|                                            |\n|                                            |\n|                                            |\n|                                            |\n|                                            |\n|                                            |\n----------------------------------------------
12
0.0
1

BUTTON
21
39
191
72
create disperse penguins
create-disperse-penguins
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
21
74
190
107
create clumped penguins
create-clumped-penguins
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
22
110
190
143
create disperse selfish penguins
create-disperse-selfish-penguins
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
170
240
290
273
2) move-outside-herd
move-outside-herd
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
502
171
767
204
number-of-penguins
number-of-penguins
0
400
200.0
1
1
NIL
HORIZONTAL

SLIDER
502
209
766
242
env-temp
env-temp
-40
20
-40.0
1
1
NIL
HORIZONTAL

CHOOSER
503
458
685
503
selfish-strategy
selfish-strategy
"no movement" "towards the center"
1

SLIDER
503
417
685
450
death-warning-limit
death-warning-limit
50
1000
300.0
50
1
NIL
HORIZONTAL

SWITCH
296
258
397
291
no-huddle?
no-huddle?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

This model tries to emulate the heat preservation technique used by the penguin emperor extreme cold weather.

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

- 
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

penguin
true
1
Polygon -1 true false 105 90 75 90
Circle -1 true false 75 45 150
Polygon -7500403 true false 30 90 75 60
Polygon -16777216 true false 150 240 180 240 225 225 255 210 270 180 285 105 270 90 255 105 255 135 240 120 225 75 180 60 120 60 75 75 60 120 45 135 45 105 30 90 15 105 30 180 45 210 75 225 120 240 135 240
Polygon -1 true false 30 90 30 105 45 135 75 120 225 120 255 135 270 105 270 90 255 105 255 135 240 120 225 90 195 60 105 60 75 90 60 120 45 135 45 105 30 90
Circle -1 true false 108 93 85
Circle -16777216 true false 105 75 90
Polygon -16777216 true false 180 90 150 90 120 90 150 45

penguin 2
true
4
Polygon -1 true false 105 90 75 90
Circle -1 true false 75 45 150
Polygon -7500403 true false 30 90 75 60
Polygon -2674135 true false 150 240 180 240 225 225 255 210 270 180 285 105 270 90 255 105 255 135 240 120 225 75 180 60 120 60 75 75 60 120 45 135 45 105 30 90 15 105 30 180 45 210 75 225 120 240 135 240
Polygon -1 true false 30 90 30 105 45 135 75 120 225 120 255 135 270 105 270 90 255 105 255 135 240 120 225 90 195 60 105 60 75 90 60 120 45 135 45 105 30 90
Circle -1 true false 108 93 85
Circle -2674135 true false 105 75 90
Polygon -2674135 true false 180 90 150 90 120 90 150 45

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

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
NetLogo 6.0.2
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
