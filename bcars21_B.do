* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Car Accidents" 


********************************************************************************

**************************** Usando Datos 2021 (40<60) *************************

********************************************************************************


import delimited "$output/ts21.csv", delimiter(comma) varnames(1)
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
save "$output/bpanel2021", replace 


import delimited "$output/car_accidents2021.csv", clear 

drop if edad == "NULL"

gen age = real(edad)

keep if calidad == "CONDUCTOR"

* Filtramos para 1º Grupo de Edad: MENORES DE 40:
keep if age > 39 & age < 60


* Recopilamos número de conductores involucrados en un accidente en cada hora y 
* para cada grupo demográfico.
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
save "$output/baccidents2021", replace 

use "$output/bpanel2021", clear
merge 1:1 date hora idcomuna using "$output/baccidents2021", nogen force

sort idcomuna date hora
order date hora idcomuna

bysort idcomuna (codcomuna) : replace codcomuna = codcomuna[_n-1] if missing(codcomuna) 
bysort idcomuna (region) : replace region = region[_n-1] if missing(region) 

drop if idcomuna == 0
sort idcomuna date hora


* Generamos Filtro:
cap drop filter
gen filter = 1
replace filter = 0 if (dia > 4 & mes > 9) | (dia == 4 & mes == 10 & hora > 19)/*
*/  | (mes > 10)

* Generamos variables post:
gen post = 0
replace post = 1 if dia == 4 & mes == 10 & hora > 11 & hora < 20

* Importamos Variable Treatment:
merge m:1 codcomuna using "Urgencias/intmun", nogen 

* Generamos variable treat*post:
gen treatpost = treat*post

* Efecto Fijo Dia+Hora:
gen diahora = fecha + hora1


* Efecto Fijo Grupo+Hora:
tostring idcomuna, gen(st_idcomuna)
gen horagrupo = st_idcomuna + hora1

* Efecto Fijo Grupo x Día
gen diagrupo = fecha + st_idcomuna

* Reemplazamos con cero en los outcomes vacíos:
replace outcome = 0 if outcome == .

* Para poder desestacionalizar luego: 
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

tostring diasemana, gen(st_diasemana)
gen st_weekdaygrupo = st_diasemana + " " + st_idcomuna

tostring mes, gen(st_mes)
gen st_mesgrupo = st_mes + " " + st_idcomuna

encode st_mesgrupo, gen(mesgrupo)
encode st_weekdaygrupo, gen(weekdaygrupo)
encode horagrupo, gen(num_horagrupo)
encode diahora, gen(num_diahora)
encode diagrupo, gen(num_diagrupo)

bys idcomuna: gen num_fecha = _n
sort idcomuna fecha
order idcomuna fecha outcome


/********************************************************************************

***************************** FIGURAS ******************************************

********************************************************************************

set scheme s1color

* 1. RAW TRENDS PER WEEK

* Semana Outage
preserve
collapse (mean) outcome, by(date dia mes hora)
keep if _n > 6624 & _n < 6793
gen cont = _n / 24
gen during = .
replace during = 0.5 if dia == 4 & mes == 10 & hora > 11 & hora < 20
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/outage.gph", replace
restore

* Semana Pre Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n < 6625 & _n > 6456
gen cont = _n / 24
gen during = .
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/preout.gph", replace
restore

* Semana Post Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n > 6792 & _n < 6961
gen cont = _n / 24
gen during = .
twoway (area during cont, color(gs14))(line outcome cont) 
graph save "plots/postout.gph", replace
restore

grc1leg2 "plots/preout.gph" "plots/outage.gph" "plots/postout.gph"


* 2. LINEAR RELATIONSHIP
preserve
collapse (mean) outcome treatment, by(idcomuna)
twoway (scatter outcome treatment) (lfit outcome treatment)
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
replace period = 1 if dia ==4 & mes == 10
replace period = 2 if dia > 4 & mes == 10 | mes > 10
egen plot_out = mean(res_out), by(period hora)


preserve

duplicates drop period hora, force
gen up = .
gen down = .

* Plot
replace up = 2 if (dia == 4 & mes == 10 & hora > 11 & hora < 20)
replace down = -1 if (dia == 4 & mes == 10 & hora > 11 & hora < 20)
twoway (rarea up down hora if period == 1, sort color(gs14*.5)) (line plot_out hora if period == 0, lcolor(orange*.5)) /*
*/ (line plot_out hora if period == 1, lcolor(blue*.5)) /*
*/ (line plot_out hora if period == 2, lcolor(red*.5)) 
graph save "plots/dcar21.gph", replace

restore


* 4. HISTOGRAM PER HIGH AND LOW SOCIAL MEDIA PENETRATION
preserve
sum treatment, d
gen status = (treatment >= 0.602) // High penetration above median.
sum outcome if status == 0
gen av_out0 = r(mean)
sum outcome if status == 1
gen av_out1 = r(mean)
collapse (mean) outcome av_out0 av_out1, by(fecha dia mes hora status)
sort status fecha
* Only compare during outage observations:
keep if (dia == 4 & mes == 10 & hora > 11 & hora < 20)
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

* Desestacionalizamos:
qui reg outcome i.hora i.diasemana i.mes i.weekdaygrupo
predict doutcome, residuals

******************** Efecto Fijo Moment y Cohort

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 26
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/24 {
	gen l`i' = 0
	replace l`i' = treatment if num_fecha == `i' - 12 + 6637
}

drop l11
replace l0 = treatment if num_fecha < 6625
replace l24 = treatment if num_fecha > 6649

* Corremos el Event Studies para Outcome "Car Accidents":
reghdfe doutcome l* , abs(diahora idcomuna) vce(cl idcomuna)
gen estud = 0
gen dnic90 = 0
gen upic90 = 0
gen dnic95 = 0
gen upic95 = 0
forvalues i = 0/10 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic95 =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace dnic90 =  _b[l`i'] - 1.64* _se[l`i'] if _n == `i'+1
	replace upic95 =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
	replace upic90 =  _b[l`i'] + 1.64* _se[l`i'] if _n == `i'+1

}
forvalues i = 12/24 {
	replace estud = _b[l`i'] if _n == `i'+1
	replace dnic95 =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace dnic90 =  _b[l`i'] - 1.64* _se[l`i'] if _n == `i'+1
	replace upic95 =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
	replace upic90 =  _b[l`i'] + 1.64* _se[l`i'] if _n == `i'+1
}



summ upic95
local top_range = r(max)
summ dnic95
local bottom_range = r(min)

twoway ///
(rarea upic95 dnic95 cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rarea upic90 dnic90 cont,  ///
fcolor(green%15) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic95 dnic95 cont, lcolor(green%60)) ///
(rcap upic90 dnic90 cont, lcolor(green)) ///
(line Zero cont, lcolor(black)) ///
(sc estud cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 5.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)), ///
 legend(off) ytitle("Outcome 2021", size(medsmall)) xtitle("Leads", size(medsmall)) ///
note("Notes: 95 and 90 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))
