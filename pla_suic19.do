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

import delimited "$raw/US-Trends/wea19.csv", varnames(1) clear // Weather
save "$output/wea19",replace

import delimited "$raw/US-Trends/amz19.csv", varnames(1) clear // Amazon
save "$output/amz19",replace


import delimited "$raw/US-Trends/sui19.csv", clear
merge m:1 state using "$raw/US-Internet/us_internet19", nogen
merge m:m state date using "$output/anx19", nogen
merge m:m state date using "$output/dep19", nogen

duplicates report
gen botar = date + state
duplicates drop botar, force
drop botar

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

* Para desestacionalizar más abajo:
gen weekday = 0
replace weekday = mod(day+4,7) if month == 3
replace weekday = mod(day+4,7) if month == 2
replace weekday = 7 if weekday == 0
bys state: gen num_fecha = _n
sort state date
order state date suicide anxiety depression

drop if num_fecha > 672

tostring weekday, gen(st_weekday)
tostring ef_hour, gen(st_ef_hour)

gen st_sw = state + " " + st_weekday
gen st_se = state + " " + st_ef_hour

encode st_sw, gen(stateweekday)
encode st_se, gen(stateefhour)
encode state, gen(num_state)
encode date, gen(moment)

/********************************************************************************

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
gen during = 0
replace during = 1 if post == 1 & filter == 1
replace during = 2 if filter == 0
sum socialm, d
gen status = (socialm > 73.8)
collapse (mean) suicide anxiety depression index socialm, by(date day hour status during)
sort status date
* Only compare during outage observations:
collapse (mean) suicide anxiety depression, by(status during)
drop if during == 2
gen categ = _n
statplot suicide anxiety depression , over(categ) vertical legend(off)
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
encode dia_estado, gen(num_diaestado)

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

* Efecto fijo Shocks Macro c/hora + Estado

* Corremos el DiD para Suicide:
reghdfe ex_sui treatpost , abs(date state) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date state) vce(cl state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date state) vce(cl state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date state) vce(cl state)


/*
* Efecto fijo Shocks Macro c/hora + Hora Efectiva + Shocks Idiosincráticos State

* Corremos el DiD para Suicide:
reghdfe ex_sui treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date dia_estado ef_hour) vce(cl state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date dia_estado ef_hour) vce(cl state)
*/


********************************************************************************

****************************** Event Studies ***********************************

********************************************************************************

* Desestacinalizamos: (ef hour estado, dia semana estado y mes estado)
qui reg suicide i.stateefhour i.stateweekday
predict dsuicide, residuals
qui reg anxiety i.stateefhour i.stateweekday
predict danxiety, residuals
qui reg depression i.stateefhour i.stateweekday
predict ddepression, residuals
qui reg index i.stateefhour i.stateweekday
predict dindex, residuals


******************** Efecto Fijo Moment, Dia x Estado y Effective Hour 

merge m:m state date using "$output/wea19", nogen
merge m:m state date using "$output/amz19", nogen


drop ln*
cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 32
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/30 {
	gen l`i' = 0
	replace l`i' = socialm if num_fecha == 348 - (24 - `i'*2)
	replace l`i' = socialm if num_fecha == 348 - (24 - `i'*2) + 1
}

replace l0 = socialm if num_fecha < 324
replace l30 = socialm if num_fecha > 385

drop l11

* Corremos el Event Studies para Suicide:

reghdfe dsuicide l*, abs(moment num_state) vce(cl state)
gen estud_sui = 0
gen dnic_sui = 0
gen upic_sui = 0
forvalues i = 0/10 {
	replace estud_sui = _b[l`i'] if _n == `i'+1
	replace dnic_sui =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_sui =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_sui = _b[l`i'] if _n == `i'+1
	replace dnic_sui =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_sui =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

summ upic_sui
local top_range = r(max)
summ dnic_sui
local bottom_range = r(min)

twoway ///
(rarea upic_sui dnic_sui cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_sui dnic_sui cont, lcolor(green)) ///
(sc estud_sui cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Suicide", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))



* Corremos el Event Studies para Anxiety:
reghdfe danxiety l* weather, abs(moment num_state) vce(cl state)
gen estud_anx = 0
gen dnic_anx = 0
gen upic_anx = 0
forvalues i = 0/10 {
	replace estud_anx = _b[l`i'] if _n == `i'+1
	replace dnic_anx =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_anx =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_anx = _b[l`i'] if _n == `i'+1
	replace dnic_anx =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_anx =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

summ upic_anx
local top_range = r(max)
summ dnic_anx
local bottom_range = r(min)

twoway ///
(rarea upic_anx dnic_anx cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_anx dnic_anx cont, lcolor(green)) ///
(sc estud_anx cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Anxiety", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))



* Corremos el Event Studies para Depression:

*log using "output", replace
*areg depression l* i.num_state i.ef_hour, abs(moment) vce(cl state)
reghdfe ddepression l*, abs(moment num_state) vce(cl state)
*log close
*translate "output.smcl" "output.pdf",replace
gen estud_dep = 0
gen dnic_dep = 0
gen upic_dep = 0
forvalues i = 0/10 {
	replace estud_dep = _b[l`i'] if _n == `i'+1
	replace dnic_dep =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_dep =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_dep = _b[l`i'] if _n == `i'+1
	replace dnic_dep =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_dep =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

summ upic_dep
local top_range = r(max)
summ dnic_dep
local bottom_range = r(min)

twoway ///
(rarea upic_dep dnic_dep cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_dep dnic_dep cont, lcolor(green)) ///
(sc estud_dep cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Depression", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))




* Corremos el Event Studies para Index (Levy 2022):
reghdfe dindex l*, abs(moment num_state) vce(cl state)
gen estud_ind = 0
gen dnic_ind = 0
gen upic_ind = 0
forvalues i = 0/10 {
	replace estud_ind = _b[l`i'] if _n == `i'+1
	replace dnic_ind =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_ind =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_ind = _b[l`i'] if _n == `i'+1
	replace dnic_ind =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_ind =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}


summ upic_ind
local top_range = r(max)
summ dnic_ind
local bottom_range = r(min)

twoway ///
(rarea upic_ind dnic_ind cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_ind dnic_ind cont, lcolor(green)) ///
(sc estud_ind cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Index", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))


********************************************************************************

****************************** Robustness Checks *******************************

********************************************************************************
qui reg weather i.stateefhour i.stateweekday
predict dweather, residuals
qui reg amazon i.stateefhour i.stateweekday
predict damazon, residuals


* Con Event Studies: 

cap drop cont Zero l* estud* up* dn*
gen cont = _n - 13 if _n < 32
gen Zero = 0

* Genero leads y lags:
forvalues i = 0/30 {
	gen l`i' = 0
	replace l`i' = socialm if num_fecha == 348 - (24 - `i'*2)
	replace l`i' = socialm if num_fecha == 348 - (24 - `i'*2) + 1
}

replace l0 = socialm if num_fecha < 324
replace l30 = socialm if num_fecha > 385

drop l11

* Corremos el Event Studies para Weather:
reghdfe dweather l* , abs(moment num_state) vce(cl state)
gen estud_wea = 0
gen dnic_wea = 0
gen upic_wea = 0
forvalues i = 0/10 {
	replace estud_wea = _b[l`i'] if _n == `i'+1
	replace dnic_wea =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_wea =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_wea = _b[l`i'] if _n == `i'+1
	replace dnic_wea =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_wea =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}

summ upic_wea
local top_range = r(max)
summ dnic_wea
local bottom_range = r(min)

twoway ///
(rarea upic_wea dnic_wea cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_wea dnic_wea cont, lcolor(green)) ///
(sc estud_wea cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Weather", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))



* Corremos el Event Studies para Amazon:

reghdfe amazon l* , abs(moment num_state) vce(cl state)
gen estud_amz = 0
gen dnic_amz = 0
gen upic_amz = 0
forvalues i = 0/10 {
	replace estud_amz = _b[l`i'] if _n == `i'+1
	replace dnic_amz =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_amz =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}
forvalues i = 12/30 {
	replace estud_amz = _b[l`i'] if _n == `i'+1
	replace dnic_amz =  _b[l`i'] - 1.96* _se[l`i'] if _n == `i'+1
	replace upic_amz =  _b[l`i'] + 1.96* _se[l`i'] if _n == `i'+1
}


summ upic_amz
local top_range = r(max)
summ dnic_amz
local bottom_range = r(min)

twoway ///
(rarea upic_amz dnic_amz cont,  ///
fcolor(green%10) lcolor(gs13) lw(none) lpattern(solid)) ///
(rcap upic_amz dnic_amz cont, lcolor(green)) ///
(sc estud_amz cont, mcolor(blue)) ///
(function y = -0.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(function y = 11.5, range(`bottom_range' `top_range') horiz lpattern(dash) lcolor(gs10)) ///
(line Zero cont, lcolor(black)), legend(off) ///
ytitle("Amazon", size(medsmall)) xtitle("2 Hour Leads", size(medsmall)) ///
note("Notes: 95 percent confidence bands") ///
graphregion(color(white)) plotregion(color(white))


