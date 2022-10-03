* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/US-Trends" 


********************************************************************************

***************************** Ajuste Datos *************************************

********************************************************************************


* Social Media Use from NTIA Nov. 2019
import delimited "$raw/US-Internet/US_internet19.csv", varnames(1) clear
save "$raw/US-Internet/us_internet19",replace

import delimited "$raw/US-Trends/anx19.csv", varnames(1) clear
save "$output/anx19",replace

import delimited "$raw/US-Trends/dep19.csv", varnames(1) clear
save "$output/dep19",replace


import delimited "$raw/US-Trends/sui19.csv", clear
merge m:1 state using "$raw/US-Internet/us_internet19", nogen
merge m:m state date using "$output/anx19", nogen
merge m:m state date using "$output/dep19", nogen

duplicates report
duplicates drop

sort state date
order state date suicide anxiety depression

* Generamos Fecha:
gen year = 2019
gen min = 0
gen sec = 0
gen fecha = mdyhms(month,day, year, hour, min, sec)
format fecha %tc
*xtset fecha


* Logaritmizamos variables:
gen ln_sui = ln(suicide + 1)
gen ln_anx = ln(anxiety + 1)
gen ln_dep = ln(depression + 1)

* Botamos Alaska, Hawaii y US.
drop if state == "AK" |  state == "HI" |  state == "US"

* Effective Hour for F.E. (pasamos a la hora respectiva en cada zona)
replace timezone = 2 if state == "ID"
replace timezone = 3 if state == "NE"
replace timezone = 3 if state == "SD"
replace timezone = 2 if state == "AZ"

gen ef_hour = hour + timezone - 3
replace ef_hour = 23 if ef_hour == -1
replace ef_hour = 22 if ef_hour == -2
replace ef_hour = 0 if ef_hour == 24

/* "Effective Date"
No es Necesario! Nunca lo uso. 
No tiene sentido que los 3 de Oct. de 2021 a las 3 efectiva gente más depresiva.
Mejor controlar shocks de ese momento que son comunes a todos los estados.
* Generamos Effective Fecha (usando Ef. Hour):
split date, p(" ")
tostring ef_hour, gen(st_hour)
gen ef_date = date1+st_hour
*/

* Botamos 18-10 (tiene un solo dato):
split date, p(" ")
drop if date1 == "2019-03-27"


* Generamos Filtro: (Ya no usado --> "Usamos Post y no During")
cap drop filter
gen filter = 1
replace filter = 0 if (month == 3 & day == 14 & hour > 10) | (month == 3 & day > 14) /*
*/  | month > 3


* Generamos variables post:
gen post = 0
replace post = 1 if (month == 3 & day == 13 & hour > 10) | (month == 3 & day > 13)


* Generamos Index (Levy-2022) --> Multiple Hypothesis.
sum ln_sui if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_sui = (ln_sui - r(mean)) / r(sd)
sum ln_anx if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_anx = (ln_anx - r(mean)) / r(sd)
sum ln_dep if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_dep = (ln_dep - r(mean)) / r(sd)
gen pre_index = (st_anx + st_sui + st_dep) / 3
egen index = std(pre_index)

/*
* Tratamiento Binario
gen high = (socialm > 74.7)
gen treatpost = high * post
*/

* Generamos variable treat*post:
gen treatpost = socialm*post


* Botamos observaciones post apagón:
*drop if filter == 0

* Para desestacionalizar más abajo
gen weekday = 0
replace weekday = mod(day+4,7) if month == 3
replace weekday = mod(day+4,7) if month == 2
replace weekday = 7 if weekday == 0
bys state: gen num_fecha = _n
sort state date
order state date suicide anxiety depression


********************************************************************************

***************************** FIGURAS ******************************************

********************************************************************************

set scheme s1color

* 1. RAW TRENDS PER WEEK

* Semana Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha day month hour)
keep if _n > 288 & _n < 457
gen date = _n / 24
gen during = .
replace during = 20 if (month == 3 & day == 13 & hour > 10) | (month == 3 & day == 14 & hour < 11)
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/outage19.gph", replace
restore

* Semana Pre Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha)
keep if _n < 289 & _n > 120
gen date = _n / 24 
gen during = .
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/preout19.gph", replace
restore

* Semana Post Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha)
keep if _n > 456 & _n < 625
gen date = _n / 24 
gen during = .
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/postout19.gph", replace
restore

grc1leg2 "plots/preout19.gph" "plots/outage19.gph" "plots/postout19.gph"


* 2. LINEAR RELATIONSHIP WITH TREATMENT

preserve
collapse (mean) suicide anxiety depression index socialm, by(state)
* Ahora Social Media
twoway (scatter suicide socialm) (lfit suicide socialm)
graph save "plots/socsui19.gph", replace
twoway (scatter anxiety socialm) (lfit anxiety socialm)
graph save "plots/socanx19.gph", replace
twoway (scatter depression socialm) (lfit depression socialm)
graph save "plots/socdep19.gph", replace
twoway (scatter index socialm) (lfit index socialm)
graph save "plots/socind19.gph", replace
restore

graph combine "plots/socsui19.gph" "plots/socanx19.gph" "plots/socdep19.gph" "plots/socind19.gph"



* 3. SEASONALLY ADJUSTED TRENDS PER DAY

set scheme s1color
* Desestacionalizamos por día de la semana y por hora. 

* Ahora calculamos las series desestacionalizadas por Día de la Semana y Valor Hora.
cap drop res*
qui reg suicide i.weekday i.ef_hour i.num_fecha
predict res_sui, residuals
qui reg anxiety i.weekday i.ef_hour i.num_fecha
predict res_anx, residuals
qui reg depression i.weekday i.ef_hour i.num_fecha
predict res_dep, residuals

* Teniendo la serie desestacionalizada, procedo a calcular cada serie:
* Serán 3 series para cada término: pre, post y during.
gen period = 0
replace period = 1 if day ==13 & month == 3
replace period = 2 if day > 13 & month == 3
egen plot_sui = mean(res_sui), by(period hour)
egen plot_anx = mean(res_anx), by(period hour)
egen plot_dep = mean(res_dep), by(period hour)


preserve

duplicates drop period hour, force
gen up = .
gen down = .

* Suicide
replace up = 4 if (day == 13 & month == 3 & hour > 10)
replace down = -6 if (day == 13 & month == 3 & hour > 10)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_sui hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_sui hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_sui hour if period == 2, lcolor(red*.5)) 
graph save "plots/dsui19.gph", replace

* Anxiety
replace up = 5 if (day == 13 & month == 3 & hour > 10)
replace down = -3 if (day == 13 & month == 3 & hour > 10)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_anx hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_anx hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_anx hour if period == 2, lcolor(red*.5)) 
graph save "plots/danx19.gph", replace

* Depression
replace up = 4 if (day == 13 & month == 3 & hour > 10)
replace down = -5 if (day == 13 & month == 3 & hour > 10)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_dep hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_dep hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_dep hour if period == 2, lcolor(red*.5)) 
graph save "plots/ddep19.gph", replace

restore

grc1leg2 "plots/dsui19.gph" "plots/danx19.gph" "plots/ddep19.gph"



* 4. HISTOGRAMS PER HIGH AND LOW SOCIAL MEDIA PENETRATION

preserve
sum socialm, d
gen status = (socialm > 73.8)
collapse (mean) suicide anxiety depression index socialm, by(date day hour status)
sort status date
* Only compare during outage observations:
keep if (day == 13 & hour > 10)
collapse (mean) suicide anxiety depression, by(status)
statplot suicide anxiety depression , over(status) vertical legend(off)
restore

*/



********************************************************************************

************************* Diferencias-en-Diferencias ***************************

********************************************************************************



*****************************************
***************************************** Efecto Fijo Fecha (con hora) y Estado!
*****************************************

* Corremos el DiD para Suicide:
reghdfe suicide treatpost , abs(state date ef_hour) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe anxiety treatpost , abs(state date ef_hour) vce(cl state)

* Corremos el DiD para Depression:
reghdfe depression treatpost , abs(state date ef_hour) vce(cl state)

* Corremos el DiD para Index (Levy):
reghdfe index treatpost , abs(state date ef_hour) vce(cl state)



**********************************************
********************************************** Efecto Fijo Dia-Estado y Momento!
**********************************************

gen dia_estado = date1 + state

* Corremos el DiD para Suicide:
reghdfe suicide treatpost , abs(dia_estado date ef_hour) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe anxiety treatpost , abs(dia_estado date ef_hour) vce(cl state)

* Corremos el DiD para Depression:
reghdfe depression treatpost , abs(dia_estado date ef_hour) vce(cl state)

* Corremos el DiD para Index (Levy):
reghdfe index treatpost , abs(dia_estado date ef_hour) vce(cl state)


/**********************************************
********************************************** Zero Inflated Poisson!
**********************************************

encode state, gen(int_state)
encode date, gen(int_date)

* Corremos el DiD para Suicide:
qui zip suicide treatpost i.int_state i.int_date i.ef_hour, inflate(_cons) vce(cl state)
est table, keep(treatpost) b se p

* Corremos el DiD para Anxiety:
qui zip anxiety treatpost i.int_state i.int_date i.ef_hour, inflate(_cons) vce(cl state)
est table, keep(treatpost) b se p

* Corremos el DiD para Depression:
qui zip depression treatpost i.int_state i.int_date i.ef_hour, inflate(_cons) vce(cl state)
est table, keep(treatpost) b se p

*/

/*
***********************************************************
*********************************************************** Logaritmizando todo!
***********************************************************
* Efecto Fijo Fecha-Hora (shocks macro), Estado y Hora Efectiva.

gen ln_socialm = ln(socialm)
gen ln_treatpost = ln_socialm * post

* Corremos el DiD para Suicide:
reghdfe ln_sui ln_treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Anxiety:
reghdfe ln_anx ln_treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Depression:
reghdfe ln_dep ln_treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Index (Levy):
reghdfe index treatpost , abs(date state ef_hour) vce(cluster state)
*/

***************************************************************
*************************************************************** Margen Extensivo
***************************************************************

gen ex_sui = (suicide>0)
gen ex_anx = (anxiety>0)
gen ex_dep = (depression>0)
gen ex_aggr = ((suicide + anxiety + depression)>0)

* Efecto fijo Shocks Macro c/hora + Hora Efectiva + Estado

* Corremos el DiD para Suicide:
reghdfe ex_sui treatpost , abs(date state ef_hour) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date state ef_hour) vce(cl state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date state ef_hour) vce(cl state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date state ef_hour) vce(cl state)

* Efecto fijo Shocks Macro c/hora + Hora Efectiva + Shocks Idiosincráticos State

* Corremos el DiD para Suicide:
reghdfe ex_sui treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date dia_estado ef_hour) vce(cl state)



********************************************************************************

****************************** Event Studies ***********************************

********************************************************************************



cap drop ln*

gen cont = _n - 12 if _n < 24
gen Zero = 0

* Genero leads y lags:
forvalues i = 1/25 {
	gen l`i' = 0
	replace l`i' = socialm if num_fecha == `i' -12 + 349
}

* Corremos el Event Studies para Suicide:
reghdfe suicide l* , abs(date dia_estado ef_hour) vce(cl state)
gen estud_sui = 0
gen dnic_sui = 0
gen upic_sui = 0
forvalues i = 1/24 {
	replace estud_sui = _b[l`i'] if _n == `i'
	replace dnic_sui =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'
	replace upic_sui =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'
}

twoway ///
(rarea upic_sui dnic_sui cont,  ///
fcolor(green%30) lcolor(gs13) lw(none) lpattern(solid)) ///
(line estud_sui cont, lcolor(blue) lpattern(dash) lwidth(thick)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Percent", size(medsmall)) xtitle("Forward Months", size(medsmall)) ///
note("Notes: 90 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))



* Corremos el Event Studies para Anxiety:
reghdfe anxiety l* , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el Event Studies para Depression:
reghdfe depression l* , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el Event Studies para Depression:
reghdfe index l* , abs(date dia_estado ef_hour) vce(cl state)


/*
encode state, gen(id)
xtset id num_fecha
qui xtreg suicide treatpost i.ef_hour i.num_fecha i.id, fe vce(cl id) 
est table, keep(treatpost) b se p

xtreg suicide 


