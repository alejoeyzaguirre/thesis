* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Urgencias" 


********************************************************************************

******************** Preparación Treatment x Comuna ****************************

********************************************************************************


/* Treatment por comunas:
use "$raw/Internet/casen17", clear

* Nos quedamos solo con las vars relevantes:
keep comuna region expc r21d

* Dado que CASEN solo tiene info representativa para comunas en RM:
labellist region
*keep if region == 13

* Expandimos:
expand expc

* Vemos el número total de "personas" (entrevistadas) por comuna:
gen id = _n
egen num = count(id), by(comuna)

* Que porcentaje de los encuestados usa internet para comunicarse por RRSS:
replace r21d = 0 if r21d == 2 | r21d == 9 | r21d == .

* Colapsamos por comuna: ? Qué hago con los missing values?
collapse (sum) r21d, by(comuna num)

* Generamos nuestro treatment:
gen treatment = r21d / num

* Generamos variable string de comuna:
decode comuna, gen(nombrecomuna) 

sort nombrecomuna
gen numerocomuna = int(comuna)

* Arreglamos los <?>
replace nombrecomuna = "Alhué" if comuna == 13502
replace nombrecomuna = "Conchalí" if comuna == 13104
replace nombrecomuna = "Curacaví" if comuna == 13503
replace nombrecomuna = "Estación Central" if comuna == 13106
replace nombrecomuna = "Maipú" if comuna == 13119
replace nombrecomuna = "María Pinto" if comuna == 13504
replace nombrecomuna = "Peñaflor" if comuna == 13605
replace nombrecomuna = "Peñalolén" if comuna == 13122
replace nombrecomuna = "San Joaquín" if comuna == 13129
replace nombrecomuna = "San José de Maipo" if comuna == 13203
replace nombrecomuna = "San Ramón" if comuna == 13131
replace nombrecomuna = "Ñuñoa" if comuna == 13120

replace nombrecomuna = "Alto Biobío" if comuna == 8314
replace nombrecomuna = "Aysén" if comuna == 11201
replace nombrecomuna = "Camiña" if comuna == 1402
replace nombrecomuna = "Cañete" if comuna == 8203
replace nombrecomuna = "Chañaral" if comuna == 3201
replace nombrecomuna = "Chillán" if comuna == 16101
replace nombrecomuna = "Chillán Viejo" if comuna == 16103
replace nombrecomuna = "Chépica" if comuna == 6302
replace nombrecomuna = "Colbún" if comuna == 7402
replace nombrecomuna = "Combarbalá" if comuna == 4302
replace nombrecomuna = "Concepción" if comuna == 8101
replace nombrecomuna = "Concón" if comuna == 5103
replace nombrecomuna = "Constitución" if comuna == 7102
replace nombrecomuna = "Copiapó" if comuna == 3101
replace nombrecomuna = "Curacautín" if comuna == 9203
replace nombrecomuna = "Curaco de Vélez" if comuna == 10204
replace nombrecomuna = "Curicó" if comuna == 7301
replace nombrecomuna = "Doñihue" if comuna == 6105
replace nombrecomuna = "Hualañé" if comuna == 7302
replace nombrecomuna = "Hualpén" if comuna == 8112
replace nombrecomuna = "La Unión" if comuna == 14201
replace nombrecomuna = "Licantén" if comuna == 7303
replace nombrecomuna = "Longaví" if comuna == 7403
replace nombrecomuna = "Los Álamos" if comuna == 8206
replace nombrecomuna = "Los Ángeles" if comuna == 8301
replace nombrecomuna = "Machalí" if comuna == 6108
replace nombrecomuna = "María Elena" if comuna == 2302
replace nombrecomuna = "Maullín" if comuna == 10108
replace nombrecomuna = "Mulchén" if comuna == 8305
replace nombrecomuna = "Máfil" if comuna == 14105
replace nombrecomuna = "Olmué" if comuna == 5803
replace nombrecomuna = "Pitrufquén" if comuna == 9114
replace nombrecomuna = "Puchuncaví" if comuna == 5105
replace nombrecomuna = "Pucón" if comuna == 9115
replace nombrecomuna = "Puqueldón" if comuna == 10206
replace nombrecomuna = "Purén" if comuna == 9208
replace nombrecomuna = "Queilén" if comuna == 10207
replace nombrecomuna = "Quellón" if comuna == 10208
replace nombrecomuna = "Quillón" if comuna == 16107
replace nombrecomuna = "Quilpué" if comuna == 5801
replace nombrecomuna = "Requínoa" if comuna == 6116
replace nombrecomuna = "Ránquil" if comuna == 16206
replace nombrecomuna = "Río Bueno" if comuna == 14204
replace nombrecomuna = "Río Claro" if comuna == 7108
replace nombrecomuna = "Río Hurtado" if comuna == 4305
replace nombrecomuna = "Río Ibáñez" if comuna == 11402
replace nombrecomuna = "Río Negro" if comuna == 10305
replace nombrecomuna = "San Fabián" if comuna == 16304
replace nombrecomuna = "San Nicolás" if comuna == 16305
replace nombrecomuna = "Santa Bárbara" if comuna == 8311
replace nombrecomuna = "Santa María" if comuna == 5706
replace nombrecomuna = "Tirúa" if comuna == 8207
replace nombrecomuna = "Toltén" if comuna == 9118
replace nombrecomuna = "Tomé" if comuna == 8111
replace nombrecomuna = "Traiguén" if comuna == 9210
replace nombrecomuna = "Valparaíso" if comuna == 5101
replace nombrecomuna = "Vichuquén" if comuna == 7309
replace nombrecomuna = "Vicuña" if comuna == 4106
replace nombrecomuna = "Vilcún" if comuna == 9119
replace nombrecomuna = "Viña del Mar" if comuna == 5109
replace nombrecomuna = "Ñiquén" if comuna == 16303

gen codcomuna = numerocomuna

* Guardamos:
save "$output/intmun", replace
*/

********************************************************************************

************************** Usando Datos EM 2021 ********************************

********************************************************************************


* Importe Base que ya fue pre-procesada en Python (ver thesis.ipynb)
use "$output/emergencies", clear

* Me quedo solo con causas relacionadas a salud mental: : ()
*tab glosacausa
keep if idcausa > 34 & idcausa <43

* Nos quedamos solo con obs. de la RM:
gen region = round(códigocomuna / 1000)
keep if region == 13

* Cambiamos nombre de Vars:
rename _5_64 g15_64
rename _5_mas g65
rename __14 g5_15
rename column7 g1_4
rename menor_a_1 g0

* Síndromes de Abstinencia:
gen withdrawal = 0
replace withdrawal = 1 if idcausa == 35 | idcausa == 37 | idcausa == 39 | idcausa == 40
keep if withdrawal == 1

* Figuras: 

/* FIGURA 1: Outcome during Outage:

preserve
collapse (sum) total, by(dia mes)
gen diasemana = 0
replace diasemana = mod(dia+4,7) if mes == 1
replace diasemana = mod(dia+0,7) if mes == 2
replace diasemana = mod(dia+0,7) if mes == 3
replace diasemana = mod(dia+3,7) if mes == 4
replace diasemana = mod(dia+5,7) if mes == 5
replace diasemana = mod(dia+1,7) if mes == 6
replace diasemana = mod(dia+3,7) if mes == 7
replace diasemana = mod(dia+6,7) if mes == 8
replace diasemana = mod(dia+2,7) if mes == 9
replace diasemana = mod(dia+4,7) if mes == 10
replace diasemana = mod(dia+0,7) if mes == 11
replace diasemana = mod(dia+2,7) if mes == 12
replace diasemana = 7 if diasemana == 0
gen during = 99
replace during = 0 if (dia > 12 & mes == 9) | (dia < 4 & mes == 10)
replace during = 1 if dia == 4 & mes == 10
replace during = 2 if (dia > 4 & dia < 26 & mes == 10) 
drop if during == 99
collapse (mean) total, by(diasemana during)
drop if during == 2
replace during = -1 if during == 1
sort diasemana during
gen categ = _n
replace total = total -1200
set scheme s1color
statplot total , over(categ) vertical legend(off)
restore 
*/

* Sacamos la suma de todas los ingresos por Salud Mental entre todas las comunas
* de cada día:
drop glosacausa
collapse (sum) total g*, by(dia mes nombrecomuna códigocomuna withdrawal)
sort nombrecomuna mes dia

* Juntamos con base de Treatment a partir de CASEN 2017.
merge m:1 nombrecomuna using "$output/intmun", nogen 

* Botamos Comunas que no están en la CASEN 17
drop if treatment == .

* Generamos variable treat*during
gen treatpost = 0
replace treatpost = treatment if dia == 4 & mes == 10

* Generamos de nuevo variable región:
gen region = round(códigocomuna / 1000)


/* FIGURA 2: Treatment Nature:

preserve
drop if dia > 4 & mes == 10 | mes > 10
sum treatment, d
gen status = (treatment >= 0.602) // High penetration above median.
sum total if status == 0
gen av_out0 = r(mean)
sum total if status == 1
gen av_out1 = r(mean)
collapse (mean) total av_out0 av_out1, by(dia mes status)
sort status mes dia
* Only compare during outage observations:
keep if (dia == 4 & mes == 10)
collapse (mean) total av_out0 av_out1, by(status)
gen rel_out = 0
replace rel_out = total / av_out0 - 1 if status == 0
replace rel_out = total / av_out1 - 1 if status == 1
statplot rel_out , over(status) vertical legend(off)
restore
*/


* Ahora limpiamos de estacionalidad la variable total:
gen diasemana = 0
replace diasemana = mod(dia+4,7) if mes == 1
replace diasemana = mod(dia+0,7) if mes == 2
replace diasemana = mod(dia+0,7) if mes == 3
replace diasemana = mod(dia+3,7) if mes == 4
replace diasemana = mod(dia+5,7) if mes == 5
replace diasemana = mod(dia+1,7) if mes == 6
replace diasemana = mod(dia+3,7) if mes == 7
replace diasemana = mod(dia+6,7) if mes == 8
replace diasemana = mod(dia+2,7) if mes == 9
replace diasemana = mod(dia+4,7) if mes == 10
replace diasemana = mod(dia+0,7) if mes == 11
replace diasemana = mod(dia+2,7) if mes == 12
replace diasemana = 7 if diasemana == 0

sort nombrecomuna mes dia
bys nombrecomuna: gen num_fecha = _n
tostring diasemana, gen(st_diasemana)
tostring mes, gen(st_mes)

gen st_weekday_x_comuna = nombrecomuna + " " + st_diasemana
gen st_mes_x_comuna = nombrecomuna + " " + st_mes

encode st_weekday_x_comuna, gen(weekday_x_comuna)
encode st_mes_x_comuna, gen(mes_x_comuna)


********************************************************************************

************************* Diferencias-en-Diferencias ***************************

********************************************************************************

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)
restore


********************************************************************************

************************* Placebo Tests ****************************************

********************************************************************************


preserve
drop if dia > 28 & mes == 9 | mes > 9
gen treatpost2 = 0
replace treatpost2 = treatment if dia == 28 & mes == 9
* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost2, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)



* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)
restore


preserve
drop if dia > 11 & mes == 10 | mes > 10
gen treatpost3 = 0
replace treatpost3 = treatment if dia == 11 & mes == 10
* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost3, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)
restore



********************************************************************************

****************************** Event Studies ***********************************

********************************************************************************

* NOTA: NO BOTAMOS OBSERVACIONES POST APAGÓN.

* Desestacionalizamos:
qui reg total i.weekday_x_comuna i.mes_x_comuna
predict dtotal, res


******************** Efecto Fijo Moment y Cohort

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 5 if _n < 10
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/8 {
	gen l`i' = 0
	replace l`i' = treatment if num_fecha == `i' - 4 + 277
}

drop l3
replace l0 = treatment if num_fecha < 273
replace l8 = treatment if num_fecha > 281

* Corremos el Event Studies para Outcome "Car Accidents":
reghdfe dtotal l* , abs(nombrecomuna num_fecha) vce(cl nombrecomuna)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/2 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 4/8 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

/*
summ estud if _n == 12
local menosuno = r(mean)

replace estud = estud - `menosuno'
replace dnic = dnic - `menosuno'
replace upic = upic - `menosuno'
replace estud = 0 if _n == 12
replace dnic = 0 if _n == 12
replace upic= 0 if _n == 12
*/

summ upic
local top_range = r(max)
summ dnic
local bottom_range = r(min)

twoway ///
(rarea upic dnic cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic dnic cont, lcolor(green)) ///
(line Zero cont, lcolor(black)) ///
(sc estud cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Outcome 2021", size(medsmall)) xtitle("Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))


********************************************************************************

********************************* Mechanisms ***********************************

********************************************************************************



* Entre 1 a 4 años:

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe g1_4 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe g1_4 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe g1_4 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_g1_4 = (g1_4 > 0)

* Efecto Fijo TWFE
reghdfe ex_g1_4 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_g1_4 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_g1_4 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)
restore



* Entre 5 y 14:

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe g5_15 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe g5_15 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe g5_15 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_g5_15 = (g5_15 > 0)

* Efecto Fijo TWFE
reghdfe ex_g5_15 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_g5_15 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_g5_15 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)
restore




* Entre 15 y 65:

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe g15_64 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe g15_64 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe g15_64 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_g15_64 = (g15_64 > 0)

* Efecto Fijo TWFE
reghdfe ex_g15_64 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_g15_64 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_g15_64 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)
restore



* Entre 65 o +:

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe g65 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe g65 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe g65 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)


* MARGEN EXTENSIVO
gen ex_g65 = (g65 > 0)

* Efecto Fijo TWFE
reghdfe ex_g65 treatpost, abs(nombrecomuna num_fecha region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_g65 treatpost, abs(nombrecomuna num_fecha mes_x_comuna region) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_g65 treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna region) vce(cl nombrecomuna)
restore


