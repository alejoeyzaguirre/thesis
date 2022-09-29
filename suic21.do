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


import delimited "$raw/US-Internet/US_internet2.csv", varnames(1) clear
save "$raw/US-Internet/us_internet",replace

import delimited "$raw/US-Trends/anxiety.csv", varnames(1) clear
save "$output/anx",replace

import delimited "$raw/US-Trends/depression.csv", varnames(1) clear
save "$output/dep",replace


import delimited "$raw/US-Trends/suic.csv", clear
merge m:1 state using "$raw/US-Internet/us_internet", nogen
merge m:m state date using "$output/anx", nogen
merge m:m state date using "$output/dep", nogen

duplicates report
duplicates drop

sort state date
order state date suicide anxiety depression

* Generamos Fecha:
gen year = 2021
gen min = 1
gen sec = 1
gen fecha = mdyhms(month,day, year, hour, min, sec)
format fecha %tc


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
drop if date1 == "2021-10-18"


* Generamos Filtro: (Ya no usado --> "Usamos Post y no During")
cap drop filter
gen filter = 1
replace filter = 0 if (day == 4 & month == 10 & hour > 15) | (day > 4 & month == 10)


* Generamos variables post (Outage de 9:40 a 16:00. Asumo que parte a las 9):
gen post = 0
replace post = 1 if (day == 4 & month == 10 & hour > 8)|(day > 4 & month == 10)


* Generamos Index (Levy-2022) --> Multiple Hypothesis.
sum ln_sui if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_sui = (ln_sui - r(mean)) / r(sd)
sum ln_anx if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_anx = (ln_anx - r(mean)) / r(sd)
sum ln_dep if post == 0 // Sacamos Std. Dev y Media antes del apagón.
gen st_dep = (ln_dep - r(mean)) / r(sd)
gen pre_index = (st_anx + st_sui + st_dep) / 3
egen index = std(pre_index)

/* Tratamiento Binario
* Tratamiento Binario
gen high = (socialm > 74.7)
gen treatpost = high * post
*/

* Generamos variable treat*post:
gen treatpost = socialm*post


* Botamos observaciones post apagón:
*drop if filter == 0



/********************************************************************************

***************************** FIGURAS ******************************************

********************************************************************************


set scheme s1color

* Semana Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha day month hour)
keep if _n > 337 & _n < 505
gen date = _n / 24
gen during = .
replace during = 25 if (day == 4 & month == 10 & hour > 8 & hour < 16)
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/outage.gph", replace
restore

* Semana Pre Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha)
keep if _n < 337 & _n > 169
gen date = _n / 24 
gen during = .
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/preout.gph", replace
restore

* Semana Post Outage
preserve
collapse (mean) suicide anxiety depression index, by(fecha)
keep if _n > 505 & _n < 674
gen date = _n / 24 
gen during = .
twoway (area during date, color(gs14))(line suicide date)(line anxiety date)(line depression date) 
graph save "plots/postout.gph", replace
restore

grc1leg2 "plots/outage.gph" "plots/preout.gph" "plots/postout.gph"

* Relación Lineal
preserve
* Ahora Social Media
collapse (mean) suicide anxiety depression index socialm, by(state)
twoway (scatter suicide socialm) (lfit suicide socialm)
graph save "plots/socsui.gph", replace
twoway (scatter anxiety socialm) (lfit anxiety socialm)
graph save "plots/socanx.gph", replace
twoway (scatter depression socialm) (lfit depression socialm)
graph save "plots/socdep.gph", replace
twoway (scatter index socialm) (lfit index socialm)
graph save "plots/socind.gph", replace

restore

graph combine "plots/socsui.gph" "plots/socanx.gph" "plots/socdep.gph" "plots/socind.gph"
*/



******** Desestacionalizando Comparission 


set scheme s1color
* Desestacionalizamos por día de la semana y por hora. 
gen weekday = 0
replace weekday = mod(day+2,7) if month == 9
replace weekday = mod(day+4,7) if month == 10
replace weekday = 7 if weekday == 0
bys state: gen num_fecha = _n
sort state date
order state date suicide anxiety depression

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
replace period = 1 if day ==4 & month == 10
replace period = 2 if day > 4 & month == 10
egen plot_sui = mean(res_sui), by(period hour)
egen plot_anx = mean(res_anx), by(period hour)
egen plot_dep = mean(res_dep), by(period hour)


preserve

duplicates drop period hour, force
gen up = .
gen down = .

* Suicide
replace up = 4 if (day == 4 & month == 10 & hour > 8 & hour < 16)
replace down = -4.2 if (day == 4 & month == 10 & hour > 8 & hour < 16)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_sui hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_sui hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_sui hour if period == 2, lcolor(red*.5)) 
graph save "plots/dsui21.gph", replace

* Anxiety
replace up = 4.5 if (day == 4 & month == 10 & hour > 8 & hour < 16)
replace down = -3 if (day == 4 & month == 10 & hour > 8 & hour < 16)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_anx hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_anx hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_anx hour if period == 2, lcolor(red*.5)) 
graph save "plots/danx21.gph", replace

* Depression
replace up = 4 if (day == 4 & month == 10 & hour > 8 & hour < 16)
replace down = -4 if (day == 4 & month == 10 & hour > 8 & hour < 16)
twoway (rarea up down hour if period == 1, sort color(gs14*.5)) (line plot_dep hour if period == 0, lcolor(orange*.5)) /*
*/ (line plot_dep hour if period == 1, lcolor(blue*.5)) /*
*/ (line plot_dep hour if period == 2, lcolor(red*.5)) 
graph save "plots/ddep21.gph", replace

restore

grc1leg2 "plots/dsui21.gph" "plots/danx21.gph" "plots/ddep21.gph"


/* With Line Smoother
twoway (line plot_sui hour if period == 0, lcolor(orange*.1)) (lowess plot_sui hour if period == 0, lcolor(orange)) /*
*/ (line plot_sui hour if period == 1, lcolor(blue*.1)) (lowess plot_sui hour if period == 1, lcolor(blue))/*
*/ (line plot_sui hour if period == 2, lcolor(red*.1)) (lowess plot_sui hour if period == 2, lcolor(red))
*/


*********** Histograms
preserve
sum socialm, d
gen status = (socialm > 74.7)
collapse (mean) suicide anxiety depression index socialm, by(date day hour status)
sort status date
* Only compare during outage observations:
keep if (day == 4 & hour > 8 & hour < 16)
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
reghdfe suicide treatpost , abs(state date ef_hour) vce(cluster state)

* Corremos el DiD para Anxiety:
reghdfe anxiety treatpost , abs(state date ef_hour) vce(cluster state)

* Corremos el DiD para Depression:
reghdfe depression treatpost , abs(state date ef_hour) vce(cluster state)

* Corremos el DiD para Index (Levy):
reghdfe index treatpost , abs(state date ef_hour) vce(cluster state)



**********************************************
********************************************** Efecto Fijo Dia-Estado y Momento!
**********************************************

gen dia_estado = date1 + state

* Corremos el DiD para Suicide:
reghdfe suicide treatpost , abs(dia_estado date ef_hour) vce(cluster state)

* Corremos el DiD para Anxiety:
reghdfe anxiety treatpost , abs(dia_estado date ef_hour) vce(cluster state)

* Corremos el DiD para Depression:
reghdfe depression treatpost , abs(dia_estado date ef_hour) vce(cluster state)

* Corremos el DiD para Index (Levy):
reghdfe index treatpost , abs(dia_estado date ef_hour) vce(cluster state)


**********************************************
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
reghdfe ex_sui treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date state ef_hour) vce(cluster state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date state ef_hour) vce(cluster state)

* Efecto fijo Shocks Macro c/hora + Hora Efectiva + Shocks Idiosincráticos State

* Corremos el DiD para Suicide:
reghdfe ex_sui treatpost , abs(date dia_estado ef_hour) vce(cluster state)

* Corremos el DiD para Anxiety:
reghdfe ex_anx treatpost , abs(date dia_estado ef_hour) vce(cluster state)

* Corremos el DiD para Depression:
reghdfe ex_dep treatpost , abs(date dia_estado ef_hour) vce(cluster state)

* Corremos el DiD para Aggregate:
reghdfe ex_aggr treatpost , abs(date dia_estado ef_hour) vce(cluster state)
