* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Car Accidents" 


********************************************************************************

**************************** Usando Datos 2021 *********************************

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
save "$output/panel2021", replace 


import delimited "$output/car_accidents2021.csv", clear 

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
save "$output/accidents2021", replace 

use "$output/panel2021", clear
merge 1:1 date hora cohort using "$output/accidents2021", nogen force

sort cohort date hora
order date hora cohort


* Generamos Filtro:
cap drop filter
gen filter = 1
replace filter = 0 if (dia > 4 & mes > 9) | (dia == 4 & mes == 10 & hora > 19)/*
*/  | (mes > 10)

* Generamos variables post:
gen post = 0
replace post = 1 if dia == 4 & mes == 10 & hora > 11 & hora < 20


* Generamos variable Treat Binario:
/*
gen treat = 0
replace treat = 1 if age < 35 // High social media penetration sería para mayores de 30.
*/

* Generamos variable Treat Continuo (Usando Datos Fundación País Digital):
* Porcentaje de Uso de Internet para Entretenimiento 2020 (Proyección).

drop if cohort == 0 // Conductores de entre 0 y 10 años.
gen treat = 0
replace treat = 0.894 if cohort == 1
replace treat = 0.881 if cohort == 2
replace treat = 0.895 if cohort == 3
replace treat = 0.910 if cohort == 4
replace treat = 0.937 if cohort == 5
replace treat = 0.924 if cohort == 6
replace treat = 0.908 if cohort == 7
replace treat = 0.850 if cohort == 8
replace treat = 0.823 if cohort == 9
replace treat = 0.782 if cohort == 10
replace treat = 0.789 if cohort == 11
replace treat = 0.738 if cohort == 12
replace treat = 0.687 if cohort == 13
replace treat = 0.701 if cohort == 14
replace treat = 0.606 if cohort == 15
replace treat = 0.622 if cohort > 15



* Generamos variable Treat Continuo (Usando Datos CASEN 2017):
* Porcentaje de Uso de Internet para Entretenimiento 2017.
/*
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
*/


* Generamos variable treat*post:
gen treatpost = treat*post


* Efecto Fijo Dia+Hora:
gen diahora = fecha + hora1

* Efecto Fijo Grupo+Hora:
tostring cohort, gen(st_cohort)
gen horagrupo = st_cohort + hora1

* Reemplazamos con cero en los outcomes vacíos:
replace outcome = 0 if outcome == .


********************************************************************************

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
replace during = 3 if dia == 4 & mes == 10 & hora > 11 & hora < 20
twoway (area during cont, color(gs14))(line outcome cont) 
graph save outage, replace
restore

* Semana Pre Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n < 6625 & _n > 6456
gen cont = _n / 24
gen during = .
twoway (area during cont, color(gs14))(line outcome cont) 
graph save preout, replace
restore

* Semana Post Outage
preserve
collapse (mean) outcome, by(date hora)
keep if _n > 6792 & _n < 6961
gen cont = _n / 24
gen during = .
twoway (area during cont, color(gs14))(line outcome cont) 
graph save postout, replace
restore

grc1leg2 preout.gph outage.gph postout.gph


* 2. LINEAR RELATIONSHIP
preserve
collapse (mean) outcome treat, by(cohort)
twoway (scatter outcome treat) (lfit outcome treat)
restore


* 3. SEASONALLY ADJUSTED TRENDS PER DAY

* Desestacionalizamos por día de la semana y por hora. 
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

bys cohort: gen num_fecha = _n
sort cohort fecha
order cohort fecha outcome

* Ahora calculamos las series desestacionalizadas por Día de la Semana y Valor Hora.
cap drop res*
qui reg outcome i.diasemana i.hora i.date
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

* Suicide
replace up = 2 if (dia == 4 & mes == 10 & hora > 11 & hora < 20)
replace down = -2 if (dia == 4 & mes == 10 & hora > 11 & hora < 20)
twoway (rarea up down hora if period == 1, sort color(gs14*.5)) (line plot_out hora if period == 0, lcolor(orange*.5)) /*
*/ (line plot_out hora if period == 1, lcolor(blue*.5)) /*
*/ (line plot_out hora if period == 2, lcolor(red*.5)) 
graph save "plots/dsui19.gph", replace

restore



*/




********************************************************************************

************************* Diferencias-en-Diferencias ***************************

********************************************************************************


* Corremos el DiD para Accidentes:

* Botamos observaciones post apagón:
drop if filter == 0



* MARGEN INTENSIVO:

/*
* (1) Con Efecto Fijo Grupo y Hora:
reghdfe outcome treatpost , abs(cohort hora) vce(cluster cohort)
*/

* (2) Con Efecto Fijo Grupo, Hora y Día:
reghdfe outcome treatpost , abs(cohort hora fecha) vce(cluster cohort)

* (3) Con Efecto Fijo Grupo y Hora-Día:
reghdfe outcome treatpost , abs(cohort diahora) vce(cluster cohort)

* (4) Con Efecto Fijo Día y HoraxGrupo:
reghdfe outcome treatpost , abs(fecha horagrupo) vce(cluster cohort)

* (5) Con Efecto Fijo Grupo, Hora-Día y HoraxGrupo:
reghdfe outcome treatpost , abs(diahora horagrupo) vce(cluster cohort)

* MARGEN EXTENSIVO:

gen ex_outcome = (outcome > 0)

/*
* (1) Con Efecto Fijo Grupo y Hora:
reghdfe ex_outcome treatpost , abs(cohort hora) vce(cluster cohort)
*/

* (2) Con Efecto Fijo Grupo, Hora y Día:
reghdfe ex_outcome treatpost , abs(cohort hora fecha) vce(cluster cohort)

* (3) Con Efecto Fijo Grupo y Hora-Día:
reghdfe ex_outcome treatpost , abs(cohort diahora) vce(cluster cohort)

* (4) Con Efecto Fijo Día y HoraxGrupo:
reghdfe ex_outcome treatpost , abs(fecha horagrupo) vce(cluster cohort)

* (5) Con Efecto Fijo Hora-Día y HoraxGrupo:
reghdfe ex_outcome treatpost , abs(diahora horagrupo) vce(cluster cohort)
