* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Car Accidents" 


********************************************************************************

**************************** Usando Datos 2019 *********************************

********************************************************************************

import delimited "$output/ts19.csv", delimiter(comma) varnames(1)
split ts, p(" ")
split ts1, p("-")
split ts11, p("0")
cap drop fecha
gen fecha = ts12 + "-" + ts13 + "-" + ts112
split ts2, p(":")
cap drop hora1
gen hora1 = ts21
gen hora = real(hora1)
duplicates drop fecha hora, force
order fecha hora
sort fecha hora
keep fecha hora hora1

expand 42
split fecha, p("-")
replace fecha3 = "20"+fecha3
cap drop mes
gen dia = real(fecha2)
gen mes = real(fecha1)
gen año = real(fecha3)
gen date = mdy(mes, dia, año)
format date %td
drop fecha1 fecha2 fecha3
sort date hora 
gen idcomuna = int(mod(_n-1,42))+1 // ID para cada comuna
replace idcomuna = idcomuna
sort idcomuna date hora
order date hora idcomuna
keep date hora idcomuna dia mes año fecha hora1
save "$output/bpanel2019", replace 

* Debo agregarle el código comuna--> Usar Accidents 2019 (comunas en Mayus.)
import delimited "$output/car_accidents2021.csv", clear
duplicates drop comuna codcomuna, force
keep comuna codcomuna
save "$output/dic", replace

* Agregamos código comunas
import delimited "$output/car_accidents2019.csv", clear 
merge m:1 comuna using "$output/dic", nogen force

drop if edad == "NULL"

gen age = real(edad)

keep if calidad == "CONDUCTOR"






* Recopilamos número de conductores involucrados en un accidente en cada hora y 
* para cada comuna.
split hora, p(":")
cap drop hora
gen hora = real(hora1)
egen outcome = count(id), by(fecha hora codcomuna)
duplicates drop fecha hora codcomuna, force
split fecha, p("-")
replace fecha3 = "20"+fecha3
gen date = mdy(real(fecha2), real(fecha1), real(fecha3))
format date %td
drop fecha*
gen region = round(codcomuna / 1000)
keep if region == 13
egen idcomuna = group(codcomuna)
sort region codcomuna date hora
order date hora codcomuna region
keep date hora codcomuna region outcome idcomuna

* Guardamos:
save "$output/baccidents2019", replace 

use "$output/bpanel2019", clear
merge 1:1 date hora idcomuna using "$output/baccidents2019", nogen force

sort idcomuna date hora
order date hora idcomuna

bysort idcomuna (codcomuna) : replace codcomuna = codcomuna[_n-1] if missing(codcomuna) 
bysort idcomuna (region) : replace region = region[_n-1] if missing(region) 

drop if idcomuna == 0
sort idcomuna date hora


* Generamos Filtro post apagón 24 horas:
cap drop filter
gen filter = 1
replace filter = 0 if (mes == 3 & dia == 14 & hora > 12) | (mes == 3 & dia > 14) /*
*/  | mes > 3

* Generamos variables post:
gen post = 0
replace post = 1 if (mes == 3 & dia == 13 & hora > 12) | (mes == 3 & dia > 13)

* Importamos Variable Treatment:
merge m:1 codcomuna using "Urgencias/intmun", nogen 


* Generamos variable treat*post:
gen treatpost = treatment*post


* Efecto Fijo Dia+Hora:
gen diahora = fecha + hora1

* Efecto Fijo Grupo+Hora:
tostring idcomuna, gen(st_idcomuna)
gen horagrupo = st_idcomuna + hora1

* Efecto Fijo Grupo x Día
gen diagrupo = fecha + st_idcomuna

* Reemplazamos con cero en los outcomes vacíos:
replace outcome = 0 if outcome == .


* Para poder desestacionalizar en el futuro: 
gen diasemana = 0
replace diasemana = mod(dia+1,7) if mes == 1
replace diasemana = mod(dia+4,7) if mes == 2
replace diasemana = mod(dia+4,7) if mes == 3
replace diasemana = mod(dia+0,7) if mes == 4
replace diasemana = mod(dia+2,7) if mes == 5
replace diasemana = mod(dia+5,7) if mes == 6
replace diasemana = mod(dia+0,7) if mes == 7
replace diasemana = mod(dia+3,7) if mes == 8
replace diasemana = mod(dia+6,7) if mes == 9
replace diasemana = mod(dia+1,7) if mes == 10
replace diasemana = mod(dia+4,7) if mes == 11
replace diasemana = mod(dia+6,7) if mes == 12
replace diasemana = 7 if diasemana == 0

bys idcomuna: gen num_fecha = _n
sort idcomuna fecha
order idcomuna fecha outcome
gen num_fecha2 = round(num_fecha/6) 


tostring diasemana, gen(st_diasemana)
gen st_weekdaygrupo = st_diasemana + " " + st_idcomuna

tostring mes, gen(st_mes)
gen st_mesgrupo = st_mes + " " + st_idcomuna

encode st_mesgrupo, gen(mesgrupo)
encode st_weekdaygrupo, gen(weekdaygrupo)
encode horagrupo, gen(num_horagrupo)
encode diahora, gen(num_diahora)
encode diagrupo, gen(num_diagrupo)

/********************************************************************************

***************************** FIGURAS ******************************************

********************************************************************************

set scheme s1color

* 1. RAW TRENDS PER WEEK

* Semana Outage
preserve
collapse (mean) outcome, by(date dia mes hora)
keep if _n > 1656 & _n < 1825
gen cont = _n / 24
gen during = 0
replace during = 3 if (mes == 3 & dia == 13 & hora > 12) | (mes == 3 & dia == 14 & hora < 13)
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/outage2.gph", replace
restore

* Semana Pre Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n < 1657 & _n > 1488
gen cont = _n / 24
gen during = 0
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/preout2.gph", replace
restore

* Semana Post Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n > 1824 & _n < 1994
gen cont = _n / 24
gen during = 0
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/postout2.gph", replace
restore

grc1leg2 "plots/preout2.gph" "plots/outage2.gph" "plots/postout2.gph"


* 2. LINEAR RELATIONSHIP
preserve
collapse (mean) outcome treat, by(cohort)
twoway (scatter outcome treat) (lfit outcome treat)
restore


* 3. SEASONALLY ADJUSTED TRENDS PER DAY
gen num_fecha2 = round(num_fecha/6)

* Ahora calculamos las series desestacionalizadas por Día de la Semana y Valor Hora.
cap drop res*
qui reg outcome i.diasemana i.hora i.num_fecha2
predict res_out, residuals

* Teniendo la serie desestacionalizada, procedo a calcular cada serie:
* Serán 3 series para cada término: pre, post y during.
gen period = 0
replace period = 1 if dia ==13 & mes == 3
replace period = 2 if dia > 13 & mes == 3 | mes > 3
egen plot_out = mean(res_out), by(period hora)


preserve

duplicates drop period hora, force
gen up = .
gen down = .

* Plot
replace up = 1 if (mes == 3 & dia == 13 & hora > 12)
replace down = -1 if (mes == 3 & dia == 13 & hora > 12)
twoway (rarea up down hora if period == 1, sort color(gs14*.5)) (line plot_out hora if period == 0, lcolor(orange*.5)) /*
*/ (line plot_out hora if period == 1, lcolor(blue*.5)) /*
*/ (line plot_out hora if period == 2, lcolor(red*.5)) 
graph save "plots/dcar19.gph", replace

restore


* 4. HISTOGRAM PER HIGH AND LOW SOCIAL MEDIA PENETRATION
preserve
sum treat, d
gen status = (treat >= 0.732) // High penetration above median.
sum outcome if status == 0
gen av_out0 = r(mean)
sum outcome if status == 1
gen av_out1 = r(mean)
collapse (mean) outcome av_out0 av_out1, by(fecha dia mes hora status)
sort status fecha
* Only compare during outage observations:
keep if (dia == 13 & mes == 3 & hora > 10)
collapse (mean) outcome av_out0 av_out1, by(status)
gen rel_out = 0
replace rel_out = outcome / av_out0 if status == 0
replace rel_out = outcome / av_out1 if status == 1
statplot rel_out , over(status) vertical legend(off)
restore


*/


********************************************************************************

************************* Diferencias-en-Diferencias ***************************

********************************************************************************


* MARGEN INTENSIVO:
* Botamos observaciones post apagón:
preserve
drop if filter == 0


* (1) Con Efecto Fijo Grupo y Hora-Día:
reghdfe outcome treatpost , abs(idcomuna diahora) vce(cluster idcomuna)

* (2) Con Efecto Fijo Grupo, Hora-Día y HoraxGrupo:
reghdfe outcome treatpost , abs(diahora horagrupo) vce(cluster idcomuna)

* (3) Con Efecto Fijo Grupo, Hora-Día, HoraxGrupo y DiaxGrupo:
reghdfe outcome treatpost , abs(diahora horagrupo diagrupo) vce(cluster idcomuna)

* MARGEN EXTENSIVO:

gen ex_outcome = (outcome > 0)

* (1) Con Efecto Fijo Grupo y Hora-Día:
reghdfe ex_outcome treatpost , abs(idcomuna diahora) vce(cluster idcomuna)

* (2) Con Efecto Fijo Hora-Día y HoraxGrupo:
reghdfe ex_outcome treatpost , abs(diahora horagrupo) vce(cluster idcomuna)

* (3) Con Efecto Fijo Grupo, Hora-Día, HoraxGrupo y DiaxGrupo:
reghdfe ex_outcome treatpost , abs(diahora horagrupo diagrupo) vce(cluster idcomuna)

restore


********************************************************************************

****************************** Event Studies ***********************************

********************************************************************************

* NOTA: NO BOTAMOS OBSERVACIONES POST APAGÓN.

* 1º Desestacionalizamos outcome:
qui reg outcome i.weekdaygrupo i.num_horagrupo i.mesgrupo
predict doutcome, residuals

******************** Efecto Fijo Cohort y Moment

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 32
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/30 {
	gen l`i' = 0
	replace l`i' = treatment if num_fecha == 1718 - (24 - `i'*2)
	replace l`i' = treatment if num_fecha == 1718 - (24 - `i'*2) + 1
}


drop l11

replace l0 = treatment if num_fecha < 1694
replace l30= treatment if num_fecha > 1755

* Corremos el Event Studies para Outcome "Car Accidents":
reghdfe doutcome l* , abs(diahora idcomuna) vce(cl idcomuna)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/10 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}


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
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Outcome 2019", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))



********************************************************************************

****************************** Placebo Test ************************************

********************************************************************************

* Corremos el Event Studies para otro miércoles y a la misma hora de la siguiente semana:
cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 32
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/30 {
	gen l`i' = 0
	replace l`i' = treatment if num_fecha == 1886 - (24 - `i'*2)
	replace l`i' = treatment if num_fecha == 1886 - (24 - `i'*2) + 1
}


drop l11

replace l0 = treatment if num_fecha < 1862
replace l30= treatment if num_fecha > 1923

* Corremos el Placebo para Outcome "Car Accidents":
reghdfe doutcome l* , abs(diahora idcomuna) vce(cl idcomuna)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/10 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

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
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Outcome (Placebo) 2019", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))




* Corremos el Event Studies para otro miércoles y a la misma hora de la semana previa:
cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 32
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/30 {
	gen l`i' = 0
	replace l`i' = treatment if num_fecha == 1550 - (24 - `i'*2)
	replace l`i' = treatment if num_fecha == 1550 - (24 - `i'*2) + 1
}


drop l11

replace l0 = treatment if num_fecha < 1526
replace l30= treatment if num_fecha > 1587

* Corremos el Placebo para Outcome "Car Accidents":
reghdfe doutcome l* , abs(diahora cohort) vce(cl cohort)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/10 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

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
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Outcome (Placebo) 2019", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))


