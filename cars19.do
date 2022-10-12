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

set maxvar 10000

import delimited "$output/ts19.csv", delimiter(comma) varnames(1) clear
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

expand 20
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
gen cohort = int(mod(_n-1,20))
replace cohort = cohort
sort cohort date hora
order date hora cohort
keep date hora cohort dia mes año fecha hora1
save "$output/panel2019", replace 

import delimited "$output/car_accidents2019.csv", clear 
drop if edad == "NULL"

gen age = real(edad)

keep if calidad == "CONDUCTOR"


* Hacer grupos de edad.
gen inter = 0
replace inter = mod(age,5) // Módulo 5 así no tengo grupos con algunos tratados
// y otros no tratados (si tratamiento binario). Datos de internet por grupo 
* etario solo para grupos quinqueniales.

* Generamos variable cohorte:
gen cohort = age - inter
replace cohort = (cohort / 5)
cap drop inter

* Recopilamos número de conductores involucrados en un accidente en cada hora y 
* para cada grupo demográfico.
split hora, p(":")
cap drop hora
gen hora = real(hora1)
egen outcome = count(id), by(fecha hora cohort)
duplicates drop fecha hora cohort, force
split fecha, p("-")
replace fecha3 = "20"+fecha3
gen date = mdy(real(fecha2), real(fecha1), real(fecha3))
format date %td
drop fecha*
sort date hora edad
order date hora cohort
keep date hora cohort outcome

* Guardamos:
save "$output/accidents2019", replace 

use "$output/panel2019", clear
merge 1:1 date hora cohort using "$output/accidents2019", nogen 

sort cohort date hora
order date hora cohort


* Generamos Filtro post todo:
cap drop filter
gen filter = 1
replace filter = 0 if (mes == 3 & dia == 14 & hora > 12) | (mes == 3 & dia > 14) /*
*/  | mes > 3

* Generamos variables post:
gen post = 0
replace post = 1 if (mes == 3 & dia == 13 & hora > 12) | (mes == 3 & dia > 13)

* Generamos variable Treat Binario:
/*
gen treat = 0
replace treat = 1 if age < 35 // High social media penetration sería para menores de 35.
*/


* Generamos variable Treat Continuo (Usando Datos CASEN 2017):
* Porcentaje de Uso de Internet para Entretenimiento 2017.

drop if cohort == 0 // Conductores de entre 0 y 4 años.
gen treat = 0
replace treat = 0.868 if cohort == 1
replace treat = 0.856 if cohort == 2
replace treat = 0.870 if cohort == 3
replace treat = 0.875 if cohort == 4
replace treat = 0.885 if cohort == 5
replace treat = 0.859 if cohort == 6
replace treat = 0.835 if cohort == 7
replace treat = 0.793 if cohort == 8
replace treat = 0.764 if cohort == 9
replace treat = 0.732 if cohort == 10
replace treat = 0.728 if cohort == 11
replace treat = 0.685 if cohort == 12
replace treat = 0.651 if cohort == 13
replace treat = 0.649 if cohort == 14
replace treat = 0.586 if cohort == 15
replace treat = 0.602 if cohort > 15


* Generamos variable treat*post:
gen treatpost = treat*post


* Efecto Fijo Dia+Hora:
gen diahora = fecha + hora1

* Efecto Fijo Grupo+Hora:
tostring cohort, gen(st_cohort)
gen horagrupo = st_cohort + hora1

* Efecto Fijo Grupo x Día
gen diagrupo = fecha + st_cohort

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

bys cohort: gen num_fecha = _n
sort cohort fecha
order cohort fecha outcome


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
reghdfe outcome treatpost , abs(cohort diahora) vce(cluster cohort)

* (2) Con Efecto Fijo Grupo, Hora-Día y HoraxGrupo:
reghdfe outcome treatpost , abs(diahora horagrupo) vce(cluster cohort)

* (3) Con Efecto Fijo Grupo, Hora-Día, HoraxGrupo y DiaxGrupo:
reghdfe outcome treatpost , abs(diahora horagrupo diagrupo) vce(cluster cohort)

* MARGEN EXTENSIVO:

gen ex_outcome = (outcome > 0)

* (1) Con Efecto Fijo Grupo y Hora-Día:
reghdfe ex_outcome treatpost , abs(cohort diahora) vce(cluster cohort)

* (2) Con Efecto Fijo Hora-Día y HoraxGrupo:
reghdfe ex_outcome treatpost , abs(diahora horagrupo) vce(cluster cohort)

* (3) Con Efecto Fijo Grupo, Hora-Día, HoraxGrupo y DiaxGrupo:
reghdfe ex_outcome treatpost , abs(diahora horagrupo diagrupo) vce(cluster cohort)

restore


********************************************************************************

****************************** Event Studies ***********************************

********************************************************************************

* NOTA: NO BOTAMOS OBSERVACIONES POST APAGÓN.

/******************** Efecto Fijo Cohorte y Moment (Dia x Hora)

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 26
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/24 {
	gen l`i' = 0
	replace l`i' = treat if num_fecha == `i' - 12 + 1718
}

* Corremos el Event Studies para Outcome "Car Accidents":
reghdfe outcome l* , abs(cohort diahora diagrupo) vce(cl cohort)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/24 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}


twoway ///
(rarea upic dnic cont,  ///
fcolor(green%30) lcolor(gs13) lw(none) lpattern(solid)) ///
(line estud cont, lcolor(blue) lpattern(dash) lwidth(thick)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Percent", size(medsmall)) xtitle("Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))

*/

******************** Efecto Fijo HoraxCohorte, Moment (Dia x Hora) y DiaxGrupo

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 38
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/36 {
	gen l`i' = 0
	replace l`i' = treat if num_fecha == `i' - 12 + 6637
}

drop l11

* Corremos el Event Studies para Outcome "Car Accidents":
reghdfe outcome l* , abs(horagrupo diahora diagrupo) vce(cl cohort)
gen estud = 0
gen dnic = 0
gen upic = 0
forvalues i = 0/10 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/36 {
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
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Percent", size(medsmall)) xtitle("Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))
